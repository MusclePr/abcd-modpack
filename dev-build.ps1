# A-B-C-D Modpack 開発用統合ビルド・署名スクリプト
# このスクリプトはビルドから署名まで全ての処理を統合します

param(
    [switch]$CreateCertificate,
    [switch]$SignOnly,
    [switch]$BuildOnly,
    [switch]$InstallCA,
    [switch]$CleanAll,
    [string]$CertPassword = "",
    [switch]$Force
)

# .envファイルからパスワードを読み込み
. .\env-helper.ps1
if ([string]::IsNullOrEmpty($CertPassword)) {
    $CertPassword = Get-EnvPassword
}

Write-Host "A-B-C-D Modpack 統合開発ツール" -ForegroundColor Green
Write-Host "=================================="
Write-Host "テスト・開発用のビルドと署名を統合処理します`n" -ForegroundColor Cyan

# 管理者権限チェック（CA証明書インストール時に必要）
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 管理者権限に昇格
function Start-ElevatedProcess {
    param(
        [string[]]$ArgumentList = $args
    )
    
    try {
        Write-Host "管理者権限が必要です。PowerShellを管理者として再起動しています..." -ForegroundColor Yellow
        
        # 現在のスクリプトパスと引数を取得
        $scriptPath = $PSCommandPath
        $currentDirectory = Get-Location
        $arguments = ""
        
        # 元の引数を再構築
        if ($ArgumentList) {
            $arguments = $ArgumentList -join " "
        }
        
        # カレントディレクトリを維持するためのコマンド
        $command = "Set-Location '$currentDirectory'; & '$scriptPath' $arguments"
        
        # 管理者権限でPowerShellを起動
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "powershell.exe"
        $processInfo.Arguments = "-ExecutionPolicy Bypass -Command `"$command`""
        $processInfo.Verb = "runas"
        $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
        
        $process = [System.Diagnostics.Process]::Start($processInfo)
        
        # 現在のプロセスを終了
        exit 0
        
    } catch {
        Write-Host "エラー: 管理者権限での起動に失敗しました。" -ForegroundColor Red
        Write-Host "手動でPowerShellを管理者として実行してから、再度このスクリプトを実行してください。" -ForegroundColor Yellow
        Write-Host "詳細: $($_.Exception.Message)" -ForegroundColor Gray
        exit 1
    }
}

# パラメータ処理
if (!$CreateCertificate -and !$SignOnly -and !$BuildOnly -and !$InstallCA -and !$CleanAll) {
    Write-Host "使用方法:" -ForegroundColor White
    Write-Host "  .\dev-build.ps1 -CreateCertificate    # テスト用証明書を作成" -ForegroundColor Gray
    Write-Host "  .\dev-build.ps1 -BuildOnly            # EXEファイルのビルドのみ" -ForegroundColor Gray
    Write-Host "  .\dev-build.ps1 -SignOnly             # 署名処理のみ" -ForegroundColor Gray
    Write-Host "  .\dev-build.ps1                       # 全処理（ビルド→署名）" -ForegroundColor Gray
    Write-Host "  .\dev-build.ps1 -InstallCA            # CA証明書をルートストアにインストール" -ForegroundColor Gray
    Write-Host "  .\dev-build.ps1 -CleanAll             # 全ての生成物を削除" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "何を実行しますか？ [1]全処理 [2]証明書作成のみ [3]ビルドのみ [4]署名のみ [5]クリーンアップ (1-5)"
    switch ($choice) {
        "1" { $BuildOnly = $false; $SignOnly = $false }
        "2" { $CreateCertificate = $true }
        "3" { $BuildOnly = $true }
        "4" { $SignOnly = $true }
        "5" { $CleanAll = $true }
        default { 
            Write-Host "デフォルトで全処理を実行します。" -ForegroundColor Yellow
            $BuildOnly = $false; $SignOnly = $false 
        }
    }
}

# クリーンアップ処理
if ($CleanAll) {
    Write-Host "`nクリーンアップを実行中..." -ForegroundColor Yellow
    
    # Maven クリーン
    if (Test-Path "target") {
        Write-Host "Maven target ディレクトリを削除..." -ForegroundColor Gray
        & mvn clean
    }
    
    # 証明書ディレクトリの削除
    if (Test-Path "certificates") {
        Write-Host "証明書ディレクトリを削除..." -ForegroundColor Gray
        Remove-Item "certificates" -Recurse -Force
    }
    
    # ログファイルの削除
    Get-ChildItem "*.log" -ErrorAction SilentlyContinue | Remove-Item -Force
    
    Write-Host "クリーンアップが完了しました。" -ForegroundColor Green
    exit 0
}

# CA証明書の確認と準備処理
Write-Host "`nステップ0: CA証明書の確認と準備..." -ForegroundColor Cyan

$caCertSourcePath = "certificates/ca-certificate.pem"
$caCertTargetPath = "src/main/resources/ca-certificate.pem"

if (Test-Path $caCertSourcePath) {
    Write-Host "✓ CA証明書ファイルが見つかりました: $caCertSourcePath" -ForegroundColor Green
    
    # ソースとターゲットのファイル比較
    if (Test-Path $caCertTargetPath) {
        $sourceHash = (Get-FileHash $caCertSourcePath -Algorithm MD5).Hash
        $targetHash = (Get-FileHash $caCertTargetPath -Algorithm MD5).Hash
        
        if ($sourceHash -eq $targetHash) {
            Write-Host "✓ CA証明書は既に最新です" -ForegroundColor Green
        } else {
            Write-Host "CA証明書が古いバージョンです。更新しています..." -ForegroundColor Yellow
            Copy-Item $caCertSourcePath $caCertTargetPath -Force
            Write-Host "✓ CA証明書を更新しました: $caCertTargetPath" -ForegroundColor Green
        }
    } else {
        Write-Host "CA証明書がresourcesディレクトリにありません。コピーしています..." -ForegroundColor Yellow
        # resourcesディレクトリが存在しない場合は作成
        $resourcesDir = Split-Path $caCertTargetPath -Parent
        if (!(Test-Path $resourcesDir)) {
            New-Item -ItemType Directory -Path $resourcesDir -Force | Out-Null
            Write-Host "✓ resourcesディレクトリを作成しました: $resourcesDir" -ForegroundColor Green
        }
        Copy-Item $caCertSourcePath $caCertTargetPath -Force
        Write-Host "✓ CA証明書をコピーしました: $caCertTargetPath" -ForegroundColor Green
    }
} else {
    Write-Host "警告: CA証明書が見つかりません: $caCertSourcePath" -ForegroundColor Yellow
    if (-not $CreateCertificate) {
        Write-Host "証明書が見つからないため、証明書作成フラグを有効にします..." -ForegroundColor Yellow
        $CreateCertificate = $true
    }
}

# 証明書作成処理
if ($CreateCertificate) {
    Write-Host "`nステップ1: テスト用証明書を作成中..." -ForegroundColor Cyan
    & .\create-test-certificate.ps1 -CertPassword $CertPassword -Force:$Force
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "エラー: 証明書の作成に失敗しました。" -ForegroundColor Red
        exit 1
    }
    
    # 新しく作成されたCA証明書をリソースにコピー
    Write-Host "新しく作成されたCA証明書をリソースディレクトリにコピー中..." -ForegroundColor Gray
    if (Test-Path $caCertSourcePath) {
        # resourcesディレクトリが存在しない場合は作成
        $resourcesDir = Split-Path $caCertTargetPath -Parent
        if (!(Test-Path $resourcesDir)) {
            New-Item -ItemType Directory -Path $resourcesDir -Force | Out-Null
            Write-Host "✓ resourcesディレクトリを作成しました: $resourcesDir" -ForegroundColor Green
        }
        Copy-Item $caCertSourcePath $caCertTargetPath -Force
        Write-Host "✓ 新しいCA証明書をリソースにコピーしました: $caCertTargetPath" -ForegroundColor Green
    }
    
    if ($InstallCA) {
        Write-Host "`nCA証明書をルート証明書ストアにインストールしますか？" -ForegroundColor Yellow
        Write-Host "（これにより、署名されたファイルが信頼済みとして認識されます）" -ForegroundColor Gray
        $install = Read-Host "[Y]はい [N]いいえ (Y/N)"
        
        if ($install -eq "Y" -or $install -eq "y") {
            if (!(Test-Administrator)) {
                Write-Host "CA証明書のインストールには管理者権限が必要です。" -ForegroundColor Yellow
                $elevate = Read-Host "管理者権限で再起動しますか？ [Y]はい [N]いいえ (Y/N)"
                if ($elevate -eq "Y" -or $elevate -eq "y") {
                    Start-ElevatedProcess "-CreateCertificate" "-InstallCA"
                } else {
                    Write-Host "CA証明書のインストールをスキップしました。" -ForegroundColor Yellow
                    Write-Host "後で手動でインストールできます: .\install-ca.ps1" -ForegroundColor Gray
                }
            } else {
                $caCertPath = ".\certificates\ca-certificate.pem"
                if (Test-Path $caCertPath) {
                    try {
                        Import-Certificate -FilePath $caCertPath -CertStoreLocation Cert:\LocalMachine\Root
                        Write-Host "CA証明書がルート証明書ストアにインストールされました。" -ForegroundColor Green
                    } catch {
                        Write-Host "警告: CA証明書のインストールに失敗しました: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
            }
        }
    }
    
    Write-Host "`n証明書の作成が完了しました！" -ForegroundColor Green
    
    if (!$BuildOnly -and !$SignOnly) {
        exit 0
    }
}

# ビルド処理
if (!$SignOnly) {
    Write-Host "`nステップ2: EXEファイルをビルド中..." -ForegroundColor Cyan
    & .\build-exe.ps1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "エラー: ビルドに失敗しました。" -ForegroundColor Red
        exit 1
    }
    
    if ($BuildOnly) {
        Write-Host "`nビルドが完了しました！" -ForegroundColor Green
        exit 0
    }
}

# 署名処理
if (!$BuildOnly) {
    Write-Host "`nステップ3: EXEファイルに署名中..." -ForegroundColor Cyan
    
    $pfxPath = ".\certificates\code-signing-certificate.pfx"
    if (!(Test-Path $pfxPath)) {
        Write-Host "警告: 証明書ファイルが見つかりません: $pfxPath" -ForegroundColor Yellow
        Write-Host "最初に証明書を作成してください: .\dev-build.ps1 -CreateCertificate" -ForegroundColor Yellow
        exit 1
    }

    & .\sign-exe.ps1 -PfxPath $pfxPath -Password $CertPassword -Force:$Force
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "エラー: 署名に失敗しました。" -ForegroundColor Red
        exit 1
    }
    
    # 署名後の検証
    Write-Host "`nステップ4: 署名済みEXEファイルの検証中..." -ForegroundColor Cyan
    & .\validate-exe.ps1 -ExePath ".\target\abcd-modpack-updater.exe"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "警告: EXEファイルの検証で問題が検出されました。" -ForegroundColor Yellow
        Write-Host "署名前のバックアップファイルがある場合は、それを使用することを検討してください。" -ForegroundColor Yellow
    }
}

