# テスト用自己認証局とコードサイニング証明書の作成スクリプト
# このスクリプトは開発・テスト目的のみで使用してください

param(
    [string]$CertificateSubject = "CN=ABCD Development CA",
    [string]$CodeSignSubject = "CN=ABCD Modpack Developer",
    [int]$ValidityDays = 365,
    [string]$CertPassword = "",
    [string]$OutputDir = ".\certificates",
    [switch]$Force
)

# .envファイルからパスワードを読み込み
. .\env-helper.ps1
if ([string]::IsNullOrEmpty($CertPassword)) {
    $CertPassword = Get-EnvPassword
}

Write-Host "A-B-C-D Modpack テスト用証明書作成ツール" -ForegroundColor Green
Write-Host "=============================================="
Write-Host "警告: このスクリプトは開発・テスト目的のみで使用してください" -ForegroundColor Yellow
Write-Host "本番環境では適切な商用証明書を使用してください`n" -ForegroundColor Yellow

# 出力ディレクトリの作成
if (!(Test-Path $OutputDir)) {
    Write-Host "証明書出力ディレクトリを作成: $OutputDir" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$caKeyPath = Join-Path $OutputDir "ca-private-key.pem"
$caCertPath = Join-Path $OutputDir "ca-certificate.pem"
$csrPath = Join-Path $OutputDir "code-signing.csr"
$codeKeyPath = Join-Path $OutputDir "code-signing-private-key.pem"
$codeCertPath = Join-Path $OutputDir "code-signing-certificate.pem"
$pfxPath = Join-Path $OutputDir "code-signing-certificate.pfx"

# 既存ファイルのチェック
if ((Test-Path $pfxPath) -and !$Force) {
    Write-Host "証明書ファイルが既に存在します: $pfxPath" -ForegroundColor Yellow
    $overwrite = Read-Host "上書きしますか？ (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "処理をキャンセルしました。" -ForegroundColor Yellow
        exit 0
    }
}

# OpenSSLの存在確認とバージョンチェック
$opensslPath = $null
$possiblePaths = @(
    "openssl",
    "C:\Program Files\OpenSSL-Win64\bin\openssl.exe",
    "C:\Program Files (x86)\OpenSSL-Win32\bin\openssl.exe",
    "C:\OpenSSL-Win64\bin\openssl.exe",
    "C:\Program Files\Git\usr\bin\openssl.exe",
    "C:\Program Files (x86)\Git\usr\bin\openssl.exe",
    "C:\msys64\usr\bin\openssl.exe",
    "C:\tools\msys64\usr\bin\openssl.exe"
)

foreach ($path in $possiblePaths) {
    try {
        $versionOutput = & $path version 2>$null
        if ($LASTEXITCODE -eq 0) {
            $opensslPath = $path
            Write-Host "OpenSSL が見つかりました: $opensslPath" -ForegroundColor Green
            Write-Host "バージョン: $versionOutput" -ForegroundColor Gray
            break
        }
    } catch {
        # パスが見つからない場合は無視
    }
}

if (!$opensslPath) {
    Write-Host "エラー: OpenSSL が見つかりません。" -ForegroundColor Red
    Write-Host "以下の方法でOpenSSLをインストールしてください:" -ForegroundColor Yellow
    Write-Host "1. Chocolatey: choco install openssl" -ForegroundColor White
    Write-Host "2. 公式サイト: https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor White
    Write-Host "3. MSYS2: pacman -S openssl" -ForegroundColor White
    Write-Host "4. Git for Windows に含まれるOpenSSL: C:\Program Files\Git\usr\bin\openssl.exe" -ForegroundColor White
    Read-Host "続行するには何かキーを押してください"
    exit 1
}

# OpenSSLの設定ファイル警告を抑制（OpenSSL 3.x対応）
$env:OPENSSL_CONF = ""

