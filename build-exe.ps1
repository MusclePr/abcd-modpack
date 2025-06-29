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

# Launch4jを実行（環境に応じてパスを調整）
$launch4jPath = "C:\Program Files (x86)\Launch4j\launch4jc.exe"
if (Test-Path $launch4jPath) {
    & $launch4jPath "launch4j-config.xml"
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
} else {
    Write-Host "`n警告: EXEファイルが見つかりません。Launch4j が失敗した可能性があります。" -ForegroundColor Yellow
}

Write-Host "`nEXEファイルのテスト方法:"
Write-Host "  .\target\abcd-modpack-updater.exe" -ForegroundColor Cyan
Write-Host "`n次のステップ:"
Write-Host "  1. EXEファイルをテスト: .\target\abcd-modpack-updater.exe" -ForegroundColor White
Write-Host "  2. コード署名を追加: .\sign-exe.ps1 -CertThumbprint <証明書の拇印>" -ForegroundColor White
