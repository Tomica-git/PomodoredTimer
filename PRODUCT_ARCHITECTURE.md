# 公開リポジトリの製品構成

長期正本は `main` です。macOSとWindowsを恒久ブランチで分けず、OS固有実装をディレクトリで分離し、共通仕様を版付きテストベクトルとして共有します。

| ID | OS | 状態 |
|---|---|---|
| `macos-public` | macOS 14以降 | public |
| `windows-public` | Windows 11 x64 | candidate |

製品識別子、保存namespace、builder、verifierは `config/product-matrix.v1.json` を正本とします。CIはマトリクスと実装の一致を確認してから各OSをビルドします。

個人版・有料版はこのリポジトリへ追加しません。公開対象へ昇格する機能だけを、秘密情報と過去履歴を含まない新しい変更として取り込みます。
