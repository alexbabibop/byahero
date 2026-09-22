# ByaHero — STEP BY STEP SETUP (Tagalog, Windows 10)

> Goal mo: makapag-`flutter run`, makapag-push sa GitHub (`alexbabibop`), at makakuha ng **APK** kahit walang Flutter sa PC mo ngayon (via GitHub Actions cloud build).

Repo root = folder na `byahero/` (nandito ang `pubspec.yaml`). Lahat ng command sa baba ay **loob ng `byahero/`**.

---

## 0. Ano ang kailangan i-install (lahat libre)

| # | Program | Bakit | Link / paano |
|---|---------|-------|--------------|
| 1 | **Git for Windows** | pang-push sa GitHub | https://git-scm.com/download/win — meron ka na (v2.55 ✔) |
| 2 | **Flutter SDK 3.22.x** | pang-build ng app | https://docs.flutter.dev/get-started/install/windows — i-download ang zip, i-extract sa `C:\src\flutter`, tapos idagdag `C:\src\flutter\bin` sa PATH |
| 3 | **Android Studio** | Android SDK + emulator + Java 17 | https://developer.android.com/studio — during install, i-check ang *Android SDK, Platform-Tools, Emulator* |
| 4 | **Java 17** | requirement ng Flutter/Gradle (meron ka pang Java 8 — kailangan mag-upgrade) | kasama na sa Android Studio (Temurin 17) o https://adoptium.net |
| 5 | **Node.js LTS** | kailangan ng Firebase CLI | https://nodejs.org — LTS version |
| 6 | **Firebase CLI** | deploy ng firestore.rules/storage.rules | Pagkatapos mag-install ng Node: `npm install -g firebase-tools` |
| 7 | **Google Maps API key** | para gumana ang mapa | https://console.cloud.google.com → APIs → i-enable *Maps SDK for Android* → Credentials → Create API key |
| 8 | **VS Code (optional)** + Flutter/Dart extensions | mas magaan kaysa Android Studio pang-code | https://code.visualstudio.com |

I-verify pagkatapos mag-install (bagong terminal):
```powershell
git --version
flutter doctor
flutter --version
java -version   # dapat 17
firebase --version
```

Kung `flutter : not recognized` pa rin → hindi pa nasa PATH ang `C:\src\flutter\bin`. I-restart ang terminal o PC.

---

## 1. Flutter + Android setup (isang beses lang)

1. I-extract ang Flutter sa `C:\src\flutter` (huwag sa folder na may space).
2. Idagdag sa PATH:
   - Start → *Edit the system environment variables* → Environment Variables → Path → Edit → New → `C:\src\flutter\bin`
3. Buksan ang Android Studio → SDK Manager → i-install:
   - Android SDK Platform 34
   - Android SDK Build-Tools
   - Android Emulator + isang device (hal. Pixel 4, API 33)
4. Sa terminal:
```powershell
flutter doctor --android-licenses   # pindutin y lahat
flutter doctor                       # dapat walang pulang X sa Android toolchain
flutter config --android-sdk "C:\Users\COS - Brian\AppData\Local\Android\Sdk"
```

> Tandaan: ang PC mo ngayon ay Java 8 pa. Hindi magbi-build ang Flutter/Gradle sa Java 8. Siguraduhing Java 17 ang gamit (`flutter doctor -v` makikita ang Java version).

---

## 2. Firebase project setup

1. Pumunta sa https://console.firebase.google.com → Add project → pangalan `byahero`.
2. Sa loob ng project:
   - **Authentication** → Sign-in method → i-enable *Email/Password* + *Google*.
   - **Firestore Database** → Create database → Start in production mode → region `asia-southeast1` (Singapore, pinakamalapit sa PH).
   - **Storage** → Get started.
3. I-register ang Android app:
   - Project Overview → Add app → Android → package name: `com.example.byahero` (palitan mo mamaya kapag may final package name ka na).
   - I-download ang `google-services.json` → ilagay sa `byahero\android\app\google-services.json` (huwag i-commit sa public repo — nasa `.gitignore` na yan).
4. Sa PC (pagkatapos mag-install ng Flutter + Node):
```powershell
dart pub global activate flutterfire_cli
flutterfire configure --project=byahero
# gagawa ito ng lib\firebase_options.dart — papalitan nito ang firebase_options_stub.dart
```
5. I-deploy ang rules:
```powershell
firebase login
firebase init firestore,storage   # piliin ang existing project, HUWAG mag-overwrite ng firestore.rules/storage.rules
firebase deploy --only firestore:rules,storage
```

---

## 3. Google Maps API key

1. https://console.cloud.google.com → piliin ang Firebase project → APIs & Services → i-enable ang **Maps SDK for Android**.
2. Credentials → Create Credentials → API key → i-restrict sa Android apps + package name + SHA-1 (makukuha via `cd android; ./gradlew signingReport` kapag may Android SDK ka na).
3. Ilagay ang key sa isa sa dalawa:
   - **Local run:** `flutter run --dart-define=MAPS_API_KEY=PASTE_KEY_HERE`
   - **CI build:** ilagay bilang GitHub Secret na `MAPS_API_KEY` (tingnan sa Sec 5).

