# Enable Wi-Fi 6GHz & Wi-Fi 7

Wi-Fi 6GHz / Wi-Fi 7 (802.11be) を有効化する Magisk / KernelSU モジュール。

## 同梱オーバーレイ

Wi-Fi のリソースパッケージ名は端末によって異なるため、2 種類のオーバーレイを同梱している。端末に存在する方だけが適用される。

| ファイル | 対象パッケージ |
| --- | --- |
| `treble-overlay-wifi7.apk` | `com.android.wifi.resources`（AOSP 版 Wi-Fi モジュール） |
| `treble-overlay-wifi7-google.apk` | `com.google.android.wifi.resources`（Google 署名版 Wi-Fi モジュール。Pixel など） |

上書きする値（共通）:

- `config_wifi11beSupportOverride` = true
- `config_wifi6ghzSupport` = true
- `config_wifiSoftapIeee80211beSupported` = true
- `config_wifiBand6GhzBonus` = 7

## KernelSU を使う場合

- 公式 KernelSU v3.0 以降は本体がモジュールの `system` ファイルをマウントしない。[meta-overlayfs](https://modules.kernelsu.org/module/meta-overlayfs) などのメタモジュールを先にインストールすること。メタモジュールがないとオーバーレイが配置されず、国コード変更などのスクリプト処理しか効かない。
- KernelSU Next / SukiSU Ultra など、マウント機能を内蔵した派生版ではメタモジュールは不要。

## 動作しないときの確認方法

```sh
# Wi-Fi リソースのパッケージ名
pm list packages | grep wifi.resources

# オーバーレイが配置されているか
ls -l /product/overlay/treble-overlay-wifi7*.apk

# オーバーレイが有効か（[x] なら有効）
cmd overlay list | grep -A2 wifi.resources

# 値が反映されているか（パッケージ名は上で確認したものに置き換える）
cmd overlay lookup com.google.android.wifi.resources com.google.android.wifi.resources:bool/config_wifi11beSupportOverride
```

オーバーレイが有効でもハードウェアやドライバが 6GHz / Wi-Fi 7 に対応していない場合は使えない（`iw phy` などで確認）。
