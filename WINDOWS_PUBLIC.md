# Windows公開版候補

## 位置づけ

Windows版はmacOS版と同じリポジトリで管理し、恒久的なOS別ブランチには分けません。タイマー挙動だけを `Shared/TestVectors/public-core-v1` で共有し、UI実装と保存形式はOSごとに独立させます。

現段階は **Windows 11 x64向け公開版候補** です。CIでコンパイル、決定的テスト、配布物検査まで行いますが、実機でのGUI・通知領域・音・前面表示の確認が終わるまでは正式配布版として扱いません。

## 公開版の範囲

- 集中、短い休憩、長い休憩と自動セッション移行
- 赤い長針は0.5〜5倍、黒い針は実時間で残り時間を表示
- 通常表示と縮小表示、常に手前、通知領域からの復帰と操作
- 針音、終了音、ミュート
- 日・週・月の集中・休憩記録
- 個人版のメディア再生機能は含めない

## 保存分離

Windows公開版が読み書きする状態は次だけです。

```text
%LOCALAPPDATA%\PomodoredTimer\Public\state.v1.json
```

macOS版・個人版の設定や履歴は読み込みません。保存時は一時ファイルをディスクへ反映してから置換し、直前の状態を `state.v1.bak` に残します。読み取れない状態ファイルは上書きせず、同じディレクトリの `state.corrupt.<時刻>.json` へ隔離します。

## ビルド

Windows 11 x64と.NET 10 SDKでPowerShellから実行します。

```powershell
./scripts/build-windows-public.ps1
```

検査に合格した成果物だけが `dist/windows-public` に移動されます。配布対象は次の3ファイルだけです。

```text
PomodoredTimer.Windows.Public.exe
SHA256.txt
BUILD-MANIFEST.json
```

`BUILD-MANIFEST.json`には製品区分、Candidate状態、source commit、.NET SDK、runtime、EXEのSHA-256を記録します。ビルド環境のユーザーパスや保存データは含めません。

## 実機リリースゲート

- 初回起動、開始、一時停止、再開、リセット
- 集中終了後と休憩終了後の自動移行
- 通知領域アイコンから表示・操作・終了
- 通常／縮小表示、最前面表示、閉じた画面の復帰
- 針音、終了音、ミュート
- 日・週・月の記録表示と再起動後の復元
- 壊れた状態ファイルの隔離と安全な初期起動
- Windows Defenderでの確認と署名方針の決定
