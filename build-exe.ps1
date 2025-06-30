# ABCD Modpack EXE ビルダー
# Launch4jを使用してJARファイルからEXEファイルを作成します

Write-Host "A-B-C-D Modpack EXE ビルダー" -ForegroundColor Green
Write-Host "========================"

Write-Host "`nステップ1: JAR のクリーンビルド..." -ForegroundColor Yellow
& mvn clean package

if ($LASTEXITCODE -ne 0) {
    Write-Host "エラー: Maven ビルドが失敗しました！" -ForegroundColor Red
    Read-Host "続行するには何かキーを押してください"
    exit 1
}

Write-Host "`nステップ2: Launch4j でEXE作成中..." -ForegroundColor Yellow

# Launch4jの設定ファイルが存在するかチェック
if (!(Test-Path "launch4j-config.xml")) {
    Write-Host "エラー: launch4j-config.xml が見つかりません！" -ForegroundColor Red
    Write-Host "Launch4jの設定ファイルが必要です。" -ForegroundColor Red
    Read-Host "続行するには何かキーを押してください"
    exit 1
}

# アイコンファイルの存在確認と代替パスでのコピー
Write-Host "アイコンファイルの確認と準備..." -ForegroundColor Gray
$iconSourcePath = "src/main/resources/icon.ico"
$iconTargetPath = "target/classes/icon.ico"
$iconLocalPath = "icon.ico"

if (Test-Path $iconSourcePath) {
    $iconInfo = Get-Item $iconSourcePath
    Write-Host "✓ ソースアイコンファイル: $iconSourcePath (サイズ: $($iconInfo.Length) bytes)" -ForegroundColor Green
    
    # ICOファイルの基本的なフォーマット確認
    try {
        $bytes = [System.IO.File]::ReadAllBytes($iconSourcePath)
        if ($bytes.Length -ge 4 -and $bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 1 -and $bytes[3] -eq 0) {
            Write-Host "✓ ICOファイルフォーマットが正しく認識されました" -ForegroundColor Green
        } else {
            Write-Host "警告: ICOファイルフォーマットの署名が不正です" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "警告: ICOファイルの読み取りエラー: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # target/classesにもコピーされているか確認
    if (Test-Path $iconTargetPath) {
        Write-Host "✓ ターゲットアイコンファイル: $iconTargetPath" -ForegroundColor Green
    } else {
        Write-Host "警告: target/classes にアイコンファイルがありません。コピーしています..." -ForegroundColor Yellow
        if (!(Test-Path "target/classes")) {
            New-Item -ItemType Directory -Path "target/classes" -Force | Out-Null
        }
        Copy-Item $iconSourcePath $iconTargetPath -Force
        Write-Host "✓ アイコンファイルをコピーしました: $iconTargetPath" -ForegroundColor Green
    }
    
    # Launch4jが確実にアイコンを見つけられるよう、カレントディレクトリにもコピー
    Copy-Item $iconSourcePath $iconLocalPath -Force
    Write-Host "✓ Launch4j用にアイコンファイルをローカルにコピーしました: $iconLocalPath" -ForegroundColor Green
} else {
    Write-Host "エラー: アイコンファイルが見つかりません: $iconSourcePath" -ForegroundColor Red
}

# Launch4jを実行（環境に応じてパスを調整）
$launch4jPath = "C:\Program Files (x86)\Launch4j\launch4jc.exe"
if (Test-Path $launch4jPath) {
    Write-Host "Launch4j 実行中: $launch4jPath" -ForegroundColor Gray
    Write-Host "設定ファイル: launch4j-config.xml" -ForegroundColor Gray
    & $launch4jPath "launch4j-config.xml"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Launch4j が正常に完了しました" -ForegroundColor Green
    } else {
        Write-Host "警告: Launch4j がエラーコード $LASTEXITCODE で終了しました" -ForegroundColor Yellow
    }
} else {
    Write-Host "Launch4jが見つかりません。手動でEXEを作成してください。" -ForegroundColor Yellow
    Write-Host "または Launch4j をインストールしてパスを確認してください。" -ForegroundColor Yellow
}

Write-Host "`nビルドが正常に完了しました！" -ForegroundColor Green
Write-Host "`n出力ファイル:"
Write-Host "- JAR: target/abcd-modpack-1.0.jar"
Write-Host "- EXE: target/abcd-modpack-updater.exe"

if (Test-Path "target/abcd-modpack-updater.exe") {
    Write-Host "`nEXEファイルが正常に作成されました！" -ForegroundColor Green
    $fileInfo = Get-Item "target/abcd-modpack-updater.exe"
    Write-Host "サイズ: $([math]::Round($fileInfo.Length / 1MB, 2)) MB ($($fileInfo.Length) bytes)"
    Write-Host "作成日時: $($fileInfo.CreationTime)"
    
    # EXEファイルのアイコン情報を確認
    Write-Host "`nEXEファイルの詳細情報:" -ForegroundColor Gray
    try {
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("target/abcd-modpack-updater.exe")
        Write-Host "ファイル説明: $($versionInfo.FileDescription)"
        Write-Host "バージョン: $($versionInfo.FileVersion)"
        Write-Host "プロダクト名: $($versionInfo.ProductName)"
        
        # アイコンの存在確認（PowerShellでは直接確認が難しいため、ファイルサイズで推測）
        $minExpectedSize = 100KB  # アイコンが含まれている場合の最小サイズ目安
        if ($fileInfo.Length -gt $minExpectedSize) {
            Write-Host "✓ EXEファイルサイズから判断すると、リソース（アイコン含む）が含まれている可能性があります" -ForegroundColor Green
        } else {
            Write-Host "警告: EXEファイルサイズが小さく、アイコンが含まれていない可能性があります" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "警告: EXEファイルの詳細情報を取得できませんでした" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n警告: EXEファイルが見つかりません。Launch4j が失敗した可能性があります。" -ForegroundColor Yellow
}

Write-Host "`nEXEファイルのテスト方法:"
Write-Host "  .\target\abcd-modpack-updater.exe" -ForegroundColor Cyan

# クリーンアップ: 一時的にコピーしたアイコンファイルを削除
if (Test-Path "icon.ico") {
    Remove-Item "icon.ico" -Force
    Write-Host "`n一時的なアイコンファイルをクリーンアップしました" -ForegroundColor Gray
}

Write-Host "`n次のステップ:"
Write-Host "  1. EXEファイルをテスト: .\target\abcd-modpack-updater.exe" -ForegroundColor White
Write-Host "  2. コード署名を追加: .\sign-exe-advanced.ps1" -ForegroundColor White
