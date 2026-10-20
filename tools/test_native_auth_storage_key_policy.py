#!/usr/bin/env python3
"""Execute the Android bridge's actual Java key predicate against SDK keys."""
from pathlib import Path
import re
import subprocess
import tempfile
import sys

path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("nimzo/native/voice_disabled/android/MainActivity.java")
source = path.read_text()
match = re.search(r'if \((key == null[\s\S]+?)\) \{\s*result.error\("STORAGE_KEY_INVALID"', source)
if not match:
    raise SystemExit("Native auth storage key policy not found")
predicate = match.group(1)
java = """
class AuthStoragePolicyTest {
  static boolean accepts(String key) { return !(PREDICATE); }
  static void check(String key, boolean expected) {
    if (accepts(key) != expected) throw new AssertionError("Incorrect key policy: " + key);
  }
  public static void main(String[] args) {
    check("sb-kvqvlpozqokwarovwmwv-auth-token", true);
    check("SUPABASE_PERSIST_SESSION_KEY", true);
    // gotrue 2.27.2 Constants.defaultStorageKey + "-code-verifier".
    // getOAuthSignInUrl, exchangeCodeForSession and signOut use this key.
    check("supabase.auth.token-code-verifier", true);
    check("supabase.auth.token-code-verifier-extra", false);
    check("other_application_secret", false);
    check("sb-project/../secret", false);
    check("sb-" + "x".repeat(221), false);
    check(null, false);
    System.out.println("Native session and SDK PKCE key policy: PASS");
  }
}
""".replace("PREDICATE", predicate)
with tempfile.TemporaryDirectory() as directory:
    file = Path(directory) / "AuthStoragePolicyTest.java"
    file.write_text(java)
    subprocess.run(["java", str(file)], check=True)
