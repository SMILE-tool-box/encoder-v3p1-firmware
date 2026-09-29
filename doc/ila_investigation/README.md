# ILA追加による動作変化の調査

調査日: 2026-09-29。対象: HEAD `176e05b`、`aa75390`、`3bad011`、`dffdaf1`、保存済みDCP/ILA。

## 結論

**「ILAが機能を直した」とは確認できない。制約に現れない問題という疑いは妥当で、実際に制約の欠落・仕様との不一致がある。さらに、RBCP通信でDAC設定値が破損する独立したRTL不具合を再現した。**

ただし、これらのどれが7月30日の「LU detectを先にONするとcathodeが真っ赤になる」現象を直接引き起こしたかは、まだ確定できない。失敗したバイナリに対応するピン波形・起動時波形は得られていない。ILAを除いた実機での検証は今回行っていない。

優先して切り分けるのは、(1) PLL LOCKEDからのリセット解除、(2) 外部DAC/ASICインターフェースのタイミング、(3) RBCPとDAC読出しのメモリ競合。100/200 MHz間を一括でfalse pathにする対処は適切ではない。

製品RTL、XDC、XPR、bit/binは変更していない。このディレクトリには調査用スクリプトと再現試験のみ追加した。

## 1. Notionの観測とGit差分

[実験ログ](https://app.notion.com/p/3a7ef0ebaaf280e59053e68a185691a1)の「実機検証3」では、次が記録されている。

- `20260803_run07`: ILA入りをSPI Flashから起動して正常。
- `run08`: 0730のbinへ差し戻すとcathodeが真っ赤になる。
- `run09`: ILA入りへ戻すと正常。
- pollingのON/OFFやJTAG/SPI Flashの違いを変えても、ILA入り側では再現しなかった。

これはバイナリ依存の証拠だが、ILAの必要性や因果関係の証明ではない。

Notionには「実は機能的な変更も入っていた（？）」とある。しかし `aa75390 → 3bad011` のLURecover差分は、出力レジスタ `ap_on` / `dac_ctrl` を内部信号 `reg_ap_on` / `reg_dac_ctrl` へ名前を変えて出力に接続したもの。**レジスタ段数・リセット値・更新条件は変わっていない。** `enable => LatchUp_Detect and DAQ_Enable` を `LURecoverEnable` に分けた箇所も同じ論理である。

`compare_ila_change.py` で、ILAとデバッグ専用ロジック・出力別名・空白を除去したLURecoverのソースが完全一致することを確認した。これはソース比較であり、合成後ネットリストの形式的等価性証明ではない。出力別名に伴うシミュレーション上のデルタサイクルは、実回路のクロック遅延の追加を意味しない。

ILAに信号を接続すると、その信号の負荷や最適化・配置配線が変わり得る。したがって、同じ機能でも未検証のタイミング問題が隠れる、という仮説は残る。

`dffdaf1` のDAC要求ワンショット化とASIC_DAC_setの要求受理条件の変更は、実際の機能修正である。これはNotionで別途観測された「2回目のLU回復で止まる」問題に対応する。ILAを外す際にも維持すべき変更である。

## 2. 保存済み設計のタイミング比較

Vivado 2024.2でDCPを開き、check_timing、report_cdc、report_clock_interaction、report_exceptions、クロック間と外部出力のreport_timingを実行した。

| 対象 | WNS (setup) | WHS (hold) | 200→100 MHz setup / hold |
|---|---:|---:|---:|
| ILA追加前の参照DCP、2026-07-30 17:27:18 JST | +0.137 ns | +0.055 ns | +1.851 / +0.079 ns |
| ILA入り、2026-08-04 16:17の保存済み実装 | +0.228 ns | +0.058 ns | +1.975 / +0.113 ns |

旧DCPは `3bad011:Vivado_project/Encoder_v3.1_Firmware.srcs/utils_1/imports/impl_1/main_routed.dcp` を取り出したもの。DCP内の時刻とLU用ILAインスタンスがないことを確認した。ただし **run08で使用したbinそのものとの一致は未確認**。このファイルはincremental implementationの参照設計なので、コミット名から「そのコミットをビルドした成果物」とは判断していない。

100 MHzと200 MHzは `main.vhd:800–819` の同一PLLE2から生成される関連クロックであり、通常のデータパスはSTA対象。Vth_Dataなどの経路も解析され、旧DCPの最小hold余裕は +0.079 ns。余裕が小さいことは事実だが、正のslackだけから違反・メタステーブルを断定することはできない。

新側の全体WNS/WHSは保存済み `main_timing_summary_routed.rpt`、クロック間の詳細は今回再解析した結果による。

## 3. 確認した制約・リセット上の問題

### 3.1 ASICの書込み出力が未制約

`FE2009bal_u_Gigabit_RO_V3.xdc:345–355`:

- `CHIP_CK` には100 MHzからの最大遅延10 nsのみ指定。
- `CHIP_RB`、`CHIP_WR`、`CHIP_SD` のoutput delayはコメントアウト。
- check_timingでもこの3ポートがno_output_delayとして列挙される。

ASIC端子におけるクロック対データ・リセット・書込み許可のsetup/holdは、この設定では保証されない。ILA追加による配線変更で動作が変わり得る箇所である。ただし、実際の違反は未測定。

`FE2009bal_DAC_SET.pdf` の波形図は確認したが、そこから保証されたsetup/holdの数値は得られなかった。図の見た目から数値を決めて制約を追加すべきではない。部品仕様・基板経路・実測の確認が必要。

### 3.2 Vth / ADC bias DACの制約が部品仕様と一致しない

回路図 `FE2009bal_u-Gigabit_RO_V3_1_回路図.pdf` p.4–5のDACはAD5640CRMZ-1。

現在のXDC `:363–375` はSCLK/ADC_SCLKについて `-divide_by 10` のgenerated clockを定義し、SDIN/SYNCのoutput delayを立上り基準の `-max 4.000`、`-min 1.000` としている。

一方、[AD5640データシート](https://www.analog.com/media/en/technical-documentation/data-sheets/AD5620_5640_5660.pdf) p.7、p.9では、データ取込みはSCLK立下り、data setup 5 ns、hold 4.5 ns、SYNC立下りからSCLK立下りまで13 ns以上である。

現在の制約は、実部品の取込みエッジとsetup/hold要件をそのまま表していない。SDINとSYNCも同一の数値では扱えない。データの最小output delayは、通常のsource-synchronousの式では基板のdata/clock skewと負のhold項を含む。`+1 ns` をそのまま「1 nsのhold保証」と読んではいけない。

修正時には、ゲート付きSCLKの最初と最後のエッジ、分周器の位相、出力FFの遅延も合わせてモデル化する必要がある。単に `-clock_fall` を足すだけで完了とはしない。**仕様との不一致は確認済みだが、DAC端子でのタイミング違反そのものは未確認。**

### 3.3 SystemRstの解除が同期されていない

`main.vhd:605` の `SystemRst <= not locked` が、DAC・LURecoverなどの非同期リセット端子に直結する。`CLKOUT2` に同期してリセットを解除する回路はない。

PLL LOCKEDの変化と100 MHzの有効エッジ、リセット配線の到達時刻に依存して、FFごとの解除が揃わない可能性がある。配置配線依存・電源再投入依存という症状とは整合するが、今回の直接原因とまでは確定していない。RTLシミュレーションでは、このアナログ的な現象は再現・排除できない。

[AMD UG949](https://docs.amd.com/r/2023.2-English/ug949-vivado-design-methodology/Synchronous-Reset-vs.-Asynchronous-Reset)も、非同期リセットを使う場合は解除をクロックに同期させることを要求している。対策候補はクロックごとの「非同期アサート・同期デアサート」と、PLL安定後の明示的な待機である。

RBCP側は `main.vhd:1506` で別の `SiTCP_Reset` を使用し、XDCではその経路をfalse pathにしている。ここも解除条件を確認する必要があるが、単にSiTCP提供の例外を削除したり、ベンダIP内部まで一括修正したりする対処はしない。

### 3.4 外部クロックとADC入力の制約不足

`TRG_IN[0]` の外部50 MHz用create_clockはXDC `:269` でコメントアウト。`main.vhd:829` ではDIP bit 6でこの外部クロックをPLL入力に選べる。check_timingは `Osc_MUX/I1` をno_clockとして報告する。

外部クロックを使用する運用なら、現状の内部OSC由来のタイミング合格だけで実運用モードを評価したことにはならない。選択モードを明示して、内部・外部を個別に解析するのがよい。DIPの実設定は未確認。

さらにADC_A/B/C/Dの40入力にinput delayがない。これは別の確実な制約漏れだが、Vth設定失敗の直接原因とする証拠はない。

CDCレポートにはSiTCP/GMII/デバッグコア由来の多数の警告がある。件数だけで今回の故障原因とは判断せず、通常の100/200 MHz間まで非同期として切り離すこともしない。

## 4. 再現したRTL不具合: RBCPアクセスがDAC読出しを破壊する

`RBCP_REG.vhd:259–296` のメモリ制御は次の優先順位になっている。

```text
rbcp_act = 1 → RBCPアドレスへ切替え、DAC_Data/Vth_Data/ADC_BIAS_Dataを全て0
それ以外   → ASIC DAC、Vth、ADC biasの順にデータ供給
```

一方、`DAC_set.vhd:151–155` は決まった時刻にDataを取り込む。データ有効信号やメモリアクセス待ち合わせがない。したがって、DACのデータ取込み期間中にRBCP通信が入るとゼロや別アドレスのデータを取り込める。LUカウンターの `0xF8` 読出しでも同じ分岐に入る。

実際のRBCP_REGとDACsetを変更せずXSimで実行した結果:

| 条件 | DACへの16 bitシリアル出力 |
|---|---|
| RAMに0x1234を書き、通常のVth設定を実行 | `0x1234` |
| 設定要求後、rbcp_actを400 ns追加保持して取込み窓に重ねる | `0x0000` |
| 通常設定中、上位byte読出しに0xF8の1 byte pollingを重ねる | `0x0034` |

3ケースとも試験のassertionを通過。これは意図した不具合の再現を確認する試験であり、製品が正常だという意味のPASSではない。

モデル化したのはRAMだけで、IPの設定（single-port、8 bit × 256、primitive output registerあり）に合わせて2サイクル読出しとしている。SiTCP通信スタック、実際の基板遅延、アナログDAC出力はシミュレーションしていない。通常通信のtail 20 nsは保存ILAの1 byte書込みでACKからrbcp_act解除まで4 sampleだったことに合わせた。400 ns保持のケースは意図的なストレス条件。

修正方向は、DAC用データの専用読出しポート・シャドーレジスタ、または明示的なデータ有効ハンドシェイクによる仲裁。polling停止だけでは任意のRBCP通信やLU回復との競合が残る。

ただし、NotionではpollingをOFFにしてもILA入りが正常だった。**このRTL不具合は存在するが、ILA依存を単独で説明するものではない。**

## 5. 保存されたILAから分かること

`Vivado_project/ila_export/LURecover/*.ila` はZIP内のwaveform.csvを直接読んだ。

- `iladata_2_normal_dacset2.ila`: sample 507でF0=02を書込み、512でACK/DAC_Set、513でDAC_Run、516でrbcp_act解除。DAC開始とRBCPアクセスが短時間重なることは実測されている。ただし、この波形でデータ破損が起きたとは確認していない。
- `iladata_3_normal_vthset.ila`: 名前にvthsetとあるが、記録窓内は80/81番地の読出し。Vth_Set/Vth_Runは上がっていない。Vthへのシリアル書込み波形としては使えない。
- 他のmain側保存波形でも、Vth_Runとrbcp_actが重なる場面は確認できなかった。

したがって、現在の保存ILAから「Vthのシリアル送信は正しかった」「競合が元の失敗原因だった」とは結論できない。また、FPGA内部で正常に見えてもDAC/ASIC端子でのsetup/holdは別途確認が必要。

## 6. ILAなしで安定化するための切り分け順

1. 現行の `dffdaf1` 修正を維持した同一RTLからILA有/無のビルドを用意する。削除するのは観測回路だけとし、incremental参照の影響を避けたclean buildで比較する。0730へ丸ごと戻す比較はLUデッドロック修正まで失うので避ける。
2. 実際のクロック入力モードを制約へ反映し、リセット解除を各クロックに同期する。この変更だけでILAなしの起動・設定順序依存が消えるか、同一個体で複数回の電源再投入を試す。
3. 外部DAC/ASICの正しいエッジ・setup/hold・基板skewを制約化する。Vth側はR6/R7/R9、ASIC側はR1–R4が回路図上の観測点。電源投入時、LU ON→AP ON→config、AP ON→config→LU ONを比較し、SCLK/SYNC/SDINとVth実電圧を確認する。
4. RBCPとのメモリ競合を修正し、今回の競合試験でも常に `0x1234` が送られることを確認する。LU連続発動、polling同時実行も試す。

ILA追加前後の制約付きSTAは合格していたため、根拠なく内部クロック間のmax_delayを厳しくするより、確認したリセット・外部I/O・機能競合を個別に潰す方が原因を追いやすい。

起動時間については、今回のILA追加差分に明示的な起動待機処理はない。電源投入→DONE、DONE→通信可能、Vivadoによる書込み・デバッグ接続のどの区間が延びるのかは未確認。ILAがあるから必ずFPGA起動が遅くなる、または遅れが不具合を隠している、とは現時点では断定しない。

## 再実行方法・出力

```text
python doc/ila_investigation/compare_ila_change.py
doc\ila_investigation\run_sim.cmd
vivado -mode batch -source doc/ila_investigation/audit_timing.tcl
```

`run_sim.cmd` はWindowsの `C:\Xilinx\Vivado\2024.2` を使用する。インストール先が異なる場合はVIVADO_BINを変更する。元プロジェクトは開かず、`.work/sim` で検証する。

`audit_timing.tcl` は既定で保存済みのimpl_1/main_routed.dcpを読み、`.work/timing` に出力する。`-tclargs <DCPのパス> <出力ラベル>` で別のDCPも解析できる。プロジェクトの変更・再合成・bitstream生成・実機への書込みは行わない。

今回の実行ログ・詳細結果:

- `.work/sim/xsim.log`: シリアル出力3ケースの検証結果。
- `.work/timing/`: ILA入りDCPの制約・CDC・クロック間・出力の再解析。
- `.work/timing_july30/`: ILA追加前の参照DCPの再解析。summary.rptに全体slack。
- 既存 `Vivado_project/Encoder_v3.1_Firmware.runs/impl_1/main_timing_summary_routed.rpt`: ILA入り実装の全体slack。

`.work` 内の生成物はGit管理対象外。
