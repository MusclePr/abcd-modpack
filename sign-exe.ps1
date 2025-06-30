# A-B-C-D Modpack EXE コードサイニングスクリプト
# このスクリプトはEXEファイルにデジタル署名を追加します

param(
    [string]$ExePath = ".\target\abcd-modpack-updater.exe",
    [string]$PfxPath = ".\certificates\code-signing-certificate.pfx",
    [string]$Password = "",
    [string]$CertThumbprint = "",
    [string]$TimestampUrl = "http://timestamp.digicert.com",
    [switch]$Force,
    [switch]$ShowCertDetails
)

# .envファイルからパスワードを読み込み
. .\env-helper.ps1
if ([string]::IsNullOrEmpty($Password)) {
    $Password = Get-EnvPassword
}

Write-Host "A-B-C-D Modpack コードサイニングツール" -ForegroundColor Green
Write-Host "======================================"

# EXEファイルの存在確認
if (!(Test-Path $ExePath)) {
    Write-Host "エラー: EXEファイルが見つかりません: $ExePath" -ForegroundColor Red
    Write-Host "最初に build-exe.ps1 を実行してEXEファイルを作成してください。" -ForegroundColor Yellow
    Read-Host "続行するには何かキーを押してください"
    exit 1
}

Write-Host "署名対象のEXE: $ExePath" -ForegroundColor Cyan
$fileInfo = Get-Item $ExePath
Write-Host "ファイルサイズ: $([math]::Round($fileInfo.Length / 1MB, 2)) MB ($($fileInfo.Length) bytes)" -ForegroundColor Gray
Write-Host "作成日時: $($fileInfo.CreationTime)" -ForegroundColor Gray

# 既存の署名確認
try {
    $existingSignature = Get-AuthenticodeSignature $ExePath
    if ($existingSignature.Status -eq "Valid") {
        Write-Host "`n既存の有効な署名が検出されました:" -ForegroundColor Yellow
        Write-Host "署名者: $($existingSignature.SignerCertificate.Subject)" -ForegroundColor Gray
        Write-Host "タイムスタンプ: $($existingSignature.TimeStamperCertificate.NotAfter)" -ForegroundColor Gray
        
        if (!$Force) {
            $overwrite = Read-Host "既存の署名を上書きしますか？ (y/N)"
            if ($overwrite -ne "y" -and $overwrite -ne "Y") {
                Write-Host "署名処理をキャンセルしました。" -ForegroundColor Yellow
                exit 0
            }
        }
    }
} catch {
    # 署名がない場合は正常
}

# 証明書の選択と検証
$certificate = $null

