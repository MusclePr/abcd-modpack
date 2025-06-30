# 証明書管理ヘルパースクリプト
# 作成した証明書の確認、インストール、削除を行います

param(
    [switch]$ListCertificates,
    [switch]$InstallCA,
    [switch]$UninstallCA,
    [switch]$ShowDetails,
    [switch]$VerifySignature,
    [string]$ExePath = ".\target\abcd-modpack-updater.exe"
)

# .envファイルからパスワードを読み込み
. .\env-helper.ps1
$envPassword = Get-EnvPassword

Write-Host "A-B-C-D Modpack 証明書管理ツール" -ForegroundColor Green
Write-Host "================================="

# 管理者権限チェック
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
        Read-Host "続行するには何かキーを押してください"
        exit 1
    }
}

# パラメータ処理
if (!$ListCertificates -and !$InstallCA -and !$UninstallCA -and !$ShowDetails -and !$VerifySignature) {
    Write-Host "`n使用方法:" -ForegroundColor White
    Write-Host "  .\certificate-manager.ps1 -ListCertificates    # 証明書一覧表示" -ForegroundColor Gray
    Write-Host "  .\certificate-manager.ps1 -ShowDetails         # 証明書詳細表示" -ForegroundColor Gray
    Write-Host "  .\certificate-manager.ps1 -InstallCA           # CA証明書をルートストアにインストール" -ForegroundColor Gray
    Write-Host "  .\certificate-manager.ps1 -UninstallCA         # CA証明書をルートストアから削除" -ForegroundColor Gray
    Write-Host "  .\certificate-manager.ps1 -VerifySignature     # EXEファイルの署名確認" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "何を実行しますか？ [1]証明書一覧 [2]詳細表示 [3]CA証明書インストール [4]CA証明書削除 [5]署名確認 (1-5)"
    switch ($choice) {
        "1" { $ListCertificates = $true }
        "2" { $ShowDetails = $true }
        "3" { $InstallCA = $true }
        "4" { $UninstallCA = $true }
        "5" { $VerifySignature = $true }
        default { 
            Write-Host "証明書一覧を表示します。" -ForegroundColor Yellow
            $ListCertificates = $true
        }
    }
}

