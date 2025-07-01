# GitHub Copilot カスタムインストラクション

## プロジェクト概要

このプロジェクトは **A-B-C-D Modpack Updater** という Minecraft modpack 管理ツールです。
Java + Maven で開発され、Launch4j で Windows EXE を生成し、PowerShell スクリプトでビルド・署名を自動化しています。

## 技術スタック

- **言語**: Java 11+、PowerShell
- **ビルドツール**: Maven 3.6+
- **GUI**: Java Swing
- **EXE作成**: Launch4j
- **署名**: OpenSSL + Windows SignTool
- **OS**: Windows (主要ターゲット)

## コーディング規約

### 一般的なルール

- **言語**: コメントやドキュメントは日本語で記述
- **書式**: 半角英数字と全角文字の間にはスペース。ただし、「。」や「、」の後はスペースを入れない。

### Java コード

- **Java バージョン**: Java 11 以上の機能を使用可能
- **パッケージ構造**: `com.abcd.modpack` 配下で整理
- **命名規約**: キャメルケース、クラス名は PascalCase
- **例外処理**: 適切な try-catch とユーザーフレンドリーなエラーメッセージ
- **ログ出力**: GUI への出力を重視（System.out.println 使用）
- **文字エンコーディング**: Windows 環境での文字化け対策を考慮

```java
// 良い例：GUI出力とエラーハンドリング
try {
    downloadFile(url, destPath);
    appendToLog("ファイルダウンロード完了: " + fileName);
} catch (IOException e) {
    appendToLog("エラー: ファイルダウンロードに失敗しました - " + e.getMessage());
    showErrorDialog("ダウンロードエラー", "ファイルのダウンロードに失敗しました。\n詳細: " + e.getMessage());
}
```

### PowerShell スクリプト

- **エラーハンドリング**: `-ErrorAction Stop` と try-catch を活用
- **パラメータ**: `[CmdletBinding()]` と適切な型指定
- **出力**: `Write-Host` で色分けされた情報表示
- **環境変数**: `.env` ファイルからの読み込みをサポート
- **証明書操作**: セキュリティを考慮した実装

```powershell
# 良い例：エラーハンドリングと情報表示
[CmdletBinding()]
param(
    [string]$OutputPath = "target\abcd-modpack-updater.exe"
)

try {
    Write-Host "🔨 EXE作成を開始します..." -ForegroundColor Cyan
    
    # 処理実行
    $result = Start-Process -FilePath $launch4jPath -ArgumentList $configPath -Wait -PassThru
    
    if ($result.ExitCode -eq 0) {
        Write-Host "✅ EXE作成が完了しました: $OutputPath" -ForegroundColor Green
    } else {
        throw "Launch4j の実行に失敗しました（終了コード: $($result.ExitCode)）"
    }
} catch {
    Write-Host "❌ エラー: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
```

## プロジェクト固有のルール

### 1. ファイルパス処理

- Windows パスセパレータ（`\`）を使用
- 相対パスは明確に、絶対パスが必要な場合は適切に解決
- PowerShell では `Join-Path` を積極的に使用

### 2. 証明書・セキュリティ

- パスワードは `.env` ファイルから読み込み（決してハードコーディングしない）
- 証明書ファイルは `certificates/` ディレクトリに配置
- テスト用証明書であることを明確にコメント

### 3. Maven とビルド

- `pom.xml` の依存関係は最小限に保つ
- リソースファイル（アイコンなど）は `src/main/resources/` に配置
- ビルド成果物は `target/` ディレクトリ

### 4. GUI 開発（Swing）

- ユーザーフレンドリーなメッセージ
- 処理中はプログレスバーやログ出力で状況を表示
- 日本語UI、適切なフォント設定
- EDT（Event Dispatch Thread）を適切に使用

### 5. Launch4j 設定

- JRE バージョン要件は Java 11 以上
- Windows 向けアイコンとメタデータを設定
- JAR内包（wrapping）モードを使用

## コード生成時の注意事項

### 推奨パターン

1. **エラー処理**: 例外をキャッチしてユーザーに分かりやすいメッセージで表示
2. **ログ出力**: 処理の進行状況を GUI に表示
3. **ファイル操作**: `java.nio.file` を使用してモダンなファイル操作
4. **外部プロセス**: `ProcessBuilder` を使用して外部コマンド実行
5. **設定管理**: プロパティファイルや環境変数で設定を外部化

### 避けるべきパターン

1. **ハードコーディング**: パス、URL、パスワードの直接記述
2. **プラットフォーム依存**: Windows 以外では動作しない前提で開発
3. **ブロッキング処理**: GUI をフリーズさせる長時間処理
4. **不適切な例外処理**: 例外を無視したり、不十分なエラーメッセージ

## 特殊な技術要件

### コードサイニング

このプロジェクトでは、Launch4j EXE の JAR 構造を保護する独自の署名手法を使用：

```powershell
# Comment Length 手法による署名
# ZIP EOCD の Comment Length フィールドを操作して署名データを適切に処理
$commentLengthOffset = $eocdPosition + 20
[System.IO.File]::WriteAllBytes($tempFile, $newCommentLength)
```

### Minecraft 環境検出

- Microsoft Store 版と通常版の Java 検出
- Minecraft ランチャープロファイルの JSON 操作
- プロセス監視（Minecraft 実行中の検出）

## 依存関係と外部ツール

- **必須**: Maven、Launch4j、OpenSSL
- **推奨**: Git、VS Code with Java Extension Pack
- **証明書**: テスト用自己署名証明書（開発時のみ）

## 文書化要件

- **README.md**: ビルド手順、使用方法、トラブルシューティング
- **コメント**: 複雑なロジック（特に署名処理）には詳細な説明
- **PowerShell**: `Get-Help` 対応のコメントベースヘルプ

---

これらのルールに従って、保守性が高く、Windows 環境で確実に動作するコードを生成してください。
