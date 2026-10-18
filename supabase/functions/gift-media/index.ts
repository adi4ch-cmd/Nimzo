const REGISTRY: Record<string, string> = {
  '53f6278f-1770-5be9-ae07-329c34f36c47': 'hall-of-fame/v1',
  '5e07ac17-491a-4a26-a48b-e6701445705f': 'dragon-throne/v2',
  '629b0f33-55b5-5084-8488-865869e9ab39': 'ice-fire-phoenix/v2',
  '2f869219-7cdd-531b-9715-c5d8c9cd864d': 'holy-tiger/v3',
};
const BUCKET = 'nimzo-private-gifts';
// Upload bootstrap entries are deployed separately and removed after ingestion.
const BOOTSTRAP: Array<{tokenHash:string;path:string;sha256:string;size:number;type:string;expires:number}> = [];
const json = (status:number, body:unknown) => new Response(JSON.stringify(body),
 {status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
const sha256 = async (bytes:BufferSource) => Array.from(new Uint8Array(
 await crypto.subtle.digest('SHA-256',bytes))).map(x=>x.toString(16).padStart(2,'0')).join('');
Deno.serve(async (req:Request) => {
 try {
  if(req.method!=='POST') return json(405,{error:'POST required'});
  const base=Deno.env.get('SUPABASE_URL')!;
  const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const admin={apikey:service,Authorization:`Bearer ${service}`};
  const uploadToken=req.headers.get('x-nimzo-upload-token');
  if(uploadToken){
   const hash=await sha256(new TextEncoder().encode(uploadToken));
   const permit=BOOTSTRAP.find(x=>x.tokenHash===hash && x.expires>Date.now());
   if(!permit) return json(401,{error:'Unauthorized'});
   if(Number(req.headers.get('content-length'))!==permit.size) return json(413,{error:'Size mismatch'});
   const bytes=await req.arrayBuffer();
   if(bytes.byteLength!==permit.size || await sha256(bytes)!==permit.sha256) return json(400,{error:'Digest mismatch'});
   const bucket=await fetch(`${base}/storage/v1/bucket`,{method:'POST',headers:{...admin,'Content-Type':'application/json'},body:JSON.stringify({id:BUCKET,name:BUCKET,public:false,file_size_limit:12000000,allowed_mime_types:['video/mp4','image/png']})});
   if(!bucket.ok && bucket.status!==400 && bucket.status!==409) return json(502,{error:'Bucket setup failed'});
   const path=permit.path.split('/').map(encodeURIComponent).join('/');
   const result=await fetch(`${base}/storage/v1/object/${BUCKET}/${path}`,{method:'POST',headers:{...admin,'Content-Type':permit.type,'x-upsert':'false'},body:bytes});
   return json(result.ok?201:502,{uploaded:result.ok,path:permit.path,status:result.status});
  }
  const authorization=req.headers.get('authorization')??'';
  if(!/^Bearer \S+$/.test(authorization)) return json(401,{error:'Sign in required'});
  const userResult=await fetch(`${base}/auth/v1/user`,{headers:{apikey:service,Authorization:authorization}});
  if(!userResult.ok) return json(401,{error:'Invalid session'});
  const user=await userResult.json();
  const body=await req.json();const giftId=String(body.gift_id??'');
  const directory=REGISTRY[giftId];
  if(!directory || !['animation','thumbnail'].includes(body.kind)) return json(400,{error:'Unsupported media'});
  const profiles=await fetch(`${base}/rest/v1/profiles?id=eq.${user.id}&status=eq.active&select=id`,{headers:admin});
  const profileRows=profiles.ok?await profiles.json():[];
  if(!profileRows.length) return json(403,{error:'Account unavailable'});
  if(body.kind==='animation'){
   const since=encodeURIComponent(new Date(Date.now()-120000).toISOString());
   // Evaluate existing event RLS as the viewer, not as service_role.
   const events=await fetch(`${base}/rest/v1/gift_animation_events?gift_id=eq.${giftId}&created_at=gte.${since}&select=id&limit=1`,{headers:{apikey:service,Authorization:authorization}});
   const rows=events.ok?await events.json():[];
   let paid=rows.length>0;
   if(!paid){
    const payments=await fetch(`${base}/rest/v1/ledger?user_id=eq.${user.id}&coin_delta=lt.0&ref-%3E%3Egift=eq.${giftId}&created_at=gte.${since}&select=id&limit=1`,{headers:admin});
    paid=payments.ok && (await payments.json()).length>0;
   }
   if(!paid) return json(403,{error:'Recent verified gift required'});
  }
  const object=`${directory}/${body.kind==='animation'?'video.mp4':'thumbnail.png'}`;
  const response=await fetch(`${base}/storage/v1/object/sign/${BUCKET}/${object}`,{method:'POST',headers:{...admin,'Content-Type':'application/json'},body:JSON.stringify({expiresIn:60})});
  if(!response.ok) return json(503,{error:'Gift media unavailable'});
  const signed=await response.json();
  const path=signed.signedURL??signed.signedUrl;
  if(typeof path!=='string') return json(503,{error:'Gift media unavailable'});
  return json(200,{url:path.startsWith('https://')?path:`${base}/storage/v1${path}`,expires_in:60});
 } catch { return json(500,{error:'Gift media unavailable'}); }
});