# 証明書一覧表示
if ($ListCertificates) {
    Write-Host "`n作成された証明書ファイル:" -ForegroundColor Cyan
    
    $certDir = ".\certificates"
    if (Test-Path $certDir) {
        Get-ChildItem $certDir -File | ForEach-Object {
            Write-Host "  $($_.Name)" -ForegroundColor Gray
            Write-Host "    サイズ: $([math]::Round($_.Length / 1KB, 2)) KB" -ForegroundColor DarkGray
            Write-Host "    作成日時: $($_.CreationTime)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "証明書ディレクトリが見つかりません。" -ForegroundColor Yellow
        Write-Host "最初に create-test-certificate.ps1 を実行してください。" -ForegroundColor Yellow
    }
    
    Write-Host "`nインストール済み証明書（個人ストア）:" -ForegroundColor Cyan
    $personalCerts = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -like "*ABCD*" }
    if ($personalCerts) {
        $personalCerts | ForEach-Object {
            Write-Host "  Subject: $($_.Subject)" -ForegroundColor Gray
            Write-Host "  拇印: $($_.Thumbprint)" -ForegroundColor DarkGray
            Write-Host "  有効期間: $($_.NotBefore) ～ $($_.NotAfter)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  ABCD関連の証明書が見つかりません。" -ForegroundColor Gray
    }
    
    Write-Host "`nインストール済みCA証明書（ルートストア）:" -ForegroundColor Cyan
    try {
        $rootCerts = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*ABCD*" }
        if ($rootCerts) {
            $rootCerts | ForEach-Object {
                Write-Host "  Subject: $($_.Subject)" -ForegroundColor Gray
                Write-Host "  拇印: $($_.Thumbprint)" -ForegroundColor DarkGray
                Write-Host "  有効期間: $($_.NotBefore) ～ $($_.NotAfter)" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  ABCD関連のCA証明書が見つかりません。" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  ルートストアの確認に失敗しました（管理者権限が必要）" -ForegroundColor Yellow
    }
}

# 証明書詳細表示
if ($ShowDetails) {
    Write-Host "`n証明書の詳細情報:" -ForegroundColor Cyan
    
    $pfxPath = ".\certificates\code-signing-certificate.pfx"
    $caCertPath = ".\certificates\ca-certificate.pem"
    
    if (Test-Path $pfxPath) {
        Write-Host "`nコードサイニング証明書 (PFX):" -ForegroundColor White
        try {
            # OpenSSLで証明書詳細を表示
            $opensslPath = "openssl"
            $tempCert = [System.IO.Path]::GetTempFileName() + ".crt"
            
            & $opensslPath pkcs12 -in $pfxPath -clcerts -nokeys -out $tempCert -passin "pass:$envPassword" 2>$null
            if ($LASTEXITCODE -eq 0) {
                & $opensslPath x509 -in $tempCert -text -noout | Select-String "Subject:", "Issuer:", "Not Before", "Not After", "Key Usage", "Extended Key Usage"
                Remove-Item $tempCert -ErrorAction SilentlyContinue
            } else {
                Write-Host "OpenSSLによる詳細表示に失敗しました。" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "証明書詳細の取得に失敗しました: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    if (Test-Path $caCertPath) {
        Write-Host "`nCA証明書:" -ForegroundColor White
        try {
            & openssl x509 -in $caCertPath -text -noout | Select-String "Subject:", "Issuer:", "Not Before", "Not After"
        } catch {
            Write-Host "CA証明書詳細の取得に失敗しました。" -ForegroundColor Yellow
        }
    }
}

# CA証明書インストール
if ($InstallCA) {
    $caCertPath = ".\certificates\ca-certificate.pem"
    
    if (!(Test-Path $caCertPath)) {
        Write-Host "エラー: CA証明書ファイルが見つかりません: $caCertPath" -ForegroundColor Red
        Write-Host "最初に create-test-certificate.ps1 を実行してください。" -ForegroundColor Yellow
        exit 1
    }
    
    if (!(Test-Administrator)) {
        Start-ElevatedProcess "-InstallCA"
    }
    
    Write-Host "`nCA証明書をルート証明書ストアにインストール中..." -ForegroundColor Cyan
    
    try {
        Import-Certificate -FilePath $caCertPath -CertStoreLocation Cert:\LocalMachine\Root
        Write-Host "CA証明書が正常にインストールされました。" -ForegroundColor Green
        Write-Host "これにより、このCAで署名されたファイルが信頼済みとして認識されます。" -ForegroundColor Gray
    } catch {
        Write-Host "エラー: CA証明書のインストールに失敗しました: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# CA証明書削除
if ($UninstallCA) {
    if (!(Test-Administrator)) {
        Start-ElevatedProcess "-UninstallCA"
    }
    
    Write-Host "`nルート証明書ストアからABCD CA証明書を削除中..." -ForegroundColor Cyan
    
    try {
        $rootCerts = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*ABCD Development CA*" }
        
        if ($rootCerts) {
            foreach ($cert in $rootCerts) {
                Write-Host "削除中: $($cert.Subject)" -ForegroundColor Gray
                Remove-Item "Cert:\LocalMachine\Root\$($cert.Thumbprint)"
            }
            Write-Host "CA証明書が正常に削除されました。" -ForegroundColor Green
        } else {
            Write-Host "削除対象のCA証明書が見つかりませんでした。" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "エラー: CA証明書の削除に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# 署名確認
if ($VerifySignature) {
    Write-Host "`nEXEファイルの署名確認:" -ForegroundColor Cyan
    
    if (!(Test-Path $ExePath)) {
        Write-Host "エラー: EXEファイルが見つかりません: $ExePath" -ForegroundColor Red
        Write-Host "最初にビルドを実行してください: .\build-exe.ps1" -ForegroundColor Yellow
        exit 1
    }
    
    try {
        $signature = Get-AuthenticodeSignature $ExePath
        
        Write-Host "`nファイル: $ExePath" -ForegroundColor White
        Write-Host "署名ステータス: $($signature.Status)" -ForegroundColor $(
            switch ($signature.Status) {
                "Valid" { "Green" }
                "NotSigned" { "Red" }
                default { "Yellow" }
            }
        )
        
        if ($signature.SignerCertificate) {
            Write-Host "署名者: $($signature.SignerCertificate.Subject)" -ForegroundColor Gray
            Write-Host "発行者: $($signature.SignerCertificate.Issuer)" -ForegroundColor Gray
            Write-Host "有効期間: $($signature.SignerCertificate.NotBefore) ～ $($signature.SignerCertificate.NotAfter)" -ForegroundColor Gray
            Write-Host "拇印: $($signature.SignerCertificate.Thumbprint)" -ForegroundColor Gray
        }
        
        if ($signature.TimeStamperCertificate) {
            Write-Host "タイムスタンプ: $($signature.TimeStamperCertificate.Subject)" -ForegroundColor Gray
        } else {
            Write-Host "タイムスタンプ: なし" -ForegroundColor Gray
        }
        
        # 署名の詳細確認
        Write-Host "`n署名の詳細確認:" -ForegroundColor White
        switch ($signature.Status) {
            "Valid" {
                Write-Host "✓ 署名は有効です" -ForegroundColor Green
            }
            "NotSigned" {
                Write-Host "✗ ファイルは署名されていません" -ForegroundColor Red
            }
            "HashMismatch" {
                Write-Host "✗ ハッシュが一致しません（ファイルが改ざんされている可能性）" -ForegroundColor Red
            }
            "NotTrusted" {
                Write-Host "⚠ 署名は有効ですが、証明書が信頼されていません" -ForegroundColor Yellow
                Write-Host "  CA証明書をインストールしてください: .\certificate-manager.ps1 -InstallCA" -ForegroundColor Gray
            }
            default {
                Write-Host "⚠ 署名ステータス: $($signature.Status)" -ForegroundColor Yellow
                Write-Host "  詳細: $($signature.StatusMessage)" -ForegroundColor Gray
            }
        }
        
    } catch {
        Write-Host "エラー: 署名確認に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n証明書管理操作が完了しました。" -ForegroundColor Green
Read-Host "続行するには何かキーを押してください"
