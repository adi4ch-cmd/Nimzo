import "jsr:@supabase/functions-js/edge-runtime.d.ts";

function b64url(input: Uint8Array): string {
  let s = "";
  for (const b of input) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
function enc(v: unknown): string {
  return b64url(new TextEncoder().encode(JSON.stringify(v)));
}
async function sign(payload: unknown, secret: string): Promise<string> {
  const data = "e30." + enc(payload);
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign(
    "HMAC", key, new TextEncoder().encode(data),
  ));
  return data + "." + b64url(sig);
}
function safeName(v: string): string {
  return v.replace(/[^A-Za-z0-9_-]/g, "_").slice(0, 64);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const vivoxServer = Deno.env.get("VIVOX_SERVER");
  const vivoxDomain = Deno.env.get("VIVOX_DOMAIN");
  const vivoxIssuer = Deno.env.get("VIVOX_TOKEN_ISSUER");
  const vivoxKey = Deno.env.get("VIVOX_TOKEN_KEY");

  if (!supabaseUrl || !serviceKey || !vivoxServer || !vivoxDomain || !vivoxIssuer || !vivoxKey) {
    return Response.json({ error: "Vivox voice service is not configured" }, { status: 503 });
  }

  const session = await fetch(supabaseUrl + "/auth/v1/user", {
    headers: { apikey: serviceKey, Authorization: auth },
  });
  if (!session.ok) return Response.json({ error: "Invalid session" }, { status: 401 });

  const user = await session.json();
  const body = await req.json().catch(() => ({}));
  const room = String(body.room ?? "").trim();
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(room)) {
    return Response.json({ error: "Invalid room" }, { status: 400 });
  }
  const accessResponse = await fetch(supabaseUrl + "/rest/v1/rpc/voice_access", {
    method: "POST",
    headers: { apikey: serviceKey, Authorization: "Bearer " + serviceKey, "Content-Type": "application/json" },
    body: JSON.stringify({ p_room: room, p_user: user.id }),
  });
  if (!accessResponse.ok) return Response.json({ error: "Voice authorization unavailable" }, { status: 503 });
  const access = await accessResponse.json();
  if (access.allowed !== true) return Response.json({ error: "Join the room before connecting voice" }, { status: 403 });

  const accountName = safeName(String(user.id));
  const accountUri = "sip:." + vivoxIssuer + "." + accountName + "@" + vivoxDomain;
  const channelUri = "sip:confctl-g-" + room + "@" + vivoxDomain;
  const now = Math.floor(Date.now() / 1000);
  const exp = now + 90;
  const vxi = Date.now();

  const loginToken = await sign({
    iss: vivoxIssuer,
    exp,
    vxa: "login",
    vxi,
    f: accountUri,
  }, vivoxKey);

  const channelToken = await sign({
    iss: vivoxIssuer,
    exp,
    vxa: "join",
    vxi: vxi + 1,
    f: accountUri,
    t: channelUri,
  }, vivoxKey);

  return Response.json({
    loginToken,
    channelToken,
    server: vivoxServer,
    accountUri,
    channelUri,
    expiresAt: exp,
    canTransmit: access.canTransmit === true,
  });
});