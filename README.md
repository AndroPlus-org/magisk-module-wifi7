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

## ドライバ設定の書き換え

オーバーレイとは別に、ドライバの設定ファイルも起動時にバインドマウントで差し替える（メタモジュール不要）。

| SoC | ファイル | 変更内容 |
| --- | --- | --- |
| Qualcomm | `/vendor/firmware/wlan/qca_cld/<チップ名>/WCNSS_qcom_cfg.ini` など | `BandCapability`・`oem_6g_support_disable=1`・`scan_mode_6ghz=0` を無効化、`enable_11be=1` |
| MediaTek | `/odm/etc/wifi/wifi.cfg` など | `DisallowBand6G 1` → `0`（中国版 ColorOS などで 6GHz が無効化されている場合） |

Qualcomm のドライバは起動時にしか `WCNSS_qcom_cfg.ini` を読まないため、バインドマウントがドライバより後になると反映されない。そのため次の場所にも書き換えた設定を書き出す（再起動後も残り、次回起動から反映される）。

- ファームウェアの検索先に `/data/vendor/firmware/update/` がある端末（OPPO など）: `/data/vendor/firmware/update/wlan/WCNSS_qcom_cfg.ini`
- HONOR: COTA 用の `/data/misc/wifi/wifi_cfg/WCNSS_qcom_cfg.ini`

MediaTek の `wifi.cfg` は、KernelSU では `initrc/wifi7.rc` で起動初期（`on init`）にもマウントし、ドライバの初期化より前に差し替える。差し替え用のファイルは前回起動時に作るため、インストール後 2 回目の起動から効く。

MediaTek では起動完了後に 6GHz のチャンネルがドライバに登録されていなければ、Wi-Fi を 1 回オフ→オンして設定を読み直させる。

## 注意: 一時 root（tmp root）環境では 6GHz を有効化できない

再起動のたびに KernelSU を入れ直し、ソフトリブートでモジュールを読み込ませる一時 root 環境では、ドライバ設定の書き換えが効かない。Wi-Fi ドライバは root のない通常起動時に元の設定で初期化され、ソフトリブートではカーネル側のドライバが再初期化されないため。

- 確認した端末: OPPO K15 Pro+（Dimensity 9500s / MT6991、ColorOS 16 中国版、KernelSU 3.2.5 の tmp root）
- 結果: Wi-Fi 7（802.11be）は 5GHz で接続できるが、6GHz はドライバが拒否する（`Band[6G] is not allowed`）
- 試して効かなかった方法: `wifi.cfg` の差し替え、Wi-Fi のオフ→オン、`/proc/net/wlan/cfg` への書き込み、ドライバモジュールの再読み込み
- オーバーレイやスクリプトによる変更（国コードなど）は通常どおり適用される
- 例外として Qualcomm で、上記の `/data` 上の設定ファイルをドライバが読む端末では、書き出した設定が次回の起動から反映される（HONOR WIN Pad の KernelSU late-load で、6GHz のチャンネルがドライバに登録されることを確認）。ただし 6GHz で通信できるかは端末のハードウェアにもよる

## KernelSU を使う場合

- 公式 KernelSU v3.0 以降は本体がモジュールの `system` ファイルをマウントしない。[meta-overlayfs](https://github.com/RipperHybrid/Meta-Overlayfsx) などのメタモジュールを先にインストールすること。メタモジュールがないとオーバーレイが配置されず、国コード変更などのスクリプト処理しか効かない。
- KernelSU を起動後に読み込む方式（`ksud late-load`。ブートローダーをアンロックできない端末など）では `post-fs-data.sh` の代わりに `late-load.sh` が実行される。Qualcomm のドライバ設定はバインドマウントでは反映されず、`/data` 上に書き出した設定が次回起動から反映される（上記参照）。
- KernelSU Next / SukiSU Ultra など、マウント機能を内蔵した派生版ではメタモジュールは不要。

## 動作しないときの確認方法

Magisk / KernelSU マネージャーでこのモジュールの「アクション」ボタンを押すと診断情報を表示し、`/sdcard/Download/wifi7_diag.txt` に保存する。不具合報告時はこのファイルを添付すること。

- 診断結果の「Driver config files」欄でドライバ設定ファイルと設定値を確認できる。

手動で確認する場合:

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
