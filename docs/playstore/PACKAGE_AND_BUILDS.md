# CBW Learn — Package & Build Info

| Field | Value |
|-------|--------|
| **App name** | Capital BullWave Learn |
| **Android package** | `com.bullwave.bullwave_learn` |
| **Old package (other app)** | `com.bullwave.bullwave_invest` |
| **Version** | 1.2.1 (build 8) |
| **Play Store file** | `app-release.aab` |
| **Test file** | `app-release.apk` |

## Build outputs

```
investingapp/bullwavecapital/build/app/outputs/bundle/release/app-release.aab
investingapp/bullwavecapital/build/app/outputs/flutter-apk/app-release.apk
```

## Rebuild commands

```bash
cd investingapp/bullwavecapital
./scripts/build_playstore.sh   # AAB for Play Store
./scripts/build_apk.sh         # APK for phone testing
```

## Play Console

Create a **new app** — package `com.bullwave.bullwave_learn` cannot be merged with `com.bullwave.bullwave_invest`.

Full steps: [PLAY_STORE_UPLOAD_GUIDE.md](./PLAY_STORE_UPLOAD_GUIDE.md)
