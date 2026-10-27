# ILA有無と修正内容の比較

基点は `fix/LUdetect` の `176e05b`。LU回復時のDAC再要求デッドロック修正 `dffdaf1` を全版で維持する。

| ブランチ | ILA | 変更内容 | この環境の作業場所 |
|---|---|---|---|
| `experiment/ila-common` | あり | 共通のビルド手順・観測回路切替のみ | `.ab/common` |
| `experiment/no-ila` | なし | ILAだけ無効化した比較基準 | `.ab/noila` |
| `fix/ila-reset` | なし | クロックごとのリセット解除同期化 | `.ab/reset` |
| `fix/ila-dac-memory` | なし | RBCPとDACの設定読出し競合を解消 | `.ab/memory` |
| `fix/ila-io-timing` | なし | シリアル出力遅延の制約とクロック入力モード指定 | `.ab/timing` |
| `fix/ila-independent` | なし | 上記3修正の統合版 | `.ab/combined` |

個別修正はすべて同じ `experiment/no-ila` から分岐している。元の作業ディレクトリと `fix/LUdetect` の未コミット差分は保管したまま、Git worktreeで別々に作業している。`.ab` はローカルの `.git/info/exclude` で除外している。

## 実装

リセットは `reset_release.vhd` によって、アサートを非同期、解除を対象クロック4回待ちにした。100 MHzのSystemRst、200 MHzのPLL起動カウンター、200 MHzのRBCPユーザーロジックに適用。ASICのアナログ電源待機時間は変更していない。

メモリ修正は、元のRBCP用BRAMに書かれる同じアドレス・データ・書込み許可を使い、ASIC 128 byte、Vth 2 byte、ADC bias 2 byteを保持する専用の読出し領域を追加した。3つのDAC制御回路が独立して読み出せるため、RBCP pollingもDAC同士も読出しポートを奪わない。制御リセットで保存値を消さない。転送中の同じ設定アドレスへの上書きをフレーム単位で原子的にする機能は含まないため、設定値の変更は転送完了後に行う。

タイミング修正は、ゲートされたSCLKを仮想的な連続10 MHzクロックとして扱う旧制約を置き換えた。実際の100 MHz出力FFから全シリアル信号への遅延を0–10 nsに制約し、RTLで確保されたエッジ間隔と合わせて評価する。100/200 MHz間にfalse pathやmulticycleは追加しない。

AD5640側はRTL試験でデータsetup 40 ns以上、SYNC setup 30 ns以上、データhold 60 ns以上、SCLKのhigh/low各50 ns以上を確認する。FPGA側遅延差10 ns、送出FFのクロックスキュー2 ns、基板スキュー2 nsを予算とすると、setupはデータ26 ns、SYNC 16 ns以上になる。これはAD5640の5 ns / 13 nsに対する設計上の予算であり、基板上での測定結果ではない。

**FE2009balのsetup/hold仕様値は未確認。** `CHIP_CK/RB/WR/SD`にもFPGA側0–10 nsの遅延制約を追加したが、ASIC端子の仕様を保証したとは扱わない。ADC_A/B/C/Dのinput delay不足も今回の修正対象外。

## ビルド

Vivado 2024.2で、各worktreeをカレントディレクトリとして実行する。

```text
vivado -mode batch -source scripts/build_clean.tcl -tclargs C:/path/to/new-output internal
python scripts/build_manifest.py C:/path/to/new-output
```

`build_manifest.py` は統合版にある。他の比較版には、統合版のスクリプトに第2引数でソースリポジトリを指定して使える。

ビルドは毎回新規プロジェクトを作り、synthesis/implementationともincremental checkpointを使用しない。既存出力ディレクトリがある場合は上書きせず終了する。比較用バイナリはこのスクリプトから作成すること（既存XPRのGUIビルドは同じclean build条件を保証しない）。合成・配置配線とsetup/hold確認を通過してからbit/binを作る。Gitに保存されたIPコンテナからIPを生成するため、初回は時間がかかる。

出力は `main.bit`、`main.bin`、`routed.dcp`、各種レポート。manifestにはソースのコミット・入力ファイルhash・bit/binのSHA-256を記録する。ビルド後にソースを変更してmanifestだけ更新しないこと。実機検証済みフラグは初期状態でfalse。

`fix/ila-io-timing` と統合版では、末尾の `internal` / `external` が制約上のPLL入力選択を指定する。**実機のDIP bit 6と一致させる。** `external` は50 MHzを前提とする。GUIのXPRには `clock_mode_internal.xdc` を登録している。外部モードはビルドスクリプトで選択する。XDC自体には条件分岐を置かず、選択したモードの制約ファイルだけを読み込む。論理DIP bit 6 = 0は `DIP_SW_IN[6]` ピンhigh（内部）、1はpin low（外部）。FPGAの実際の入力切替ロジック自体は変更していない。比較基準・リセット単独・メモリ単独版は従来のOSC_IN由来の制約を保持する。

## 検証

```text
doc\ila_investigation\run_reset_sim.cmd
doc\ila_investigation\run_sim.cmd
doc\ila_investigation\run_timing_sim.cmd
```

統合版には3種類すべて、個別修正版には該当する試験がある。基準版のrun_sim.cmdは旧不具合を再現できることを確認する試験なので、そのPASSは正常動作を意味しない。メモリ修正版と統合版では同じ重複条件でも正しい値を送ることを要求する。

実機比較では、まずILAありとILAなし基準を同じ基板・同じ設定で交互に試す。その後、個別修正版を1つずつ比較し、最後に統合版を試す。電源投入順序、LU ON/AP ON/configの順序、pollingの有無、使用クロック、bit/binのSHA-256を記録する。同じ版で複数回電源を入れ直す。一度成功しただけでは原因特定や再発防止の確認とはしない。

推奨記録列:

```csv
date,board,branch,commit,bin_sha256,clock_mode,boot_source,power_cycle,config_order,polling,config_ok,lu_recovery_ok,boot_seconds,notes
```

設定成功はヒットの有無だけでなく、可能ならVth電圧とDAC端子波形でも確認する。実機への書込みは今回の作業では実施していない。
