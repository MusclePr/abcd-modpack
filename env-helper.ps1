# 環境変数読み込み用ヘルパー関数
# .envファイルから環境変数を読み込みます

function Load-EnvFile {
    param(
        [string]$EnvFilePath = ".\.env"
    )
    
    if (!(Test-Path $EnvFilePath)) {
        Write-Host "警告: .envファイルが見つかりません: $EnvFilePath" -ForegroundColor Yellow
        return $null
    }
    
    $envVars = @{}
    
    try {
        $content = Get-Content $EnvFilePath -ErrorAction Stop
        foreach ($line in $content) {
            # 空行やコメント行をスキップ
            if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
                continue
            }
            
            # KEY="VALUE" または KEY=VALUE の形式を解析
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                # クォートを除去（"" または ''）
                if (($value.StartsWith('"') -and $value.EndsWith('"')) -or 
                    ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
                
                $envVars[$key] = $value
            }
        }
        
        Write-Host ".envファイルを読み込みました: $EnvFilePath" -ForegroundColor Green
        return $envVars
        
    } catch {
        Write-Host "エラー: .envファイルの読み込みに失敗しました: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-EnvPassword {
    param(
        [string]$EnvFilePath = ".\.env",
        [string]$DefaultPassword = "TestPassword123!"
    )
    
    $envVars = Load-EnvFile -EnvFilePath $EnvFilePath
    
    if ($envVars -and $envVars.ContainsKey("PASSWORD")) {
        return $envVars["PASSWORD"]
    } else {
        Write-Host "警告: .envファイルからPASSWORDが読み込めませんでした。デフォルトパスワードを使用します。" -ForegroundColor Yellow
        return $DefaultPassword
    }
}

# PowerShellスクリプトファイル（.ps1）では Export-ModuleMember は不要
# 関数は自動的に利用可能になります