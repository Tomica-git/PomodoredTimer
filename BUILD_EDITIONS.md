# 公開版ビルド境界

このリポジトリはmacOS公開版とWindows公開版候補だけを扱います。個人版や将来の有料版は別の非公開リポジトリで管理し、公開リポジトリのブランチ・タグ・履歴へ含めません。

## 公開対象

| 製品 | 状態 | 保存領域 |
|---|---|---|
| macOS Public | 公開 | `pomodored.public.*` の専用キー |
| Windows Public | 実機確認前の候補 | `%LOCALAPPDATA%\PomodoredTimer\Public` |

## 禁止事項

- 個人版の機能、識別子、保存キー、登録URLを含めない
- UserDefaults、履歴JSON、バックアップ、ログ、ローカル絶対パスを含めない
- 公開版から非公開版の保存領域を探索・移行・同期しない
- macOSとWindowsの保存ファイルを共有しない

## 合格条件

- macOS公開版の決定的テストと成果物検査が通る
- Windows公開版候補のテスト、publish、成果物検査が通る
- 両OSが `Shared/TestVectors/public-core-v1` と一致する
- 公開履歴が独立しており、非公開リポジトリの過去commitを祖先に持たない
