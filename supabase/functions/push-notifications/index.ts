// Scheduled server worker. No user-supplied recipient, token or notification body.
interface PushJob { notification_id: string; device_token: string; user_id: string; lease_id: string }
interface ServiceAccount { project_id: string; client_email: string; private_key: string }
let cached: { token: string; expires: number; project: string } | null = null;
function base64url(bytes: Uint8Array): string {
  let binary = ''; for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
async function googleToken(account: ServiceAccount): Promise<string> {
  if (cached?.project === account.project_id && cached.expires > Date.now() + 60000) return cached.token;
  const now = Math.floor(Date.now() / 1000);
  const encode = (v: unknown) => base64url(new TextEncoder().encode(JSON.stringify(v)));
  const unsigned = encode({ alg: 'RS256', typ: 'JWT' }) + '.' + encode({
    iss: account.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  });
  const pem = account.private_key.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(pem), c => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: unsigned + '.' + base64url(new Uint8Array(signature)) }).toString(),
    signal: AbortSignal.timeout(10000),
  });
  const result = await response.json();
  if (!response.ok || typeof result.access_token !== 'string') throw Error('OAuth unavailable');
  cached = { token: result.access_token, expires: Date.now() + Math.min(Number(result.expires_in) || 3600, 3600) * 1000, project: account.project_id };
  return cached.token;
}
Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const url = Deno.env.get('SUPABASE_URL');
  if (!key) return Response.json({ error: 'Push service unavailable' }, { status: 503 });
  if (!url) return Response.json({ error: 'Push service unavailable' }, { status: 503 });
  async function rpc(name: string, params: unknown = {}): Promise<unknown> {
    const response = await fetch(url + '/rest/v1/rpc/' + name, {
      method: 'POST', headers: { apikey: key!, Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' },
      body: JSON.stringify(params), signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) throw Error('Queue unavailable');
    return await response.json();
  }
  if (request.headers.get('Authorization') !== 'Bearer ' + key) {
    const time = request.headers.get('X-Nimzo-Dispatch-Time');
    const nonce = request.headers.get('X-Nimzo-Dispatch-Nonce');
    const signature = request.headers.get('X-Nimzo-Dispatch-Signature');
    if (!time || !nonce || !signature) return Response.json({ error: 'Unauthorized' }, { status: 401 });
    try {
      if (await rpc('authorize_push_dispatch', { p_time: time, p_nonce: nonce, p_signature: signature }) !== true) {
        return Response.json({ error: 'Unauthorized' }, { status: 401 });
      }
    } catch (_) { return Response.json({ error: 'Unauthorized' }, { status: 401 }); }
  }
  try {
    // Fetch server-only credentials from encrypted Vault via a service_role-only RPC.
    // Never return or log this object; no user account can invoke the RPC.
    const account = await rpc('get_push_firebase_service_account') as ServiceAccount;
    if (account?.project_id !== 'nimzo-1f296' ||
        !account.client_email?.endsWith('.iam.gserviceaccount.com') ||
        !account.private_key?.includes('BEGIN PRIVATE KEY')) {
      throw Error('Push credentials unavailable');
    }
    // Obtain credentials before leasing jobs, so an unconfigured sender loses none.
    const access = await googleToken(account);
    const jobs = await rpc('claim_push_batch') as PushJob[];
    let sent = 0;
    for (const job of jobs) {
      let result = 'retry';
      try {
        const response = await fetch('https://fcm.googleapis.com/v1/projects/' + account.project_id + '/messages:send', {
          method: 'POST', headers: { Authorization: 'Bearer ' + access, 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: {
            token: job.device_token,
            notification: { title: 'NIMZO', body: 'Open NIMZO to view your notification.' },
            data: { notification_id: job.notification_id, user_id: job.user_id },
            android: { priority: 'HIGH', ttl: '3600s', notification: { tag: job.notification_id, sound: 'default', channel_id: 'nimzo_activity', default_vibrate_timings: true } },
          } }), signal: AbortSignal.timeout(5000),
        });
        if (response.ok) { result = 'sent'; sent++; }
        else {
          const body = await response.json().catch(() => ({}));
          if (body.error?.details?.some((d: { errorCode?: string }) => d.errorCode === 'UNREGISTERED')) result = 'invalid';
          if (response.status === 401) cached = null;
        }
      } catch (_) { /* Retry after the lease/backoff; never log credentials or tokens. */ }
      await rpc('finish_push', { p_id: job.notification_id, p_token: job.device_token, p_lease: job.lease_id, p_result: result });
    }
    // Empty-queue diagnostic validates FCM API authorization with no real device.
    // An invalid synthetic target is expected to fail validation, never to deliver.
    let validation: string | undefined;
    if (jobs.length === 0) {
      const probe = await fetch('https://fcm.googleapis.com/v1/projects/' + account.project_id + '/messages:send', {
        method: 'POST', headers: { Authorization: 'Bearer ' + access, 'Content-Type': 'application/json' },
        body: JSON.stringify({ validate_only: true, message: { token: 'NIMZO-VALIDATION-NOT-A-DEVICE', notification: { title: 'NIMZO validation' } } }),
        signal: AbortSignal.timeout(5000),
      });
      const result = await probe.json().catch(() => ({}));
      validation = probe.ok ? 'accepted_validate_only' : String(result.error?.status || 'HTTP_' + probe.status);
    }
    return Response.json({ processed: jobs.length, sent, oauth: 'ok', validation });
  } catch (_) { return Response.json({ error: 'Push delivery temporarily unavailable' }, { status: 503 }); }
});
