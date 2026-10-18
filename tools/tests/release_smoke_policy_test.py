"""A release artifact must depend on successful installation/startup."""
import pathlib
import unittest

class ReleaseSmokePolicy(unittest.TestCase):
    def test_failed_launch_cannot_publish_verified_apk(self):
        text = pathlib.Path('.github/workflows/nimzo-final-release-apk.yml').read_text()
        launch = text.index('      - name: Install and launch release APK')
        upload = text.index('      - name: Upload verified release-mode APK artifact')
        self.assertLess(launch, upload)
        self.assertNotIn('continue-on-error: true', text[launch:upload])
        self.assertNotIn('if: always()', text[launch:upload])

if __name__ == '__main__':
    unittest.main()
