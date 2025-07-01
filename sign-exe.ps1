# A-B-C-D Modpack 高度なEXE署名スクリプト
# Launch4j EXE内のJAR構造を保護する署名手法

param(
    [string]$ExePath = ".\target\abcd-modpack-updater.exe",
    [string]$PfxPath = ".\certificates\code-signing-certificate.pfx",
    [string]$Password = "",
    [string]$TimestampUrl = "http://timestamp.digicert.com",
    [switch]$Force,
    [switch]$ShowDetails
)

# .envファイルからパスワードを読み込み
. .\env-helper.ps1
if ([string]::IsNullOrEmpty($Password)) {
    $Password = Get-EnvPassword
}

Write-Host "A-B-C-D Modpack 高度なコードサイニングツール" -ForegroundColor Green
Write-Host "================================================"
Write-Host "Launch4j EXE内のJAR構造を保護する署名手法を使用します" -ForegroundColor Cyan

# EXEファイルの存在確認
if (!(Test-Path $ExePath)) {
    Write-Host "エラー: EXEファイルが見つかりません: $ExePath" -ForegroundColor Red
    exit 1
}

Write-Host "`n元のEXEファイル: $ExePath" -ForegroundColor White
$originalFile = Get-Item $ExePath
$originalSize = $originalFile.Length
Write-Host "元のファイルサイズ: $([math]::Round($originalSize / 1KB, 2)) KB ($originalSize bytes)" -ForegroundColor Gray

# 証明書の読み込み
Write-Host "`nPFXファイルから証明書を読み込み中..." -ForegroundColor Cyan
try {
    $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    $certificate = Import-PfxCertificate -FilePath $PfxPath -CertStoreLocation Cert:\CurrentUser\My -Password $securePassword -Exportable
    Write-Host "証明書のインポートが完了しました: $($certificate.Subject)" -ForegroundColor Green
    $certImported = $true
} catch {
    Write-Host "エラー: PFXファイルの読み込みに失敗しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 1: 元のEXEをコピーして署名用ファイルを作成
$signExePath = $ExePath -replace "\.exe$", "-sign.exe"
Write-Host "`nStep 1: 署名用EXEファイルのコピーを作成中..." -ForegroundColor Yellow
Copy-Item $ExePath $signExePath -Force
Write-Host "署名用ファイル: $signExePath" -ForegroundColor Gray

# Step 2: コピーしたファイルに署名を適用
Write-Host "`nStep 2: 署名用ファイルに署名を適用中..." -ForegroundColor Yellow

# signtool.exeの場所を探す
$signtoolPaths = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe",
    "${env:ProgramFiles}\Windows Kits\10\bin\*\x64\signtool.exe"
)

$signtoolExe = $null
foreach ($path in $signtoolPaths) {
    $found = Get-ChildItem $path -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($found) {
        $signtoolExe = $found.FullName
        break
    }
}

if (-not $signtoolExe) {
    Write-Host "エラー: signtool.exe が見つかりません" -ForegroundColor Red
    exit 1
}

Write-Host "signtool パス: $signtoolExe" -ForegroundColor DarkGray

# 署名用ファイルに署名
$arguments = @(
    "sign"
    "/sha1"
    $certificate.Thumbprint
    "/fd"
    "SHA256"
    "/tr"
    "`"$TimestampUrl`""
    "/td"
    "SHA256"
    "/v"
    "`"$signExePath`""
)

Write-Host "実行コマンド: `"$signtoolExe`" $($arguments -join ' ')" -ForegroundColor DarkGray

$process = Start-Process -FilePath $signtoolExe -ArgumentList $arguments -Wait -PassThru -NoNewWindow -RedirectStandardOutput "signtool-output.log" -RedirectStandardError "signtool-error.log"

if ($process.ExitCode -ne 0) {
    $errorOutput = if (Test-Path "signtool-error.log") { Get-Content "signtool-error.log" -Raw } else { "不明なエラー" }
    Write-Host "エラー: 署名に失敗しました (終了コード: $($process.ExitCode))" -ForegroundColor Red
    Write-Host $errorOutput -ForegroundColor Gray
    exit 1
}

Write-Host "署名用ファイルへの署名が完了しました" -ForegroundColor Green

# Step 3: 署名後のファイルサイズを計算
$signedFile = Get-Item $signExePath
$signedSize = $signedFile.Length
$sizeDifference = $signedSize - $originalSize

Write-Host "`nStep 3: ファイルサイズの差分を計算中..." -ForegroundColor Yellow
Write-Host "元のファイルサイズ: $originalSize bytes" -ForegroundColor Gray
Write-Host "署名後ファイルサイズ: $signedSize bytes" -ForegroundColor Gray
Write-Host "署名によるサイズ増加: $sizeDifference bytes" -ForegroundColor Cyan

