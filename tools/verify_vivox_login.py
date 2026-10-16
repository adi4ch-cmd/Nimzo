"""Verify packaged JNI uses the Unity Vivox Access Token login request."""
import sys
import zipfile


def verify(apk):
    with zipfile.ZipFile(apk) as archive:
        for abi in ('arm64-v8a', 'armeabi-v7a', 'x86_64'):
            bridge = archive.read(f'lib/{abi}/libvivox_bridge.so')
            if b'vx_req_account_anonymous_login_create' not in bridge:
                raise ValueError(f'{abi}: Access Token login request missing')
            if b'vx_req_account_authtoken_login_create' in bridge:
                raise ValueError(f'{abi}: legacy auth-ticket login retained')
    print('Three-ABI Vivox Access Token login request: PASS')


if __name__ == '__main__':
    verify(sys.argv[1])
