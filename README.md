# A-B-C-D Modpack Updater

A-B-C-D Modpack 用のアップデーターアプリケーションです。
Minecraft の modpack を自動的にダウンロード・インストール・更新する Java アプリケーションです。

## 機能

- **自動バージョン確認**: 最新バージョンとの比較を行い、必要に応じてアップデートを促します
- **Fabric 自動インストール**: 指定された Minecraft バージョンに対応する Fabric Loader を自動でインストールします
- **Modpack 管理**: 必要な mod ファイルのダウンロード、不要なファイルの削除を自動で行います
- **ランチャープロファイル作成**: Minecraft ランチャーに A-B-C-D 専用のプロファイルを自動作成します
- **GUIインターフェース**: 処理状況を視覚的に確認できる Swing ベースの GUI を提供します

## 必要環境

- **Java**: Java 11 以上
- **OS**: Windows (主に Windows 環境での動作を想定)
- **Minecraft**: Minecraft Java Edition のランチャーがインストールされていること

## ビルド方法

### 前提条件
- Maven 3.6 以上
- Java Development Kit (JDK) 11 以上
- Launch4j (EXE作成時)
- OpenSSL (テスト用証明書作成時)

### 開発・テスト用ビルド（推奨）

統合スクリプトを使用して、証明書作成からEXE署名まで一括で実行できます：

```powershell
# 初回セットアップ（証明書作成 + ビルド + 署名）
.\dev-build.ps1

# 個別実行
.\dev-build.ps1 -CreateCertificate    # テスト用証明書作成
.\dev-build.ps1 -BuildOnly            # ビルドのみ
.\dev-build.ps1 -SignOnly             # 署名のみ
.\dev-build.ps1 -CleanAll             # 全てクリーンアップ
```

### コマンドライン

```powershell
# プロジェクトをクローン
git clone https://github.com/MusclePr/abcd-modpack.git
cd abcd-modpack

# 従来のビルド方法
.\build-exe.ps1
```

## コードサイニング（開発・テスト用）

このプロジェクトには、テスト・開発用の自己認証局（CA）によるコードサイニング機能が含まれています。

### 環境設定

証明書のパスワードは`.env`ファイルで管理します。プロジェクトルートに`.env`ファイルを作成してください：

```bash
# .env ファイル
PASSWORD="Cx!3.-a8K/Vw"
```

**注意**: `.env`ファイルは`.gitignore`に含まれており、Gitリポジトリにはコミットされません。

### 自己認証局とコードサイニング証明書の作成

```powershell
# テスト用証明書を作成（.envファイルからパスワードを自動読み込み）
.\create-test-certificate.ps1
```

このスクリプトは以下を作成します：
- CA（認証局）の秘密鍵と証明書
- コードサイニング用の秘密鍵と証明書
- PKCS#12形式の証明書ファイル (.pfx)

作成されるファイル：
```
certificates/
├── ca-certificate.pem                # CA証明書
├── ca-private-key.pem                # CA秘密鍵
├── code-signing-certificate.pem      # コードサイニング証明書
├── code-signing-private-key.pem      # コードサイニング秘密鍵
└── code-signing-certificate.pfx      # 署名用PFXファイル
```

### EXEファイルへの署名

```powershell
# PFXファイルを使用して署名（.envファイルからパスワードを自動読み込み）
.\sign-exe.ps1

# 明示的にPFXファイルとパスワードを指定
.\sign-exe.ps1 -PfxPath ".\certificates\code-signing-certificate.pfx" -Password "カスタムパスワード"

# 証明書ストアの証明書を使用して署名
.\sign-exe.ps1 -CertThumbprint "証明書の拇印"
```

### 証明書管理

```powershell
# 証明書の確認・管理
.\certificate-manager.ps1 -ListCertificates    # 証明書一覧
.\certificate-manager.ps1 -ShowDetails         # 詳細表示
.\certificate-manager.ps1 -VerifySignature     # 署名確認

# CA証明書をルート証明書ストアにインストール（管理者権限必要）
.\certificate-manager.ps1 -InstallCA

# CA証明書をルート証明書ストアから削除（管理者権限必要）
.\certificate-manager.ps1 -UninstallCA
```

### 注意事項

