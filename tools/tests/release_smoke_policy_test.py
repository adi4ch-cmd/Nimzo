"""A release artifact must depend on successful installation/startup."""
import pathlib
import unittest

class ReleaseSmokePolicy(unittest.TestCase):
    def test_failed_launch_cannot_publish_verified_apk(self):
        text = pathlib.Path('.github/workflows/nimzo-full-integration-apk.yml').read_text()
        launch = text.index('      - name: Install and launch release APK')
        upload = text.index('      - name: Upload verified release-mode APK artifact')
        self.assertLess(launch, upload)
        self.assertNotIn('continue-on-error: true', text[launch:upload])
        self.assertNotIn('if: always()', text[launch:upload])

    def test_generated_host_preserves_reviewed_dependencies(self):
        text = pathlib.Path('.github/workflows/nimzo-full-integration-apk.yml').read_text()
        create = text.index('flutter create . --no-pub')
        restore = text.index('git restore --source=HEAD -- pubspec.lock')
        resolve = text.index('flutter pub get --enforce-lockfile')
        self.assertLess(create, restore)
        self.assertLess(restore, resolve)

if __name__ == '__main__':
    unittest.main()
