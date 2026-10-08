/** Validate provider-owned purchase fields; caller prices and balances are never trusted. */
export function requireGooglePurchase(data: any, userId: string): "production" {
  if (!data || Number(data.purchaseState) !== 0) throw new Error("Google purchase is not completed");
  if (!userId || data.obfuscatedExternalAccountId !== userId) throw new Error("Purchase account binding does not match this account");
  if (data.purchaseType === 0) throw new Error("Sandbox purchase verified; live coins are not credited");
  if (data.purchaseType != null) throw new Error("Promotional purchase settlement is not supported");
  if (data.quantity != null && Number(data.quantity) !== 1) throw new Error("Multi-quantity purchases are not supported");
  return "production";
}
