import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireGooglePurchase } from "./purchase_contract.ts";
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
async function verifyGoogle(productId: string, token: string, userId: string) {
  const service = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT"); if (!service) throw new Error("Google Play verification is not configured");
  const access = await googleAccessToken(service);
  const packageName = Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME")?.trim() || "io.nimzo.app";
  const url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" + encodeURIComponent(packageName) + "/purchases/products/" + encodeURIComponent(productId) + "/tokens/" + encodeURIComponent(token);
  const r = await fetch(url, { headers: { Authorization: "Bearer " + access } }); const data = await r.json();
  if (!r.ok) throw new Error("Google purchase verification failed");
  const environment = requireGooglePurchase(data, userId);
  return { transactionId: String(token), ok: true, environment };
}
async function verifyApple(productId: string, receipt: string, transactionId: string) {
  const secret = Deno.env.get("APP_STORE_SHARED_SECRET"); if (!secret) throw new Error("Apple App Store verification is not configured");
  const body = JSON.stringify({ "receipt-data": receipt, password: secret, "exclude-old-transactions": false });
  let r = await fetch("https://buy.itunes.apple.com/verifyReceipt", { method: "POST", headers: { "Content-Type": "application/json" }, body }); let data = await r.json();
  if (data.status === 21007) { r = await fetch("https://sandbox.itunes.apple.com/verifyReceipt", { method: "POST", headers: { "Content-Type": "application/json" }, body }); data = await r.json(); }
  if (!r.ok || data.status !== 0) throw new Error("Apple purchase verification failed");
  const bundleId = Deno.env.get("APP_STORE_BUNDLE_ID")?.trim() || "io.nimzo.app";
  if (String(data.receipt?.bundle_id ?? "") !== bundleId) throw new Error("Apple bundle/receipt mismatch");
  const entries = [...(Array.isArray(data.latest_receipt_info) ? data.latest_receipt_info : []), ...(Array.isArray(data.receipt?.in_app) ? data.receipt.in_app : [])];
  const match = entries.filter((x: any) => String(x.product_id) === productId && !x.cancellation_date && !x.cancellation_date_ms && (!transactionId || String(x.transaction_id) === transactionId)).sort((a: any, b: any) => Number(b.purchase_date_ms ?? 0) - Number(a.purchase_date_ms ?? 0))[0];
  if (!match?.transaction_id) throw new Error("Apple product/receipt mismatch"); return { transactionId: String(match.transaction_id), ok: true };
}
Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const auth = req.headers.get("Authorization"); if (!auth?.startsWith("Bearer ")) return json({ error: "Unauthorized" }, 401);
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!; const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } }); const token = auth.slice(7);
  const { data: userData, error: userError } = await admin.auth.getUser(token); if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);
  const body = await req.json().catch(() => ({}));
  if (!body || typeof body !== "object" || Array.isArray(body)) return json({error: "Invalid purchase request"}, 400);
  if (body.action === "configuration") return json({account_binding: true,
    ready_stores: Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT")?.trim() ? ["google_play"] : [],
    environment: "store-managed"});
  const raw = String(body.store ?? "").toLowerCase();
  const store = raw === "google" || raw === "google_play" ? "google_play" : raw === "apple" || raw === "app_store" ? "app_store" : "";
  const productId = String(body.product_id ?? ""); const receipt = String(body.receipt ?? "");
  if (!store || !productId || productId.length > 200 || !receipt || receipt.length > 16384) return json({ error: "Invalid purchase request" }, 400);
  if (store === "app_store") return json({error: "Apple purchase account binding verification is not configured"}, 503);
  try {
    const verified = await verifyGoogle(productId, receipt, userData.user.id);
    const { data: settlement, error } = await admin.rpc("apply_recharge", { p_user: userData.user.id, p_store: store, p_txn: verified.transactionId, p_product: productId });
    if (error) { console.error("apply_recharge failed"); return json({ error: "Purchase verified but settlement failed; retry is safe" }, 502); }
    if (!settlement || !["credited", "replayed"].includes(settlement.status)
      || settlement.product_id !== productId || settlement.transaction_id !== verified.transactionId
      || !Number.isSafeInteger(settlement.coins) || settlement.coins <= 0) {
      console.error("apply_recharge returned an unconfirmed settlement");
      return json({ error: "Purchase settlement was not confirmed; retry is safe" }, 502);
    }
    return json({ ok: true, status: settlement.status, coins: settlement.coins, store, product_id: productId, transaction_id: verified.transactionId, environment: verified.environment });
  } catch (e) {
    const safeErrors = ["Google Play verification is not configured", "Google token exchange failed", "Google purchase verification failed", "Google purchase is not completed", "Purchase account binding does not match this account", "Sandbox purchase verified; live coins are not credited", "Promotional purchase settlement is not supported", "Multi-quantity purchases are not supported"];
    const message = e instanceof Error && safeErrors.includes(e.message) ? e.message : "Purchase verification failed";
    console.error("Purchase verification failed"); return json({error: message}, 400);
  }
});