# Step 4: 元のEXEファイルのZIP End of Central Directoryを検索・編集
Write-Host "`nStep 4: 元のEXEファイルのZIP構造を解析中..." -ForegroundColor Yellow

try {
    # ファイルを読み込み
    [System.IO.Directory]::SetCurrentDirectory($PWD) # .NET のカレントディレクトリを PowerShell の $PWD に同期
    $bytes = [System.IO.File]::ReadAllBytes($ExePath)
    
    # ZIP End of Central Directory signature (0x504B0506) を検索
    $eocdSignature = @(0x50, 0x4B, 0x05, 0x06)
    $eocdPosition = -1
    
    for ($i = $bytes.Length - 22; $i -ge 0; $i--) {
        $match = $true
        for ($j = 0; $j -lt 4; $j++) {
            if ($bytes[$i + $j] -ne $eocdSignature[$j]) {
                $match = $false
                break
            }
        }
        if ($match) {
            $eocdPosition = $i
            break
        }
    }
    
    if ($eocdPosition -eq -1) {
        Write-Host "警告: ZIP End of Central Directory が見つかりませんでした" -ForegroundColor Yellow
        Write-Host "標準的な署名処理にフォールバックします..." -ForegroundColor Yellow
        
        # フォールバック: 標準署名
        $signature = Set-AuthenticodeSignature -FilePath $ExePath -Certificate $certificate
        if ($signature.Status -eq "Valid") {
            Write-Host "標準署名が完了しました" -ForegroundColor Green
        }
    } else {
        Write-Host "ZIP End of Central Directory 発見: offset $eocdPosition" -ForegroundColor Green
        
        # EOCD構造を解析
        # PKZIP EOCD レコード構造（$eocdPosition からの相対オフセット）
        # 00: 50 4B 05 06   ← シグネチャ
        # 04: 2バイト       ← Number of this disk
        # 06: 2バイト       ← Disk where central directory starts
        # 08: 2バイト       ← Number of central directory records on this disk
        # 10: 2バイト       ← Total number of central directory records
        # 12: 4バイト       ← Size of central directory
        # 16: 4バイト       ← Offset of start of central directory
        # 20: 2バイト       ← Comment length ← これを変更する！
        
        $commentLength = [BitConverter]::ToUInt16($bytes, $eocdPosition + 20)
        Write-Host "現在のComment Length: $commentLength" -ForegroundColor Gray
        
        # Step 5: Comment Lengthを署名サイズに設定（推奨手法）
        Write-Host "`nStep 5: ZIP構造のComment Lengthを調整中..." -ForegroundColor Yellow
        
        # 署名サイズが2バイトの最大値（65535）を超えないかチェック
        if ($sizeDifference -gt 65535) {
            Write-Host "警告: 署名サイズ($sizeDifference bytes)が2バイト最大値(65535)を超えています" -ForegroundColor Yellow
            Write-Host "フォールバック処理を実行します..." -ForegroundColor Yellow
            
            # フォールバック: 標準署名
            $signature = Set-AuthenticodeSignature -FilePath $ExePath -Certificate $certificate
            if ($signature.Status -eq "Valid") {
                Write-Host "フォールバック署名が完了しました" -ForegroundColor Green
            }
            return
        }
        
        # Comment Lengthを署名サイズに設定
        $newCommentLength = [uint16]$sizeDifference
        $newCommentLengthBytes = [BitConverter]::GetBytes($newCommentLength)
        
        # Comment Length（オフセット+20）を更新
        $bytes[$eocdPosition + 20] = $newCommentLengthBytes[0]
        $bytes[$eocdPosition + 21] = $newCommentLengthBytes[1]
        
        Write-Host "Comment Length を $commentLength から $newCommentLength に更新" -ForegroundColor Cyan
        Write-Host "これにより署名データ($sizeDifference bytes)をZIPコメント領域として扱います" -ForegroundColor Gray
        
        # 修正されたファイルを保存
        [System.IO.File]::WriteAllBytes($ExePath, $bytes)
        Write-Host "ZIP構造の修正が完了しました" -ForegroundColor Green
        
        # Step 6: 修正されたファイルに最終署名
        Write-Host "`nStep 6: 修正されたファイルに最終署名を適用中..." -ForegroundColor Yellow
        
        $finalArguments = @(
            "sign"
            "/sha1"
            $certificate.Thumbprint
            "/fd"
            "SHA256"
            "/tr"
            "`"$TimestampUrl`""
            "/td"
            "SHA256"
            "/v"
            "`"$ExePath`""
        )
        
        $finalProcess = Start-Process -FilePath $signtoolExe -ArgumentList $finalArguments -Wait -PassThru -NoNewWindow -RedirectStandardOutput "signtool-final-output.log" -RedirectStandardError "signtool-final-error.log"
        
        if ($finalProcess.ExitCode -eq 0) {
            Write-Host "最終署名が正常に完了しました！" -ForegroundColor Green
        } else {
            $finalErrorOutput = if (Test-Path "signtool-final-error.log") { Get-Content "signtool-final-error.log" -Raw } else { "不明なエラー" }
            Write-Host "警告: 最終署名に失敗しました: $finalErrorOutput" -ForegroundColor Yellow
        }
    }
    
} catch {
    Write-Host "エラー: ZIP構造の解析に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 7: 結果の確認
Write-Host "`nStep 7: 最終結果の確認..." -ForegroundColor Yellow

try {
    $finalSignature = Get-AuthenticodeSignature $ExePath
    Write-Host "署名ステータス: $($finalSignature.Status)" -ForegroundColor $(if ($finalSignature.Status -eq "Valid") { "Green" } else { "Yellow" })
    Write-Host "署名者: $($finalSignature.SignerCertificate.Subject)" -ForegroundColor Gray
    
    $finalFile = Get-Item $ExePath
    Write-Host "最終ファイルサイズ: $([math]::Round($finalFile.Length / 1KB, 2)) KB ($($finalFile.Length) bytes)" -ForegroundColor Gray
    
    # EXEの動作テストは手動とし、割愛
    #Write-Host "`n動作テスト実行中..." -ForegroundColor Cyan
    #$testProcess = Start-Process -FilePath $ExePath -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "test-output.log" -RedirectStandardError "test-error.log"
    
    #if ($testProcess.ExitCode -eq 0) {
    #    Write-Host "✓ EXEファイルは正常に動作します" -ForegroundColor Green
    #} else {
    #    Write-Host "⚠ EXEファイルの動作に問題がある可能性があります" -ForegroundColor Yellow
    #    $testError = if (Test-Path "test-error.log") { Get-Content "test-error.log" -Raw } else { "" }
    #    if ($testError.Trim().Length -gt 0) {
    #        Write-Host "テストエラー: $testError" -ForegroundColor Gray
    #    }
    #}
    
} catch {
    Write-Host "警告: 最終確認に失敗しました: $($_.Exception.Message)" -ForegroundColor Yellow
}

# クリーンアップ
Write-Host "`nクリーンアップ中..." -ForegroundColor Gray

# 一時ファイルを削除
@("signtool-output.log", "signtool-error.log", "signtool-final-output.log", "signtool-final-error.log", "test-output.log", "test-error.log") | ForEach-Object {
    if (Test-Path $_) {
        Remove-Item $_ -Force -ErrorAction SilentlyContinue
    }
}

# 署名用ファイルを削除
if (Test-Path $signExePath) {
    Remove-Item $signExePath -Force -ErrorAction SilentlyContinue
    Write-Host "署名用一時ファイルを削除しました: $signExePath" -ForegroundColor Gray
}

# インポートした証明書のクリーンアップ
if ($certImported -and $certificate) {
    try {
        Remove-Item "Cert:\CurrentUser\My\$($certificate.Thumbprint)" -ErrorAction SilentlyContinue
        Write-Host "証明書のクリーンアップが完了しました" -ForegroundColor Gray
    } catch {
        Write-Host "警告: 証明書のクリーンアップに失敗しました" -ForegroundColor Yellow
    }
}

Write-Host "`n高度なコードサイニングが完了しました！" -ForegroundColor Green
Write-Host "詳細を表示する場合は -ShowDetails スイッチを使用してください" -ForegroundColor White

if ($ShowDetails) {
    Write-Host "`n詳細情報:" -ForegroundColor White
    Write-Host "- この手法はLaunch4j EXE内のJAR構造を保護します" -ForegroundColor Gray
    Write-Host "- ZIP End of Central DirectoryのComment Lengthを署名サイズに設定します" -ForegroundColor Gray
    Write-Host "- 署名データをZIPコメント領域として扱い、JAR破損を防ぎます" -ForegroundColor Gray
    Write-Host "- Central Directoryの位置やサイズ情報は変更しません" -ForegroundColor Gray
}