try {
    Write-Host "`nステップ1: CA（認証局）の秘密鍵を作成..." -ForegroundColor Cyan
    # OpenSSL 3.x系の正しい構文（RSA 2048ビット、AES256暗号化）
    & $opensslPath genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out $caKeyPath -aes256 -pass "pass:$CertPassword"
    if ($LASTEXITCODE -ne 0) { throw "CA秘密鍵の作成に失敗しました" }

    Write-Host "ステップ2: CA証明書を作成..." -ForegroundColor Cyan
    # OpenSSL 3.x系での証明書作成
    & $opensslPath req -new -x509 -key $caKeyPath -sha256 -days $ValidityDays -out $caCertPath -passin "pass:$CertPassword" -subj "/CN=ABCD Development CA"
    if ($LASTEXITCODE -ne 0) { throw "CA証明書の作成に失敗しました" }

    Write-Host "ステップ3: コードサイニング用の秘密鍵を作成..." -ForegroundColor Cyan
    # コードサイニング用の秘密鍵（暗号化なし）
    & $opensslPath genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out $codeKeyPath
    if ($LASTEXITCODE -ne 0) { throw "コードサイニング秘密鍵の作成に失敗しました" }

    Write-Host "ステップ4: コードサイニング証明書署名要求（CSR）を作成..." -ForegroundColor Cyan
    # OpenSSL 3.x系対応の設定ファイル
    $configContent = @"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = A-B-C-D Developer

[v3_req]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
"@
    $configPath = Join-Path $OutputDir "code-signing.conf"
    $configContent | Out-File -FilePath $configPath -Encoding UTF8

    & $opensslPath req -new -key $codeKeyPath -out $csrPath -config $configPath
    if ($LASTEXITCODE -ne 0) { throw "CSRの作成に失敗しました" }

    Write-Host "ステップ5: CA証明書でコードサイニング証明書に署名..." -ForegroundColor Cyan
    # OpenSSL 3.x系の証明書署名
    & $opensslPath x509 -req -in $csrPath -CA $caCertPath -CAkey $caKeyPath -CAcreateserial -out $codeCertPath -days $ValidityDays -sha256 -extensions v3_req -extfile $configPath -passin "pass:$CertPassword"
    if ($LASTEXITCODE -ne 0) { throw "証明書への署名に失敗しました" }

    Write-Host "ステップ6: PKCS#12 (.pfx) ファイルを作成..." -ForegroundColor Cyan
    # OpenSSL 3.x系で推奨される現代的なアルゴリズムを使用
    & $opensslPath pkcs12 -export -out $pfxPath -inkey $codeKeyPath -in $codeCertPath -certfile $caCertPath -passout "pass:$CertPassword" -name "ABCD Code Signing Certificate" -keypbe AES-256-CBC -certpbe AES-256-CBC -macalg SHA256
    if ($LASTEXITCODE -ne 0) {
        Write-Host "現代的なアルゴリズムでの作成に失敗しました。互換性モードで再試行します..." -ForegroundColor Yellow
        # フォールバック: より互換性のあるオプション
        & $opensslPath pkcs12 -export -out $pfxPath -inkey $codeKeyPath -in $codeCertPath -certfile $caCertPath -passout "pass:$CertPassword" -name "ABCD Code Signing Certificate"
        if ($LASTEXITCODE -ne 0) { throw "PFXファイルの作成に失敗しました" }
    }

    Write-Host "`n証明書の作成が完了しました！" -ForegroundColor Green
    Write-Host "出力ファイル:" -ForegroundColor White
    Write-Host "- CA証明書: $caCertPath" -ForegroundColor Gray
    Write-Host "- コードサイニング証明書 (PFX): $pfxPath" -ForegroundColor Gray
    Write-Host "- 証明書パスワード: $CertPassword" -ForegroundColor Gray

    # 証明書情報の表示
    Write-Host "`n証明書の詳細:" -ForegroundColor White
    & $opensslPath x509 -in $codeCertPath -text -noout | Select-String "Subject:", "Not Before", "Not After", "Public Key Algorithm"

    Write-Host "`n次のステップ:" -ForegroundColor White
    Write-Host "1. CA証明書をルート証明書ストアにインストール（オプション）:"
    Write-Host "   certlm.msc を開いて 'Trusted Root Certification Authorities' に $caCertPath をインポート" -ForegroundColor Cyan
    Write-Host "2. EXEファイルに署名:"
    Write-Host "   .\sign-exe.ps1 -PfxPath `"$pfxPath`" -Password `"$CertPassword`"" -ForegroundColor Cyan

    # 一時ファイルのクリーンアップ
    Remove-Item $csrPath -ErrorAction SilentlyContinue
    Remove-Item $configPath -ErrorAction SilentlyContinue

} catch {
    Write-Host "`nエラー: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "証明書の作成に失敗しました。" -ForegroundColor Red
    Read-Host "続行するには何かキーを押してください"
    exit 1
}

Write-Host "`n証明書作成スクリプトが正常に完了しました！" -ForegroundColor Green
Read-Host "続行するには何かキーを押してください"