# 最終確認
Write-Host "`n全ての処理が正常に完了しました！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

$exePath = ".\target\abcd-modpack-updater.exe"
if (Test-Path $exePath) {
    Write-Host "`n署名済みEXEファイル: $exePath" -ForegroundColor White
    
    # ファイル情報表示
    $fileInfo = Get-Item $exePath
    Write-Host "ファイルサイズ: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
    Write-Host "作成日時: $($fileInfo.CreationTime)" -ForegroundColor Gray
    
    # 署名確認
    try {
        $signature = Get-AuthenticodeSignature $exePath
        Write-Host "署名ステータス: $($signature.Status)" -ForegroundColor $(if ($signature.Status -eq "Valid") { "Green" } else { "Yellow" })
        Write-Host "署名者: $($signature.SignerCertificate.Subject)" -ForegroundColor Gray
    } catch {
        Write-Host "署名確認に失敗しました: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host "`nテスト実行:" -ForegroundColor White
    Write-Host "  $exePath" -ForegroundColor Cyan
    
    $runTest = Read-Host "`n署名済みEXEファイルをテスト実行しますか？ [Y]はい [N]いいえ (Y/N)"
    if ($runTest -eq "Y" -or $runTest -eq "y") {
        Write-Host "EXEファイルを実行中..." -ForegroundColor Cyan
        & $exePath
    }
}

Write-Host "`n開発用ビルド・署名プロセスが完了しました。" -ForegroundColor Green

