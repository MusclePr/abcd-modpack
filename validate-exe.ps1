# A-B-C-D Modpack EXE 検証スクリプト
# 署名済みEXEファイルの整合性と実行可能性を詳細にチェックします

param(
    [string]$ExePath = ".\target\abcd-modpack-updater.exe",
    [switch]$Verbose
)

Write-Host "A-B-C-D Modpack EXE 検証ツール" -ForegroundColor Green
Write-Host "==============================="

# EXEファイルの存在確認
if (!(Test-Path $ExePath)) {
    Write-Host "エラー: EXEファイルが見つかりません: $ExePath" -ForegroundColor Red
    exit 1
}

$exeFile = Get-Item $ExePath
Write-Host "`n対象ファイル: $ExePath" -ForegroundColor Cyan
Write-Host "ファイルサイズ: $([math]::Round($exeFile.Length / 1MB, 2)) MB ($($exeFile.Length) bytes)" -ForegroundColor Gray
Write-Host "作成日時: $($exeFile.CreationTime)" -ForegroundColor Gray
Write-Host "更新日時: $($exeFile.LastWriteTime)" -ForegroundColor Gray

$allTestsPassed = $true

# テスト1: ファイル署名の確認
Write-Host "`n[テスト1] デジタル署名の確認..." -ForegroundColor Yellow
try {
    $signature = Get-AuthenticodeSignature $ExePath
    
    switch ($signature.Status) {
        "Valid" {
            Write-Host "✓ 署名ステータス: 有効" -ForegroundColor Green
        }
        "UnknownError" {
            Write-Host "? 署名ステータス: 不明なエラー（通常は自己署名証明書）" -ForegroundColor Yellow
        }
        "NotSigned" {
            Write-Host "✗ 署名ステータス: 署名なし" -ForegroundColor Red
            $allTestsPassed = $false
        }
        default {
            Write-Host "✗ 署名ステータス: $($signature.Status)" -ForegroundColor Red
            $allTestsPassed = $false
        }
    }
    
    if ($signature.SignerCertificate) {
        Write-Host "  署名者: $($signature.SignerCertificate.Subject)" -ForegroundColor Gray
        if ($Verbose) {
            Write-Host "  発行者: $($signature.SignerCertificate.Issuer)" -ForegroundColor DarkGray
            Write-Host "  拇印: $($signature.SignerCertificate.Thumbprint)" -ForegroundColor DarkGray
            Write-Host "  有効期間: $($signature.SignerCertificate.NotBefore) ～ $($signature.SignerCertificate.NotAfter)" -ForegroundColor DarkGray
        }
    }
    
    if ($signature.TimeStamperCertificate) {
        Write-Host "  タイムスタンプ: $($signature.TimeStamperCertificate.Subject)" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "✗ 署名確認エラー: $($_.Exception.Message)" -ForegroundColor Red
    $allTestsPassed = $false
}

# テスト2: PE ファイル形式の確認
Write-Host "`n[テスト2] PE実行ファイル形式の確認..." -ForegroundColor Yellow
try {
    $bytes = [System.IO.File]::ReadAllBytes($ExePath)
    
    # DOSヘッダーの確認 (MZ)
    if ($bytes.Length -gt 2 -and $bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) {
        Write-Host "✓ DOSヘッダー: 正常" -ForegroundColor Green
        
        # PEヘッダーの位置を取得
        if ($bytes.Length -gt 60) {
            $peHeaderOffset = [System.BitConverter]::ToInt32($bytes, 60)
            
            if ($peHeaderOffset -lt $bytes.Length - 4) {
                # PEシグネチャの確認 (PE\0\0)
                if ($bytes[$peHeaderOffset] -eq 0x50 -and $bytes[$peHeaderOffset + 1] -eq 0x45 -and 
                    $bytes[$peHeaderOffset + 2] -eq 0x00 -and $bytes[$peHeaderOffset + 3] -eq 0x00) {
                    Write-Host "✓ PEヘッダー: 正常" -ForegroundColor Green
                } else {
                    Write-Host "✗ PEヘッダー: 無効" -ForegroundColor Red
                    $allTestsPassed = $false
                }
            } else {
                Write-Host "✗ PEヘッダーオフセット: 範囲外" -ForegroundColor Red
                $allTestsPassed = $false
            }
        } else {
            Write-Host "✗ ファイルサイズ: PEヘッダーを読み取るには小さすぎます" -ForegroundColor Red
            $allTestsPassed = $false
        }
    } else {
        Write-Host "✗ DOSヘッダー: 無効" -ForegroundColor Red
        $allTestsPassed = $false
    }
    
} catch {
    Write-Host "✗ ファイル読み取りエラー: $($_.Exception.Message)" -ForegroundColor Red
    $allTestsPassed = $false
}

# テスト3: Launch4j JAR埋め込みの確認
Write-Host "`n[テスト3] Launch4j JAR埋め込みの確認..." -ForegroundColor Yellow
try {
    $jarFound = $false
    $jarOffset = -1
    
    # JARファイル署名（PK\x03\x04）を検索
    for ($i = 0; $i -lt $bytes.Length - 4; $i++) {
        if ($bytes[$i] -eq 0x50 -and $bytes[$i+1] -eq 0x4B -and 
            $bytes[$i+2] -eq 0x03 -and $bytes[$i+3] -eq 0x04) {
            $jarFound = $true
            $jarOffset = $i
            break
        }
    }
    
    if ($jarFound) {
        Write-Host "✓ JAR埋め込み: 検出されました (オフセット: $jarOffset)" -ForegroundColor Green
        
        # JAR内のMANIFESTファイルを確認
        $manifestFound = $false
        $mainClassFound = $false
        
        for ($i = $jarOffset; $i -lt [Math]::Min($bytes.Length - 30, $jarOffset + 2000); $i++) {
            $substring = [System.Text.Encoding]::ASCII.GetString($bytes, $i, [Math]::Min(30, $bytes.Length - $i))
            if ($substring.Contains("META-INF/MANIFEST")) {
                $manifestFound = $true
            }
            if ($substring.Contains("Main-Class:") -or $substring.Contains("com.abcd.modpack")) {
                $mainClassFound = $true
            }
        }
        
        if ($manifestFound) {
            Write-Host "✓ JAR MANIFEST: 検出されました" -ForegroundColor Green
        } else {
            Write-Host "? JAR MANIFEST: 見つかりませんでした（検索範囲制限のため正常な可能性もあります）" -ForegroundColor Yellow
        }
        
        if ($mainClassFound) {
            Write-Host "✓ Main-Class: 検出されました" -ForegroundColor Green
        } else {
            Write-Host "? Main-Class: 見つかりませんでした（実行時エラーの原因の可能性）" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "✗ JAR埋め込み: 検出されませんでした" -ForegroundColor Red
        $allTestsPassed = $false
    }
    
} catch {
    Write-Host "✗ JAR検索エラー: $($_.Exception.Message)" -ForegroundColor Red
    $allTestsPassed = $false
}

# テスト4: ファイルアクセステスト
Write-Host "`n[テスト4] ファイルアクセステスト..." -ForegroundColor Yellow
try {
    $fileStream = [System.IO.File]::OpenRead($ExePath)
    $buffer = New-Object byte[] 1024
    $bytesRead = $fileStream.Read($buffer, 0, 1024)
    $fileStream.Close()
    
    if ($bytesRead -gt 0) {
        Write-Host "✓ ファイル読み取り: 正常 ($bytesRead bytes 読み取り)" -ForegroundColor Green
    } else {
        Write-Host "✗ ファイル読み取り: データが読み取れませんでした" -ForegroundColor Red
        $allTestsPassed = $false
    }
    
} catch {
    Write-Host "✗ ファイルアクセスエラー: $($_.Exception.Message)" -ForegroundColor Red
    $allTestsPassed = $false
}

# テスト4.5: Java環境の確認
Write-Host "`n[テスト4.5] Java環境の確認..." -ForegroundColor Yellow
try {
    # 一般的なJavaパスをチェック
    $javaLocations = @(
        "${env:JAVA_HOME}\bin\java.exe",
        "${env:LOCALAPPDATA}\Packages\Microsoft.4297127D64EC6_8wekyb3d8bbwe\LocalCache\Local\runtime\java-runtime-delta\windows-x64\java-runtime-delta\bin\java.exe",
        "java.exe"  # PATHから検索
    )
    
    $javaFound = $false
    $javaVersion = ""
    
    foreach ($javaPath in $javaLocations) {
        if ($javaPath -eq "java.exe") {
            # PATHから検索
            try {
                $result = & java -version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $javaFound = $true
                    $javaVersion = ($result | Select-Object -First 1).ToString()
                    Write-Host "✓ Java (PATH): $javaVersion" -ForegroundColor Green
                    break
                }
            } catch {
                continue
            }
        } elseif (Test-Path $javaPath) {
            try {
                $result = & $javaPath -version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $javaFound = $true
                    $javaVersion = ($result | Select-Object -First 1).ToString()
                    Write-Host "✓ Java ($javaPath): $javaVersion" -ForegroundColor Green
                    break
                }
            } catch {
                continue
            }
        }
    }
    
    if (!$javaFound) {
        Write-Host "✗ Java: 実行可能なJavaランタイムが見つかりません" -ForegroundColor Red
        Write-Host "  Launch4j EXEはJava 17以上が必要です" -ForegroundColor Yellow
        Write-Host "  インストール先: https://adoptium.net/temurin/releases/" -ForegroundColor Gray
        $allTestsPassed = $false
    } else {
        # Javaバージョンチェック（簡易）
        if ($javaVersion -match "(\d+)\.") {
            $majorVersion = [int]$matches[1]
            if ($majorVersion -ge 17) {
                Write-Host "✓ Java バージョン: Launch4j要件を満たしています (Java $majorVersion)" -ForegroundColor Green
            } else {
                Write-Host "✗ Java バージョン: 古すぎます (Java $majorVersion は 17未満)" -ForegroundColor Red
                $allTestsPassed = $false
            }
        } elseif ($javaVersion -match '"(\d+)') {
            $majorVersion = [int]$matches[1]
            if ($majorVersion -ge 17) {
                Write-Host "✓ Java バージョン: Launch4j要件を満たしています (Java $majorVersion)" -ForegroundColor Green
            } else {
                Write-Host "✗ Java バージョン: 古すぎます (Java $majorVersion は 17未満)" -ForegroundColor Red
                $allTestsPassed = $false
            }
        } else {
            Write-Host "? Java バージョン: 解析できませんでした - $javaVersion" -ForegroundColor Yellow
        }
    }
    
} catch {
    Write-Host "✗ Java環境確認エラー: $($_.Exception.Message)" -ForegroundColor Red
    $allTestsPassed = $false
}