- **開発・テスト専用**: 作成される証明書は自己署名証明書であり、本番環境では使用しないでください
- **セキュリティ**: パスワードは`.env`ファイルで管理されます。このファイルは絶対にリポジトリにコミットしないでください
- **信頼性**: 自己署名証明書で署名されたファイルは、CA証明書をルート証明書ストアにインストールするまで「信頼されていない」として扱われます
- **商用証明書**: 本番環境では、DigiCert、Symantec、Comodo等の商用証明書を使用してください

### VS Code Tasks

このプロジェクトには以下のVS Code Tasksが設定されています：

- **Maven Build**: `Ctrl+Shift+P` → `Tasks: Run Task` → `Maven Build`
- **Run Updater**: `Ctrl+Shift+P` → `Tasks: Run Task` → `Run Updater`
- **Build EXE**: `Ctrl+Shift+P` → `Tasks: Run Task` → `Build EXE`
- **Run EXE**: `Ctrl+Shift+P` → `Tasks: Run Task` → `Run EXE`

### 実行ファイル（EXE）の作成

Launch4j を使用して Windows 実行ファイルを作成できます：

```powershell
# EXE作成（従来の方法）
.\build-exe.ps1

# 署名付きEXE作成（推奨）
.\dev-build.ps1
```

## 使用方法

1. **アプリケーションを起動**
   - JAR ファイルまたは EXE ファイルを実行します

2. **自動処理の確認**
   - バージョンチェック
   - Minecraft プロセスの確認（実行中の場合は終了を促します）
   - Java 実行環境の検出

3. **Fabricのインストール**
   - 最新の Fabric Installer を自動ダウンロード
   - 指定された Minecraft バージョンで Fabric をインストール

4. **Modpackの処理**
   - サーバーから modpack リストをダウンロード
   - 必要な mod ファイルをダウンロード
   - 不要なファイルを削除

5. **完了**
   - Minecraft ランチャーで「A-B-C-D」プロファイルから起動

## プロジェクト構造

```
abcd-modpack/
├── src/
│   └── main/
│       ├── java/
│       │   └── com/abcd/modpack/
│       │       └── Updater.java          # メインクラス
│       └── resources/
│           └── icon.ico                  # アプリケーションアイコン
├── certificates/                         # 証明書ディレクトリ（自動生成）
├── target/                               # ビルド出力ディレクトリ
├── .env                                  # 環境変数ファイル（要作成）
├── env-helper.ps1                       # 環境変数読み込みヘルパー
├── pom.xml                              # Maven設定ファイル
├── launch4j-config.xml                  # Launch4j設定ファイル
├── build-exe.ps1                       # EXE作成スクリプト
├── sign-exe.ps1                        # EXE署名スクリプト
├── create-test-certificate.ps1         # テスト証明書作成スクリプト
├── dev-build.ps1                       # 統合ビルド・署名スクリプト
├── certificate-manager.ps1             # 証明書管理スクリプト
└── abcd-modpack.ps1                     # 実行スクリプト
```

## 設定ファイル

### Maven設定 (pom.xml)
- プロジェクトの依存関係とビルド設定
- Java 11 をターゲット
- Maven Compiler Plugin の設定

### Launch4j 設定 (launch4j-config.xml)
- Windows 実行ファイル作成の設定
- JRE の最小/最大バージョン指定
- アプリケーションアイコンの設定

## トラブルシューティング

### Java実行環境が見つからない場合
アプリケーションは以下の順序で Java を検索します：
1. Microsoft Store 版 Minecraft 付属の Java
2. JAVA_HOME 環境変数で指定された Java

### Minecraftが実行中の場合
アプリケーションは Minecraft プロセスを検出し、終了を促します。ランチャーを含むすべての Minecraft 関連プロセスを終了してください。

### 文字化けが発生する場合
アプリケーションは Windows 環境での文字化けを防ぐため、複数のエンコーディング（Shift_JIS、システムデフォルト）を試行します。

## ライセンス

このプロジェクトのライセンスについては、プロジェクト管理者にお問い合わせください。

## サポート

問題や質問がある場合は、以下のリソースを確認してください：
- [A-B-C-D 公式サイト](https://a-b-c-d.com/)
- [Modpack ダウンロードページ](https://a-b-c-d.com/modpacks/)

---

**注意**: このアプリケーションはMinecraft Java Edition での使用を前提としています。Bedrock Edition では動作しません。
