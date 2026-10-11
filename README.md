# overlay-builder

`enable-wifi-7` モジュールに同梱する Wi-Fi オーバーレイ APK の生成用スクリプト。モジュール本体（`master`）には含めず、このブランチで保管する。

## 生成物

| ファイル | package | targetPackage |
| --- | --- | --- |
| `treble-overlay-wifi7.apk` | `me.phh.treble.overlay.misc.wifi7` | `com.android.wifi.resources` |
| `treble-overlay-wifi7-google.apk` | `me.phh.treble.overlay.misc.wifi7.google` | `com.google.android.wifi.resources` |

共通: static オーバーレイ、priority 8003、uses-sdk なし。上書きする値は `res/values/config.xml`。

## 使い方

```sh
sudo apt install aapt apksigner zipalign android-sdk-platform-23 python3 default-jdk-headless
./build.sh                      # out/ に出力
```

自前の鍵で署名する場合:

```sh
KEYSTORE=/path/to/key.jks KS_PASS=xxxx KS_ALIAS=xxxx ./build.sh
```

`KEYSTORE` を指定しない場合は `out/debug.jks` を生成して署名する（`out/` はコミットしない）。

生成した APK をモジュールの `system/product/overlay/` に配置する。

## 構成

- `build.sh`: ビルド手順。aapt で `resources.arsc` を作り、マニフェストを差し替えて zipalign・署名する
- `gen_manifest.py`: バイナリ `AndroidManifest.xml` を生成する。aapt の API 23 用 android.jar では `android:isStatic` を解決できないため、直接書き出している
- `res/values/config.xml`: オーバーレイする値