---

## 4. Patakbuhin locally

```powershell
cd "C:\Users\COS - Brian\Documents\Default Project\byahero"
flutter pub get
flutter analyze
flutter run --dart-define=MAPS_API_KEY=PASTE_KEY_HERE
```

Test checklist:
- [ ] Start Journey → palitan ng Vehicle mode → makita ang color dots.
- [ ] Pause/Resume/End gumagana.
- [ ] Proof Camera nagbubukas (live only, walang gallery button).
- [ ] PDF Preview nagge-generate.
- [ ] Community Feed (gagana lang kapag connected ang Firebase).

Local APK:
```powershell
flutter build apk --release --dart-define=MAPS_API_KEY=PASTE_KEY_HERE
# output: build\app\outputs\flutter-apk\app-release.apk
```

---

## 5. GitHub setup (portfolio + cloud APK build)

Gusto mo: username `alexbabibop`, email `jamiestun@gmail.com`.

### 5a. Git identity (isang beses lang sa PC)
```powershell
git config --global user.name "alexbabibop"
git config --global user.email "jamiestun@gmail.com"
```

### 5b. Gawin ang repo sa github.com
1. Login bilang `alexbabibop` → New repository → name `byahero` → Public (pang-portfolio) → **HUWAG** lagyan ng README (meron na tayo) → Create.
2. Sa PC:
```powershell
cd "C:\Users\COS - Brian\Documents\Default Project\byahero"
git init
git add .
git commit -m "feat: ByaHero MVP scaffold (tracker, anti-daya, PDF, community)"
git branch -M main
git remote add origin https://github.com/alexbabibop/byahero.git
git push -u origin main
```
Kung hihingi ng login: gumamit ng **Personal Access Token** (GitHub → Settings → Developer settings → Tokens classic → scope `repo`) bilang password. O mas madali: `gh auth login`.

### 5c. Kunin ang APK nang hindi nag-iinstall ng Flutter (cloud build)
1. Pagkatapos mag-push, pumunta sa repo → **Actions** tab → i-enable ang workflows.
2. Bawat push sa `main` ay tumatakbo ang `Build APK` workflow (`.github/workflows/build-apk.yml`).
3. Kapag green check na → buksan ang run → **Artifacts** → i-download ang `byahero-apk` → nasa loob ang `app-release.apk`.
4. Ilipat sa phone → install → test.

### 5d. Secrets (para gumana ang Maps + Firebase sa cloud build)
Repo → Settings → Secrets and variables → Actions → New repository secret:
- `MAPS_API_KEY` = ang Google Maps key mo.
- `GOOGLE_SERVICES_JSON` (optional) = ang buong `google-services.json`, naka-base64:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\google-services.json"))
```
I-paste ang output bilang secret value. Ang workflow ang magbabalik nito sa `android/app/google-services.json` tuwing build.

---

## 6. Play Store checklist (kapag ready nang i-publish)

- [ ] I-host ang `PRIVACY_POLICY.md` sa public URL (GitHub Pages o Firebase Hosting) at ilagay sa Play Console + in-app disclosure bago mag-start ng tracking.
- [ ] Palitan ang package name + app icon + splash.
- [ ] `flutter build appbundle --release` (AAB ang kailangan ng Play, hindi APK).
- [ ] Fill-up ng Data Safety form: location, camera, device IDs.
- [ ] Internal testing track muna bago production.

Short description (gamitin sa listing):
> Ikaw ang bida sa byahe mo! Track commute times, queue delays, and generate tamper-proof reports.

Tags: Commute Tracker, P2P Bus Lines, Traffic News, Proof Generator, Pinoy Transit.

---

## 7. Troubleshooting

| Error | Fix |
|-------|-----|
| `flutter not recognized` | Wala sa PATH. Idagdag `C:\src\flutter\bin`, bagong terminal. |
| `Java version 1.8` | Mag-install ng Java 17, ituro ang `JAVA_HOME` dito. |
| `google-services.json missing` | Normal sa MVP — gagana ang UI sa offline mode; ilagay ang file para sa Firebase features. |
| `MAPS_API_KEY invalid` | I-check ang restriction + billing sa Google Cloud. |
| `Actions build failed` | Buksan ang failed step log; kadalasan ay Flutter version o missing secret. |
| Gallery dapat walang access | Sinasadya yan (anti-daya). Huwag magdagdag ng `image_picker` gallery. |

---

## 8. Susunod na gagawin (Kapag tapos ang setup)

1. `flutterfire configure` para sa tunay na `firebase_options.dart`.
2. I-wire ang `FirebaseAuth` UID sa `JourneyTracker.startJourney` (palitan ang `'local-user'`).
3. I-test ang 100m geofence sa totoong terminal (BGC/EDSA).
4. Gawing sqflite ang `_queue` sa `FirestoreService` para sa tunay na offline caching.
5. Magdagdag ng app icon: `flutter_launcher_icons` package.

Good luck boss! Ikaw ang bida sa byahe mo. 🚀