if ($CertThumbprint -ne "") {
    # 拇印が指定された場合、証明書ストアから取得
    Write-Host "`n証明書ストアから証明書を検索中..." -ForegroundColor Cyan
    $certificate = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $CertThumbprint }
    
    if (!$certificate) {
        $certificate = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $CertThumbprint }
    }
    
    if (!$certificate) {
        Write-Host "エラー: 指定された拇印の証明書が見つかりません: $CertThumbprint" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "証明書が見つかりました: $($certificate.Subject)" -ForegroundColor Green
    
} elseif (Test-Path $PfxPath) {
    # PFXファイルが存在する場合
    Write-Host "`nPFXファイルから証明書を読み込み中..." -ForegroundColor Cyan
    Write-Host "PFXファイル: $PfxPath" -ForegroundColor Gray
    
    try {
        # PFXファイルをインポート（一時的に個人ストアに追加）
        $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
        $certificate = Import-PfxCertificate -FilePath $PfxPath -CertStoreLocation Cert:\CurrentUser\My -Password $securePassword -Exportable
        
        Write-Host "証明書のインポートが完了しました: $($certificate.Subject)" -ForegroundColor Green
        $certImported = $true
        
    } catch {
        Write-Host "エラー: PFXファイルの読み込みに失敗しました: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
} else {
    Write-Host "エラー: 証明書が指定されていません。" -ForegroundColor Red
    Write-Host "以下のいずれかを指定してください:" -ForegroundColor Yellow
    Write-Host "1. -CertThumbprint を使用して証明書ストアの証明書を指定" -ForegroundColor White
    Write-Host "2. -PfxPath を使用してPFXファイルを指定" -ForegroundColor White
    Write-Host "3. 最初に create-test-certificate.ps1 を実行してテスト証明書を作成" -ForegroundColor White
    exit 1
}

# 証明書詳細の表示
if ($ShowCertDetails -or $true) {
    Write-Host "`n証明書の詳細:" -ForegroundColor White
    Write-Host "Subject: $($certificate.Subject)" -ForegroundColor Gray
    Write-Host "Issuer: $($certificate.Issuer)" -ForegroundColor Gray
    Write-Host "有効期間: $($certificate.NotBefore) ～ $($certificate.NotAfter)" -ForegroundColor Gray
    Write-Host "拇印: $($certificate.Thumbprint)" -ForegroundColor Gray
    
    # コードサイニングの用途確認
    $hasCodeSigning = $certificate.EnhancedKeyUsageList | Where-Object { $_.ObjectId -eq "1.3.6.1.5.5.7.3.3" }
    if ($hasCodeSigning) {
        Write-Host "コードサイニング用途: 有効 ✓" -ForegroundColor Green
    } else {
        Write-Host "警告: この証明書はコードサイニング用途が設定されていません" -ForegroundColor Yellow
    }
}

# コードサイニングの実行
Write-Host "`nEXEファイルに署名中..." -ForegroundColor Cyan

try {
    # SignTool.exe の検索
    $signToolPath = $null
    $possiblePaths = @(
        "signtool",
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe",
        "${env:ProgramFiles}\Windows Kits\10\bin\*\x64\signtool.exe",
        "${env:ProgramFiles(x86)}\Windows Kits\8.1\bin\x64\signtool.exe",
        "${env:ProgramFiles}\Windows Kits\8.1\bin\x64\signtool.exe"
    )
    
    foreach ($path in $possiblePaths) {
        $resolved = Get-ChildItem $path -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($resolved -and (Test-Path $resolved.FullName)) {
            $signToolPath = $resolved.FullName
            break
        }
    }
    
    if (!$signToolPath) {
        # SignTool が見つからない場合、Set-AuthenticodeSignature を使用
        Write-Host "SignTool.exe が見つかりません。PowerShellの署名機能を使用します。" -ForegroundColor Yellow
        
        $signature = Set-AuthenticodeSignature -FilePath $ExePath -Certificate $certificate
        
        if ($signature.Status -eq "Valid") {
            Write-Host "署名が正常に完了しました！" -ForegroundColor Green
        } else {
            throw "署名に失敗しました: $($signature.StatusMessage)"
        }
    } else {
        # SignTool.exe を使用してタイムスタンプ付きで署名
        Write-Host "SignTool を使用して署名中: $signToolPath" -ForegroundColor Gray
        
        $arguments = @(
            "sign",
            "/sha1", $certificate.Thumbprint,
            "/t", $TimestampUrl,
            "/v",
            "`"$ExePath`""
        )
        
        $process = Start-Process -FilePath $signToolPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Host "SignTool による署名が正常に完了しました！" -ForegroundColor Green
        } else {
            throw "SignTool による署名に失敗しました (終了コード: $($process.ExitCode))"
        }
    }
    
} catch {
    Write-Host "エラー: 署名処理に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 署名結果の確認
Write-Host "`n署名結果の確認..." -ForegroundColor Cyan
try {
    $finalSignature = Get-AuthenticodeSignature $ExePath
    
    Write-Host "署名ステータス: $($finalSignature.Status)" -ForegroundColor $(if ($finalSignature.Status -eq "Valid") { "Green" } else { "Yellow" })
    Write-Host "署名者: $($finalSignature.SignerCertificate.Subject)" -ForegroundColor Gray
    
    if ($finalSignature.TimeStamperCertificate) {
        Write-Host "タイムスタンプ: $($finalSignature.TimeStamperCertificate.Subject)" -ForegroundColor Gray
    }
    
    # ファイル情報の更新表示
    $newFileInfo = Get-Item $ExePath
    Write-Host "署名後のファイルサイズ: $([math]::Round($newFileInfo.Length / 1MB, 2)) MB ($($newFileInfo.Length) bytes)" -ForegroundColor Gray
    
} catch {
    Write-Host "警告: 署名結果の確認に失敗しました: $($_.Exception.Message)" -ForegroundColor Yellow
}

# インポートした証明書のクリーンアップ（PFXから読み込んだ場合）
if ($certImported -and $certificate) {
    Write-Host "`n一時的にインポートした証明書を削除中..." -ForegroundColor Cyan
    try {
        Remove-Item "Cert:\CurrentUser\My\$($certificate.Thumbprint)" -ErrorAction SilentlyContinue
        Write-Host "証明書のクリーンアップが完了しました。" -ForegroundColor Gray
    } catch {
        Write-Host "警告: 証明書のクリーンアップに失敗しました: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nコードサイニングが正常に完了しました！" -ForegroundColor Green
Write-Host "`n署名済みEXEファイル: $ExePath" -ForegroundColor White

Write-Host "`n次のステップ:" -ForegroundColor White
Write-Host "1. 署名済みEXEファイルをテスト: $ExePath" -ForegroundColor Cyan
Write-Host "2. 署名確認: Get-AuthenticodeSignature `"$ExePath`"" -ForegroundColor Cyan

Read-Host "続行するには何かキーを押してください"