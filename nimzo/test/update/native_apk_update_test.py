"""Execute production download/hash/redirect policy with an isolated HTTP fixture."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class NativeApkUpdateTest(unittest.TestCase):
    def test_download_integrity_and_trusted_redirect_policy(self):
        javac = shutil.which('javac')
        if not javac:
            local = Path('/workspace/.nimzo-jdk/bin/javac')
            if local.is_file(): javac = str(local)
        if not javac: self.skipTest('Java compiler unavailable')
        source = (ROOT / 'native/vivox/android/NimzoUpdate.java').read_text()
        methods = []
        for name in ('trustedEntry', 'trustedRedirect', 'fetch', 'verifyFile', 'hex'):
            methods.append(re.search(r'  private static [^\n]+ ' + name + r'\([\s\S]*?\n  }', source).group())
        methods.append(re.search(r'  public void onResume\(\)[\s\S]*?\n  }', source).group())
        harness = '''
import java.io.*;
import java.net.*;
import java.security.MessageDigest;
public class NativeUpdateTest {
''' + '\n'.join(methods) + r'''
private final ActivityFixture activity = new ActivityFixture();
private final PendingFixture pending = new PendingFixture();
private final java.util.concurrent.Executor worker = Runnable::run;
private boolean busy, destroyed;
private boolean installerFails;
private int opened;
private void validate(File f,String p,String c,long b){}
private void openInstaller(File f) throws Exception {if(installerFails)throw new IOException();opened++;}
static class ActivityFixture {
 File cache; boolean permission;
 File getCacheDir(){return cache;}
 ActivityFixture getPackageManager(){return this;}
 boolean canRequestPackageInstalls(){return permission;}
 void runOnUiThread(Runnable runnable){runnable.run();}
}
static class PendingFixture {
 java.util.Map<String,Object> values=new java.util.HashMap<>();
 boolean contains(String key){return values.containsKey(key);}
 String getString(String key,String fallback){return (String)values.getOrDefault(key,fallback);}
 long getLong(String key,long fallback){return ((Number)values.getOrDefault(key,fallback)).longValue();}
 PendingFixture edit(){return this;} PendingFixture clear(){values.clear();return this;} void apply(){}
}
private static final class UpdateFailure extends Exception {
 final String code; UpdateFailure(String code) { this.code=code; }
}
static byte[] payload = "verified-apk-fixture".getBytes();
static int response = 200;
static String redirect;
static class Connection extends HttpURLConnection {
 Connection(URL url) { super(url); }
 public void connect() {} public void disconnect() {} public boolean usingProxy(){return false;}
 public int getResponseCode(){return response;}
 public String getHeaderField(String name){return redirect;}
 public InputStream getInputStream(){return new ByteArrayInputStream(payload);}
}
static URL fixture() throws Exception {
 return new URL(null,"https://github.com/adi4ch-cmd/Nimzo/releases/download/test/app-release.apk",
 new URLStreamHandler(){protected URLConnection openConnection(URL url){return new Connection(url);}});
}
static void require(boolean condition){if(!condition)throw new AssertionError();}
public static void main(String[] args) throws Exception {
 require(trustedEntry(fixture()));
 for(String bad:new String[]{"http://github.com/adi4ch-cmd/Nimzo/releases/download/test/app-release.apk",
 "https://github.com/other/Nimzo/releases/download/test/app-release.apk",
 "https://github.com/adi4ch-cmd/Nimzo/releases/download/test/app-release.apk?key=x"})
 require(!trustedEntry(new URL(bad)));
 require(trustedRedirect(new URL("https://release-assets.githubusercontent.com/asset?token=fixture")));
 require(!trustedRedirect(new URL("https://attacker.invalid/asset")));
 require(!trustedRedirect(new URL("http://github.com/asset")));
 File file=File.createTempFile("nimzo-update-test", ".apk");
 try {
  String digest=hex(MessageDigest.getInstance("SHA-256").digest(payload));
  fetch(fixture(),file,digest);
  verifyFile(file,digest);
  require(java.util.Arrays.equals(java.nio.file.Files.readAllBytes(file.toPath()),payload));
  try{fetch(fixture(),file,"0".repeat(64));throw new AssertionError();}
  catch(UpdateFailure expected){require(expected.code.equals("UPDATE_CHECKSUM"));}
  java.nio.file.Files.write(file.toPath(), "tampered".getBytes());
  try{verifyFile(file,digest);throw new AssertionError();}
  catch(UpdateFailure expected){require(expected.code.equals("UPDATE_CHECKSUM"));}
  response=302;redirect="https://attacker.invalid/file";
  try{fetch(fixture(),file,digest);throw new AssertionError();}
  catch(UpdateFailure expected){require(expected.code.equals("UPDATE_REDIRECT"));}
  response=200;payload=new byte[0];
  try{fetch(fixture(),file,digest);throw new AssertionError();}
  catch(UpdateFailure expected){require(expected.code.equals("UPDATE_CHECKSUM"));}
 } finally {file.delete();}
 File cache=java.nio.file.Files.createTempDirectory("nimzo-permission-resume").toFile();
 File updates=new File(cache,"nimzo_updates");updates.mkdir();File cached=new File(updates,"update.apk");
 byte[] original="verified-resume-fixture".getBytes();java.nio.file.Files.write(cached.toPath(),original);
 String digest=hex(MessageDigest.getInstance("SHA-256").digest(original));
 NativeUpdateTest initial=new NativeUpdateTest();initial.activity.cache=cache;
 initial.pending.values.put("build",107L);initial.pending.values.put("sha256",digest);
 initial.onResume();require(initial.opened==0 && initial.pending.contains("build"));
 NativeUpdateTest recreated=new NativeUpdateTest();recreated.activity.cache=cache;recreated.activity.permission=true;
 recreated.pending.values=initial.pending.values;recreated.onResume();
 require(recreated.opened==1 && !recreated.pending.contains("build"));
 recreated.pending.values.put("build",107L);recreated.pending.values.put("sha256",digest);recreated.installerFails=true;
 recreated.onResume();require(android.widget.Toast.shown==1 && !recreated.pending.contains("build"));
 recreated.installerFails=false;recreated.pending.values.put("build",107L);recreated.pending.values.put("sha256",digest);
 java.nio.file.Files.write(cached.toPath(),"tampered".getBytes());recreated.onResume();
 require(recreated.opened==1 && android.widget.Toast.shown==2);
 cached.delete();updates.delete();cache.delete();
}
}
'''
        with tempfile.TemporaryDirectory(prefix='nimzo-update-native-') as temporary:
            folder = Path(temporary)
            clock = folder / 'android/os/SystemClock.java'; clock.parent.mkdir(parents=True)
            clock.write_text('package android.os; public class SystemClock { public static long elapsedRealtime(){return System.nanoTime()/1000000;} }')
            build = folder / 'android/os/Build.java'
            build.write_text('package android.os; public class Build { public static class VERSION { public static int SDK_INT=36; } }')
            toast = folder / 'android/widget/Toast.java'; toast.parent.mkdir(parents=True)
            toast.write_text('package android.widget; public class Toast { public static int shown; public static final int LENGTH_LONG=1; public static Toast makeText(Object context,String message,int duration){return new Toast();} public void show(){shown++;} }')
            harness = 'import android.os.Build;\nimport android.widget.Toast;\n' + harness
            java = folder / 'NativeUpdateTest.java'; java.write_text(harness)
            subprocess.run([javac, '-d', str(folder), str(java), str(clock), str(build), str(toast)], check=True)
            executable = str(Path(javac).with_name('java'))
            subprocess.run([executable, '-cp', str(folder), 'NativeUpdateTest'], check=True)
