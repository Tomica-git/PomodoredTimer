# Pomodored Timer Public

赤い長針の速度を変えながら、黒い残り時間針と半透明の扇形でセッションの進行を確認できるポモドーロタイマーです。macOS公開版とWindows 11 x64版候補を、共通の挙動仕様とテストベクトルで検証しています。

## 主な機能

- 集中・短い休憩・長い休憩と自動セッション移行
- 赤い長針は最大5倍速、黒い針は実時間で残り時間を表示
- メニューバー／通知領域から開始、一時停止、前面表示
- 通常表示と約320×300の縮小表示、常に手前への固定
- 日・週・月で切り替えられる集中・休憩記録
- 針音、終了音、ミュート
- 端末内だけに保存し、macOSとWindowsで保存領域を分離

## 構成

```text
PomodoredTimer/
├── Sources/PomodoredTimer/         macOS公開版
├── Windows/                        Windows 11 x64公開版候補
├── Shared/TestVectors/             OS共通の挙動契約とテストデータ
├── Tests/                          macOSと共通仕様の検証
└── scripts/                        ビルド・公開境界の自動検査
```

この公開リポジトリには、個人版のソース、登録URL、実利用履歴、UserDefaults、ローカルパス、生成済み個人成果物を含めません。

## macOS版のビルド

必要環境：macOS 14以降、Swift 6、Xcode Command Line Tools。

```sh
./scripts/build-app.sh
```

検査済みアプリは `dist/public/Pomodored Timer Public.app` に生成されます。ビルド時に、公開版以外の保存キー、ローカルパス、履歴ファイル、ネットワークURL、WebKit依存が成果物へ混入していないことを検査します。

## Windows版候補のビルド

必要環境：Windows 11 x64、.NET 10 SDK。

```powershell
./scripts/build-windows-public.ps1
```

検査済み成果物は `dist/windows-public` に生成されます。Windows実機での受入確認が終わるまでは正式配布版ではなく候補です。詳細は [WINDOWS_PUBLIC.md](WINDOWS_PUBLIC.md) を参照してください。

## 設計上の境界

- macOSのBundle ID：`jp.tomica.pomodoredtimer.public`
- macOSの保存先：公開版専用UserDefaultsキー
- Windowsの保存先：`%LOCALAPPDATA%\PomodoredTimer\Public`
- OS間で共有するもの：タイマー挙動の契約と匿名テストベクトル
- 共有しないもの：保存ファイル、実履歴、OS固有UI、個人版機能

CIはmacOS公開版のビルド・テスト・成果物検査と、Windows版候補のビルド・テスト・成果物検査を別々の環境で実行します。

## 操作

- `Space`：開始／一時停止／再開
- `Command + R`：現在のセッションを終了し、集中・SET 1・停止状態へ戻す
- 緑ボタン：通常表示と縮小表示を切り替える
- メニューバー／通知領域：タイマー操作、設定、前面表示
- 「常に手前」：ほかのウインドウより前に固定する

設定と活動記録は利用者の端末内だけに保存されます。一時停止中の時間は活動記録へ加算しません。

## ライセンス

現時点ではライセンスを付与していません。ソースコードの閲覧はできますが、複製・改変・再配布の許諾は別途必要です。
