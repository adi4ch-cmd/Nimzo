// Supabase Edge Function: verify-purchase  (UNTESTED. Needs your store credentials.)
// Verifies a store receipt with Google Play / App Store using SERVER-HELD secrets,
// then calls apply_recharge with the service role. The client price is never trusted:
// coins and price come from recharge_packages.
//
// Secrets to set:  supabase secrets set GOOGLE_SA_JSON=... ANDROID_PACKAGE=... APPLE_ISSUER_ID=... APPLE_KEY_ID=... APPLE_PRIVATE_KEY=... APPLE_BUNDLE_ID=...
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const b64u = (b: ArrayBuffer | string) =>
  btoa(typeof b === "string" ? b : String.fromCharCode(...new Uint8Array(b))).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");

async function signJwt(alg: "RS256" | "ES256", pem: string, header: Record<string, unknown>, claims: Record<string, unknown>) {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der,
    alg === "RS256" ? { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" } : { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const input = `${b64u(JSON.stringify({ alg, typ: "JWT", ...header }))}.${b64u(JSON.stringify(claims))}`;
  const sig = await crypto.subtle.sign(alg === "RS256" ? "RSASSA-PKCS1-v1_5" : { name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input));
  return `${input}.${b64u(sig)}`;
}

async function verifyGoogle(productId: string, token: string): Promise<string> {
  const sa = JSON.parse(Deno.env.get("GOOGLE_SA_JSON")!);
  const now = Math.floor(Date.now() / 1000);
  const jwt = await signJwt("RS256", sa.private_key, {}, {
    iss: sa.client_email, scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600 });
  const tok = await (await fetch("https://oauth2.googleapis.com/token", { method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }) })).json();
  const pkg = Deno.env.get("ANDROID_PACKAGE")!;
  const res = await fetch(`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${pkg}/purchases/products/${productId}/tokens/${token}`,
    { headers: { Authorization: `Bearer ${tok.access_token}` } });
  const p = await res.json();
  if (!res.ok || p.purchaseState !== 0) throw new Error("google purchase not valid");
  return token; // use the purchase token as the unique transaction id (idempotency key)
}

async function verifyApple(transactionId: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const jwt = await signJwt("ES256", Deno.env.get("APPLE_PRIVATE_KEY")!, { kid: Deno.env.get("APPLE_KEY_ID") },
    { iss: Deno.env.get("APPLE_ISSUER_ID"), iat: now, exp: now + 1800, aud: "appstoreconnect-v1", bid: Deno.env.get("APPLE_BUNDLE_ID") });
  const res = await fetch(`https://api.storekit.itunes.apple.com/inApps/v1/transactions/${transactionId}`, { headers: { Authorization: `Bearer ${jwt}` } });
  if (!res.ok) throw new Error("apple transaction not found");
  return transactionId;
}

Deno.serve(async (req) => {
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const authed = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization")! } } });
    const { data: { user } } = await authed.auth.getUser();
    if (!user) return new Response("unauthorized", { status: 401 });

    const { store, product_id, receipt } = await req.json();
    const txn = store === "google" ? await verifyGoogle(product_id, receipt)
              : store === "apple" ? await verifyApple(receipt) : (() => { throw new Error("bad store"); })();

    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);  // server only
    const { error } = await admin.rpc("apply_recharge", { p_user: user.id, p_store: store, p_txn: txn, p_product: product_id });
    if (error) throw error;
    return Response.json({ ok: true });
  } catch (e) {
    return Response.json({ ok: false, error: String(e) }, { status: 400 });
  }
});
