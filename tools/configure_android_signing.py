"""Install only a supplied existing signing identity in generated Android Gradle."""
from pathlib import Path


def configure(path: Path) -> None:
    source = path.read_text()
    kotlin = path.suffix == '.kts'
    if kotlin:
        source = source.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
        block = '''
android {
    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("NIMZO_KEYSTORE_PATH"))
            storePassword = System.getenv("NIMZO_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("NIMZO_KEY_ALIAS")
            keyPassword = System.getenv("NIMZO_KEY_PASSWORD")
        }
    }
}
'''
    else:
        raise ValueError('Only generated Kotlin Gradle projects are supported')
    # Define release signing before the generated buildTypes references it.
    if 'signingConfigs.getByName("release")' not in source and 'signingConfig signingConfigs.release' not in source:
        raise ValueError('Generated release signing selection was not recognized')
    path.write_text(source.replace('android {', block + '\nandroid {', 1))


if __name__ == '__main__':
    import sys
    configure(Path(sys.argv[1]))
