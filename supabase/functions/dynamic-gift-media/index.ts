// NIMZO signed private gift playback — new gifts only.
// Existing gift-media gateway for legacy four IDs remains untouched.
// Only a visible, recently settled server gift event permits playback.
const BUCKET = 'nimzo-private-gifts';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MIME = {'Content-Type':'application/json','Cache-Control':'no-store',
  'Access-Control-Allow-Origin':'*'};
const reply=(status:number, data:unknown) =>
  new Response(JSON.stringify(data),{status,headers:MIME});

Deno.serve(async (req:Request) => {
  try {
    if(req.method==='OPTIONS') return new Response(null,{
      status:204,headers:{...MIME,
        'Access-Control-Allow-Headers':'authorization,apikey,content-type',
        'Access-Control-Allow-Methods':'POST,OPTIONS'}});
    if(req.method!=='POST') return reply(405,{error:'POST required'});
    const token=req.headers.get('authorization')??'';
    if(!/^Bearer \\S+$/.test(token)) return reply(401,{error:'Sign in required'});
    if(Number(req.headers.get('content-length')??'0')>4096)
      return reply(413,{error:'Invalid request'});
    const raw=await req.text();
    if(raw.length>4096) return reply(413,{error:'Invalid request'});
    const body=JSON.parse(raw) as Record<string,unknown>;
    const giftId=body.gift_id;
    if(typeof giftId!=='string'||!UUID.test(giftId))
      return reply(400,{error:'Invalid gift'});
    const base=Deno.env.get('SUPABASE_URL');
    const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if(!base||!service) return reply(503,{error:'Playback temporarily unavailable'});
    const admin={apikey:service,Authorization:'Bearer '+service};
    const userResponse=await fetch(base+'/auth/v1/user',{
      headers:{apikey:service,Authorization:token}});
    if(!userResponse.ok) return reply(401,{error:'Invalid session'});
    const user=await userResponse.json() as {id?:string};
    if(!user.id||!UUID.test(user.id)) return reply(401,{error:'Invalid session'});

    // The auth user's account must still be active, regardless of cached JWT.
    const profileResult=await fetch(base+'/rest/v1/profiles?id=eq.'+
      encodeURIComponent(user.id)+'&status=eq.active&select=id&limit=1',
      {headers:admin});
    const profiles=profileResult.ok?await profileResult.json():[];
    if(!Array.isArray(profiles)||profiles.length!==1)
      return reply(403,{error:'Account unavailable'});
    // Private mapping and SHA never reach the app or an unauthenticated user.
    const mediaResponse=await fetch(base+'/rest/v1/nimzo_private_gift_media?gift_id=eq.'+
      encodeURIComponent(giftId)+'&approved=eq.true&select=storage_path,media_kind,duration_ms&limit=1',
      {headers:admin});
    if(!mediaResponse.ok) return reply(503,{error:'Playback unavailable'});
    const media=await mediaResponse.json();
    if(!Array.isArray(media)||media.length!==1)
      return reply(404,{error:'Approved media unavailable'});
    const item=media[0] as {storage_path:string,media_kind:string,duration_ms:number};
    if(!/^dynamic\/[a-zA-Z0-9_/-]{5,200}\/[a-f0-9]{64}[.]mp4$/.test(item.storage_path) ||
       !['vap','mp4'].includes(item.media_kind) ||
       !Number.isInteger(item.duration_ms) ||
       item.duration_ms<1000||item.duration_ms>30000)
      return reply(503,{error:'Invalid server media'});

    const giftResult=await fetch(base+'/rest/v1/gifts?id=eq.'+
      encodeURIComponent(giftId)+'&active=eq.true&select=id&limit=1',
      {headers:admin});
    const gifts=giftResult.ok?await giftResult.json():[];
    if(!Array.isArray(gifts)||gifts.length!==1)
      return reply(404,{error:'Gift unavailable'});

    // Important: this query uses the VIEWER JWT so PostgREST applies the
    // existing room_members/country gift_animation_events RLS policy.
    // The edge never accepts an event ID from the client.
    const since=encodeURIComponent(new Date(Date.now()-120000).toISOString());
    const eventResult=await fetch(base+'/rest/v1/gift_animation_events?gift_id=eq.'+
      encodeURIComponent(giftId)+'&created_at=gte.'+since+
      '&select=id&limit=1',{headers:{
        apikey:service,Authorization:token}});
    const events=eventResult.ok?await eventResult.json():[];
    if(!Array.isArray(events)||events.length===0)
      return reply(403,{error:'Recent verified room gift required'});

    const object=item.storage_path.split('/').map(encodeURIComponent).join('/');
    const signed=await fetch(base+'/storage/v1/object/sign/'+BUCKET+'/'+object,{
      method:'POST',headers:{...admin,'Content-Type':'application/json'},
      body:JSON.stringify({expiresIn:75})});
    if(!signed.ok) return reply(503,{error:'Gift playback unavailable'});
    const json=await signed.json();
    const path=json.signedURL??json.signedUrl;
    if(typeof path!=='string') return reply(503,{error:'Gift playback unavailable'});
    const url=path.startsWith('https://')?path:base+'/storage/v1'+path;
    return reply(200,{url,media_kind:item.media_kind,
      duration_ms:item.duration_ms,expires_in:75});
  }catch {
    return reply(500,{error:'Gift playback unavailable'});
  }
});
