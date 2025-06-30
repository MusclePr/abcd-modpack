# CA証明書自動インストールスクリプト
# 管理者権限で実行してください

param(
    [string]$CertPath = ".\certificates\ca-certificate.pem",
    [switch]$Uninstall
)

# 管理者権限チェック
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 管理者権限に昇格
function Start-ElevatedProcess {
    param(
        [string]$FilePath = $PSCommandPath,
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
        Read-Host "続行するには何かキーを押してください"
        exit 1
    }
}

if (!(Test-Administrator)) {
    Start-ElevatedProcess
}

Write-Host "A-B-C-D CA証明書管理ツール" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

if ($Uninstall) {
    Write-Host "`nCA証明書をアンインストール中..." -ForegroundColor Yellow
    
    try {
        $certs = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*ABCD Development CA*" }
        
        if ($certs) {
            foreach ($cert in $certs) {
                Write-Host "削除中: $($cert.Subject)" -ForegroundColor Gray
                Remove-Item "Cert:\LocalMachine\Root\$($cert.Thumbprint)" -Force
            }
            Write-Host "CA証明書が正常に削除されました。" -ForegroundColor Green
        } else {
            Write-Host "削除対象のCA証明書が見つかりませんでした。" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "エラー: CA証明書の削除に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    if (!(Test-Path $CertPath)) {
        Write-Host "エラー: CA証明書ファイルが見つかりません: $CertPath" -ForegroundColor Red
        Write-Host "最初に証明書を作成してください: .\create-test-certificate.ps1" -ForegroundColor Yellow
        Read-Host "続行するには何かキーを押してください"
        exit 1
    }
    
    Write-Host "`nCA証明書をインストール中..." -ForegroundColor Cyan
    Write-Host "証明書ファイル: $CertPath" -ForegroundColor Gray
    
    try {
        # 既存の証明書をチェック
        $existingCerts = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*ABCD Development CA*" }
        if ($existingCerts) {
            Write-Host "既存のABCD CA証明書が見つかりました。削除してから新しい証明書をインストールします。" -ForegroundColor Yellow
            foreach ($cert in $existingCerts) {
                Remove-Item "Cert:\LocalMachine\Root\$($cert.Thumbprint)" -Force
            }
        }
        
        # 新しい証明書をインストール
        $importedCert = Import-Certificate -FilePath $CertPath -CertStoreLocation Cert:\LocalMachine\Root
        
        Write-Host "`nCA証明書が正常にインストールされました！" -ForegroundColor Green
        Write-Host "証明書情報:" -ForegroundColor White
        Write-Host "  Subject: $($importedCert.Subject)" -ForegroundColor Gray
        Write-Host "  Issuer: $($importedCert.Issuer)" -ForegroundColor Gray
        Write-Host "  Thumbprint: $($importedCert.Thumbprint)" -ForegroundColor Gray
        Write-Host "  有効期間: $($importedCert.NotBefore) ～ $($importedCert.NotAfter)" -ForegroundColor Gray
        
        Write-Host "`n効果:" -ForegroundColor White
        Write-Host "  ✓ このCAで署名されたファイルが信頼済みとして認識されます" -ForegroundColor Green
        Write-Host "  ✓ SmartScreenによる警告が表示されなくなります" -ForegroundColor Green
        Write-Host "  ✓ Windowsセキュリティによる署名検証がパスします" -ForegroundColor Green
        
    } catch {
        Write-Host "エラー: CA証明書のインストールに失敗しました: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n操作が完了しました。" -ForegroundColor Green
Read-Host "続行するには何かキーを押してください"
