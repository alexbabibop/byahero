"""I-wire ang sarili mong signing keystore sa android/app/build.gradle.kts.

Ginagawa lang ito kung may ANDROID_KEYSTORE_BASE64 secret, kaya kapag wala,
gumagamit pa rin ang debug key (bago-bago ang SHA-1).

Idinagdag ito bilang hiwalay na file (hindi inline sa workflow) dahil ang
YAML block scalar natatapos sa linyang mas mababa ang indent — kaya may
dagdag na syntax error sa workflow file.
"""

import pathlib
import sys

GRADLE = pathlib.Path("android/app/build.gradle.kts")

SIGNING_BLOCK = """    signingConfigs {
        create("release") {
            storeFile = file("upload-keystore.jks")
            storePassword = System.getenv("KS_STORE_PASS")
            keyAlias = System.getenv("KS_KEY_ALIAS")
            keyPassword = System.getenv("KS_KEY_PASS")
        }
    }

"""

DEBUG_SIGNING = 'signingConfig = signingConfigs.getByName("debug")'
RELEASE_SIGNING = 'signingConfig = signingConfigs.getByName("release")'


def main() -> int:
    if not GRADLE.exists():
        print(f"ERROR: {GRADLE} not found (nakalimutang mag-run ng flutter create?)")
        return 1

    text = GRADLE.read_text(encoding="utf-8")

    if "upload-keystore.jks" in text:
        print("keystore already configured — nothing to do")
        return 0

    if "android {\n" not in text:
        print("ERROR: 'android {' block not found in build.gradle.kts")
        return 1

    text = text.replace("android {\n", "android {\n" + SIGNING_BLOCK, 1)

    if text.count(DEBUG_SIGNING) != 1:
        print("ERROR: expected exactly one debug signingConfig line")
        return 1
    text = text.replace(DEBUG_SIGNING, RELEASE_SIGNING)

    GRADLE.write_text(text, encoding="utf-8")
    print("OK: keystore wired into build.gradle.kts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
