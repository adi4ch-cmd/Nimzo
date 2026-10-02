import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
const b64url = (input: Uint8Array | string) => { const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input; let s = ""; for (const b of bytes) s += String.fromCharCode(b); return btoa(s).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", ""); };
function pemToBytes(pem: string) { const raw = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, ""); const bin = atob(raw); return Uint8Array.from(bin, c => c.charCodeAt(0)); }
async function googleAccessToken(serviceAccountJson: string) {
  const sa = JSON.parse(serviceAccountJson); const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = b64url(JSON.stringify({ iss: sa.client_email, scope: "https://www.googleapis.com/auth/androidpublisher", aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600 }));
  const unsigned = header + "." + payload;
  const key = await crypto.subtle.importKey("pkcs8", pemToBytes(sa.private_key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)));
  const assertion = unsigned + "." + b64url(sig);
  const response = await fetch("https://oauth2.googleapis.com/token", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }) });
  const data = await response.json(); if (!response.ok || !data.access_token) throw new Error("Google token exchange failed"); return data.access_token as string;
}
async function verifyGoogle(productId: string, token: string) {
  const service = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT"); if (!service) throw new Error("Google Play verification is not configured");
  const access = await googleAccessToken(service);
  const url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/io.nimzo.nimzo/purchases/products/" + encodeURIComponent(productId) + "/tokens/" + encodeURIComponent(token);
  const r = await fetch(url, { headers: { Authorization: "Bearer " + access } }); const data = await r.json();
  if (!r.ok) throw new Error("Google purchase verification failed"); if (Number(data.purchaseState) !== 0) throw new Error("Google purchase is not completed");
  return { transactionId: String(token), ok: true };
}
async function verifyApple(productId: string, receipt: string) {
  const secret = Deno.env.get("APP_STORE_SHARED_SECRET"); if (!secret) throw new Error("Apple App Store verification is not configured");
  const body = JSON.stringify({ "receipt-data": receipt, password: secret, "exclude-old-transactions": false });
  let r = await fetch("https://buy.itunes.apple.com/verifyReceipt", { method: "POST", headers: { "Content-Type": "application/json" }, body }); let data = await r.json();
  if (data.status === 21007) { r = await fetch("https://sandbox.itunes.apple.com/verifyReceipt", { method: "POST", headers: { "Content-Type": "application/json" }, body }); data = await r.json(); }
  if (!r.ok || data.status !== 0) throw new Error("Apple purchase verification failed");
  const entries = [...(Array.isArray(data.latest_receipt_info) ? data.latest_receipt_info : []), ...(Array.isArray(data.receipt?.in_app) ? data.receipt.in_app : [])];
  const match = entries.filter((x: any) => String(x.product_id) === productId).sort((a: any, b: any) => Number(b.purchase_date_ms ?? 0) - Number(a.purchase_date_ms ?? 0))[0];
  if (!match?.transaction_id) throw new Error("Apple product/receipt mismatch"); return { transactionId: String(match.transaction_id), ok: true };
}
Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const auth = req.headers.get("Authorization"); if (!auth?.startsWith("Bearer ")) return json({ error: "Unauthorized" }, 401);
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!; const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } }); const token = auth.slice(7);
  const { data: userData, error: userError } = await admin.auth.getUser(token); if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);
  const body = await req.json().catch(() => ({})); const raw = String(body.store ?? "").toLowerCase();
  const store = raw === "google" || raw === "google_play" ? "google_play" : raw === "apple" || raw === "app_store" ? "app_store" : "";
  const productId = String(body.product_id ?? ""); const receipt = String(body.receipt ?? "");
  if (!store || !productId || !receipt) return json({ error: "Invalid purchase request" }, 400);
  try {
    const verified = store === "google_play" ? await verifyGoogle(productId, receipt) : await verifyApple(productId, receipt);
    const { error } = await admin.rpc("apply_recharge", { p_user: userData.user.id, p_store: store, p_txn: verified.transactionId, p_product: productId });
    if (error) { console.error("apply_recharge failed", error); return json({ error: "Purchase verified but settlement failed; retry is safe" }, 502); }
    return json({ ok: true, store, product_id: productId, transaction_id: verified.transactionId });
  } catch (e) { console.error(e); return json({ error: e instanceof Error ? e.message : "Purchase verification failed" }, 400); }
});