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

### コマンドライン

```powershell
# プロジェクトをクローン
git clone https://github.com/MusclePr/abcd-modpack.git
cd abcd-modpack

.\build-exe.ps1
```

### VS Code Tasks

このプロジェクトには以下のVS Code Tasksが設定されています：

- **Maven Build**: `Ctrl+Shift+P` → `Tasks: Run Task` → `Maven Build`
- **Run Updater**: `Ctrl+Shift+P` → `Tasks: Run Task` → `Run Updater`
- **Build EXE**: `Ctrl+Shift+P` → `Tasks: Run Task` → `Build EXE`
- **Run EXE**: `Ctrl+Shift+P` → `Tasks: Run Task` → `Run EXE`

### 実行ファイル（EXE）の作成

Launch4j を使用して Windows 実行ファイルを作成できます：

```powershell
# EXEファイルをビルド
.\build-exe.ps1

# 作成されたEXEを実行
.\target\abcd-modpack-updater.exe
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
├── target/                               # ビルド出力ディレクトリ
├── pom.xml                              # Maven設定ファイル
├── launch4j-config.xml                  # Launch4j設定ファイル
├── build-exe.ps1                       # EXE作成スクリプト
├── sign-exe.ps1                        # EXE署名スクリプト
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