# テスト5: 実行テスト（オプション）
Write-Host "`n[テスト5] 実行可能性テスト..." -ForegroundColor Yellow
$runTest = Read-Host "実際にEXEファイルを起動してテストしますか？ (y/N)"
if ($runTest -eq "y" -or $runTest -eq "Y") {
    try {
        Write-Host "EXEファイルをテスト実行中..." -ForegroundColor Cyan
        
        # プロセスを開始して標準出力とエラー出力をキャプチャ
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $ExePath
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $false
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        
        # 出力データを受信するためのイベントハンドラ
        $outputBuilder = New-Object System.Text.StringBuilder
        $errorBuilder = New-Object System.Text.StringBuilder
        
        $outputHandler = {
            if ($EventArgs.Data -ne $null) {
                $outputBuilder.AppendLine($EventArgs.Data)
            }
        }
        
        $errorHandler = {
            if ($EventArgs.Data -ne $null) {
                $errorBuilder.AppendLine($EventArgs.Data)
            }
        }
        
        Register-ObjectEvent -InputObject $process -EventName "OutputDataReceived" -Action $outputHandler | Out-Null
        Register-ObjectEvent -InputObject $process -EventName "ErrorDataReceived" -Action $errorHandler | Out-Null
        
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        
        # プロセスの実行を短時間監視
        $timeoutSeconds = 5
        $process.WaitForExit($timeoutSeconds * 1000)
        
        # イベント登録を解除
        Get-EventSubscriber | Where-Object { $_.SourceObject -eq $process } | Unregister-Event
        
        if ($process.HasExited) {
            $exitCode = $process.ExitCode
            Write-Host "プロセス終了コード: $exitCode" -ForegroundColor Gray
            
            # 標準出力とエラー出力を表示
            $stdout = $outputBuilder.ToString().Trim()
            $stderr = $errorBuilder.ToString().Trim()
            
            if ($stdout.Length -gt 0) {
                Write-Host "標準出力:" -ForegroundColor Cyan
                Write-Host $stdout -ForegroundColor Gray
            }
            
            if ($stderr.Length -gt 0) {
                Write-Host "エラー出力:" -ForegroundColor Yellow
                Write-Host $stderr -ForegroundColor Gray
            }
            
            if ($exitCode -eq 0 -and ($stdout.Length -gt 0 -or $stderr.Length -gt 0)) {
                Write-Host "✓ 実行テスト: 正常終了（出力あり）" -ForegroundColor Green
            } elseif ($exitCode -eq 0) {
                Write-Host "? 実行テスト: 正常終了（出力なし - 想定外の早期終了の可能性）" -ForegroundColor Yellow
                Write-Host "  原因の可能性:" -ForegroundColor Yellow
                Write-Host "  - Javaランタイムが見つからない" -ForegroundColor Gray
                Write-Host "  - JAR内のMainクラスに問題がある" -ForegroundColor Gray
                Write-Host "  - 依存関係の問題" -ForegroundColor Gray
                $allTestsPassed = $false
            } else {
                Write-Host "✗ 実行テスト: 異常終了 (終了コード: $exitCode)" -ForegroundColor Red
                $allTestsPassed = $false
            }
        } else {
            Write-Host "✓ 実行テスト: プロセスが正常に開始されました (PID: $($process.Id))" -ForegroundColor Green
            
            $killProcess = Read-Host "テストプロセスを終了しますか？ (Y/n)"
            if ($killProcess -ne "n" -and $killProcess -ne "N") {
                try {
                    $process.Kill()
                    $process.WaitForExit(5000)
                    Write-Host "テストプロセスを終了しました。" -ForegroundColor Gray
                } catch {
                    Write-Host "プロセス終了に失敗しました: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
        
        $process.Dispose()
        
    } catch {
        Write-Host "✗ 実行テストエラー: $($_.Exception.Message)" -ForegroundColor Red
        $allTestsPassed = $false
    }
} else {
    Write-Host "実行テストをスキップしました。" -ForegroundColor Gray
}

# 結果サマリー
Write-Host "`n検証結果サマリー" -ForegroundColor White
Write-Host "================"

if ($allTestsPassed) {
    Write-Host "✓ 全てのテストに合格しました！EXEファイルは正常です。" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ 一部のテストに失敗しました。EXEファイルに問題がある可能性があります。" -ForegroundColor Red
    
    Write-Host "`n推奨対処法:" -ForegroundColor Yellow
    Write-Host "1. Java環境の確認と修正" -ForegroundColor White
    Write-Host "   - Java 17以上がインストールされているか確認" -ForegroundColor Gray
    Write-Host "   - https://adoptium.net/temurin/releases/ からダウンロード" -ForegroundColor Gray
    Write-Host "2. ビルドプロセスを最初からやり直す" -ForegroundColor White
    Write-Host "   - .\dev-build.ps1 -CleanAll" -ForegroundColor Gray
    Write-Host "   - .\dev-build.ps1" -ForegroundColor Gray
    Write-Host "3. 署名前のEXEファイルで同じテストを実行" -ForegroundColor White
    Write-Host "   - .\dev-build.ps1 -BuildOnly" -ForegroundColor Gray
    Write-Host "   - .\validate-exe.ps1" -ForegroundColor Gray
    Write-Host "4. JAR単体での実行テスト" -ForegroundColor White
    Write-Host "   - java -jar .\target\abcd-modpack-1.0.jar" -ForegroundColor Gray
    Write-Host "5. launch4j-config.xml の設定を確認" -ForegroundColor White
    Write-Host "6. 署名プロセスでファイルが破損していないか確認" -ForegroundColor White
    
    exit 1
}

# テスト4: ファイルハンドルテスト
Write-Host "`n[テスト4] ファイルアクセステスト..." -ForegroundColor Yellow
try {
    $fileStream = [System.IO.File]::OpenRead($ExePath)
    $buffer = New-Object byte[] 1024
    $bytesRead = $fileStream.Read($buffer, 0, 1024)
    $fileStream.Close()
    
    if ($bytesRead -gt 0) {
        Write-Host "✓ ファイル読み取り: 正常 ($bytesRead bytes 読み取り)" -ForegroundColor Green
    } else {
        Write-Host "✗ ファイル読み取り: データが読み取れませんでした" -ForegroundColor Red
        $allTestsPassed = $false
    }
    
} catch {
    Write-Host "✗ ファイルアクセスエラー: $($_.Exception.Message)" -ForegroundColor Red
    $allTestsPassed = $false
}

# テスト5: 実行テスト（オプション）
Write-Host "`n[テスト5] 実行可能性テスト..." -ForegroundColor Yellow
$runTest = Read-Host "実際にEXEファイルを起動してテストしますか？ (y/N)"
if ($runTest -eq "y" -or $runTest -eq "Y") {
    try {
        Write-Host "EXEファイルをテスト実行中..." -ForegroundColor Cyan
        
        # プロセスを開始して標準出力とエラー出力をキャプチャ
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $ExePath
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $false
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        
        # 出力データを受信するためのイベントハンドラ
        $outputBuilder = New-Object System.Text.StringBuilder
        $errorBuilder = New-Object System.Text.StringBuilder
        
        $outputHandler = {
            if ($EventArgs.Data -ne $null) {
                $outputBuilder.AppendLine($EventArgs.Data)
            }
        }
        
        $errorHandler = {
            if ($EventArgs.Data -ne $null) {
                $errorBuilder.AppendLine($EventArgs.Data)
            }
        }
        
        Register-ObjectEvent -InputObject $process -EventName "OutputDataReceived" -Action $outputHandler | Out-Null
        Register-ObjectEvent -InputObject $process -EventName "ErrorDataReceived" -Action $errorHandler | Out-Null
        
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        
        # プロセスの実行を短時間監視
        $timeoutSeconds = 5
        $process.WaitForExit($timeoutSeconds * 1000)
        
        # イベント登録を解除
        Get-EventSubscriber | Where-Object { $_.SourceObject -eq $process } | Unregister-Event
        
        if ($process.HasExited) {
            $exitCode = $process.ExitCode
            Write-Host "プロセス終了コード: $exitCode" -ForegroundColor Gray
            
            # 標準出力とエラー出力を表示
            $stdout = $outputBuilder.ToString().Trim()
            $stderr = $errorBuilder.ToString().Trim()
            
            if ($stdout.Length -gt 0) {
                Write-Host "標準出力:" -ForegroundColor Cyan
                Write-Host $stdout -ForegroundColor Gray
            }
            
            if ($stderr.Length -gt 0) {
                Write-Host "エラー出力:" -ForegroundColor Yellow
                Write-Host $stderr -ForegroundColor Gray
            }
            
            if ($exitCode -eq 0 -and ($stdout.Length -gt 0 -or $stderr.Length -gt 0)) {
                Write-Host "✓ 実行テスト: 正常終了（出力あり）" -ForegroundColor Green
            } elseif ($exitCode -eq 0) {
                Write-Host "? 実行テスト: 正常終了（出力なし - 想定外の早期終了の可能性）" -ForegroundColor Yellow
                Write-Host "  原因の可能性:" -ForegroundColor Yellow
                Write-Host "  - Javaランタイムが見つからない" -ForegroundColor Gray
                Write-Host "  - JAR内のMainクラスに問題がある" -ForegroundColor Gray
                Write-Host "  - 依存関係の問題" -ForegroundColor Gray
                $allTestsPassed = $false
            } else {
                Write-Host "✗ 実行テスト: 異常終了 (終了コード: $exitCode)" -ForegroundColor Red
                $allTestsPassed = $false
            }
        } else {
            Write-Host "✓ 実行テスト: プロセスが正常に開始されました (PID: $($process.Id))" -ForegroundColor Green
            
            $killProcess = Read-Host "テストプロセスを終了しますか？ (Y/n)"
            if ($killProcess -ne "n" -and $killProcess -ne "N") {
                try {
                    $process.Kill()
                    $process.WaitForExit(5000)
                    Write-Host "テストプロセスを終了しました。" -ForegroundColor Gray
                } catch {
                    Write-Host "プロセス終了に失敗しました: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
        
        $process.Dispose()
        
    } catch {
        Write-Host "✗ 実行テストエラー: $($_.Exception.Message)" -ForegroundColor Red
        $allTestsPassed = $false
    }
} else {
    Write-Host "実行テストをスキップしました。" -ForegroundColor Gray
}

# 結果サマリー
Write-Host "`n検証結果サマリー" -ForegroundColor White
Write-Host "================"

if ($allTestsPassed) {
    Write-Host "✓ 全てのテストに合格しました！EXEファイルは正常です。" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ 一部のテストに失敗しました。EXEファイルに問題がある可能性があります。" -ForegroundColor Red
    
    Write-Host "`n推奨対処法:" -ForegroundColor Yellow
    Write-Host "1. Java環境の確認と修正" -ForegroundColor White
    Write-Host "   - Java 17以上がインストールされているか確認" -ForegroundColor Gray
    Write-Host "   - https://adoptium.net/temurin/releases/ からダウンロード" -ForegroundColor Gray
    Write-Host "2. ビルドプロセスを最初からやり直す" -ForegroundColor White
    Write-Host "   - .\dev-build.ps1 -CleanAll" -ForegroundColor Gray
    Write-Host "   - .\dev-build.ps1" -ForegroundColor Gray
    Write-Host "3. 署名前のEXEファイルで同じテストを実行" -ForegroundColor White
    Write-Host "   - .\dev-build.ps1 -BuildOnly" -ForegroundColor Gray
    Write-Host "   - .\validate-exe.ps1" -ForegroundColor Gray
    Write-Host "4. JAR単体での実行テスト" -ForegroundColor White
    Write-Host "   - java -jar .\target\abcd-modpack-1.0.jar" -ForegroundColor Gray
    Write-Host "5. launch4j-config.xml の設定を確認" -ForegroundColor White
    Write-Host "6. 署名プロセスでファイルが破損していないか確認" -ForegroundColor White
    
    exit 1
}
