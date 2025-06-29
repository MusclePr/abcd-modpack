if (Get-Process -Name "Minecraft" -ErrorAction SilentlyContinue) {
  Write-Output "Minecraft のランチャーを終了してください。"
  pause
}

# ダウンロードするため、カレントディレクトリの移動
$gameDir = "$env:APPDATA\.minecraft_abcd"
if (-Not (Test-Path $gameDir)) {
  New-Item -ItemType Directory -Path $gameDir -Force | Out-Null
}
Set-Location $gameDir

$response = Invoke-WebRequest -Uri "https://a-b-c-d.com/downloads/abcd-mods-latest.txt"
if ($? -eq $false) {
  Write-Output "A-B-C-D.COM から最新バージョンの取得に失敗しました。"
  pause
  exit
}

$text = $response.Content -split "`r?`n"
# １行目：マイクラバージョン
$ver = $text[0].Trim()
# ２行目：アップデーターバージョン
$updaterVersion = $text[1].Trim()
Write-Output "Minecraft version：$ver"
Write-Output "Updater latest version：$updaterVersion"

# Java ランタイムのパス
$java = "${env:LOCALAPPDATA}/Packages/Microsoft.4297127D64EC6_8wekyb3d8bbwe/LocalCache/Local/runtime/java-runtime-delta/windows-x64/java-runtime-delta/bin/java.exe"
if (-Not (Test-Path "${java}")) {
  if ($env:JAVA_HOME) {
    $javaAlt = Join-Path $env:JAVA_HOME "bin\java.exe"
    if (Test-Path $javaAlt) {
      Write-Host "⚠ 指定のJavaが見つからなかったため、JAVA_HOMEのJavaを使用します："
      $java = $javaAlt
    } else {
      Write-Error "JAVA_HOME は設定されていますが、その中の java.exe が見つかりません: $javaAlt"
      pause
      exit 1
    }
  } else {
    Write-Error "Java 実行ファイルが見つからず、JAVA_HOME も未設定です。"
    pause
    exit 1
  }
}

# 最新の fabric バージョン番号を取得
$base = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/"
$html = Invoke-WebRequest $base
if ($? -eq $false) {
  Write-Output "fabric の最新バージョンの診断に失敗しました。"
  pause
  exit
}
$versions = $html.Links | Where-Object { $_.href -match "^[0-9]+\.[0-9]+\." } | ForEach-Object { $_.href.TrimEnd('/') }
$latest = ($versions | Sort-Object { [Version]$_ } -Descending)[0]

# 最新版の fabric-installer-*.jar のダウンロード
$exeUrl = "$base$latest/fabric-installer-$latest.jar"
$dest = "fabric-installer-$latest.jar"
Invoke-WebRequest -Uri $exeUrl -OutFile $dest
if ($? -eq $false) {
  Write-Output "最新の fabric-installer の取得に失敗しました。"
  pause
  exit
}

# Java ランタイムのパス
$java = "${env:LOCALAPPDATA}\Packages\Microsoft.4297127D64EC6_8wekyb3d8bbwe\LocalCache\Local\runtime\java-runtime-delta\windows-x64\java-runtime-delta\bin\java.exe"
$loadver = ""
$output = & "${java}" -jar "${dest}" client -mcversion "${ver}"
$output | ForEach-Object {
  if ($_ -match " with fabric ([0-9\.]+)") {
    $script:loadver = $matches[1]
  }
}

if ($loadver -match "([0-9\.]+)") {
  Write-Host "Loader Version：$loadver"
} else {
  Write-Error "ローダーバージョンの取得に失敗しました。"
  Write-Host $output
  pause
  exit 1
}

# 準備：パスやバージョン番号などを変数で指定
$profilePath = "$env:APPDATA\.minecraft\launcher_profiles.json"
$profileId = "A-B-C-D"
$created = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
Write-Output "📁 ゲームディレクトリ: $gameDir"

# JSON ファイルを読み込み
$json = Get-Content $profilePath -Raw | ConvertFrom-Json

# profiles プロパティが存在するかチェック
if (-not $json.PSObject.Properties.Name -contains "profiles") {
  $json | Add-Member -MemberType NoteProperty -Name "profiles" -Value @{}
}

# profiles をハッシュテーブル化（←インデクサアクセス用）
$profiles = @{}
foreach ($k in $json.profiles.PSObject.Properties.Name) {
  # fabric-installer がインストールしたプロファイルは除く
  if ($k -eq "fabric-loader-$ver") { continue }
  $profiles[$k] = $json.profiles.$k
}

# 新しいプロファイル構成
$profiles[$profileId] = @{
    created         = $created
    gameDir         = $gameDir
    icon            = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAACABAMAAAAxEHz4AAAAGFBMVEUAAAA4NCrb0LTGvKW8spyAem2uppSakn5SsnMLAAAAAXRSTlMAQObYZgAAAJ5JREFUaIHt1MENgCAMRmFWYAVXcAVXcAVXcH3bhCYNkYjcKO8dSf7v1JASUWdZAlgb0PEmDSMAYYBdGkYApgf8ER3SbwRgesAf0BACMD1gB6S9IbkEEBfwY49oNj4lgLhA64C0o9R9RABTAvp4SX5kB2TA5y8EEAK4pRrxB9QcA4QBWkj3GCAMUCO/xwBhAI/kEsCagCHDY4AwAC3VA6t4zTAMj0OJAAAAAElFTkSuQmCC"
    javaArgs        = "-Xmx4G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M"
    lastUsed        = "1970-01-01T00:00:00.000Z"
    lastVersionId   = "fabric-loader-$loadver-$ver"
    name            = "A-B-C-D $ver"
    type            = "custom"
}
$json.profiles = $profiles

# ランチャーのプロファイル構成を書き換え
$utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($profilePath, ($json | ConvertTo-Json -Depth 10), $utf8NoBOM)

#
# パッケージをダウンロード更新
#

$packs = "abcd-update-packs-${ver}.txt"
Remove-Item ${packs} -ErrorAction Ignore
Write-Output "Download ... ${packs}"
Invoke-WebRequest -ErrorAction Stop -Uri https://a-b-c-d.com/downloads/${packs} -OutFile .\${packs}
if ($? -eq $false) {
  Write-Output "ModPack のダウンロードに失敗しました。"
  pause
  exit
}
(Get-Content -Path .\${packs}) | ForEach-Object{
  $op = $_.Substring(0,1)
  $value = $_.Substring(1)
  switch ($op)
  {
    '-' {
      Write-Host "Remove-Item ${value}"
      Remove-Item -ErrorAction Ignore ${value}
    }
    '+' {
      $ext = [System.IO.Path]::GetExtension($value);
      Write-Host "Invoke-WebRequest -Uri https://a-b-c-d.com/downloads/${value} -OutFile .\${value}"
      Invoke-WebRequest -Uri https://a-b-c-d.com/downloads/${value} -OutFile .\${value}
      if ($ext -eq ".zip") {
        Write-Host "Expand-Archive -Path .\${value} -DestinationPath .\ -Force"
        Expand-Archive -Path .\${value} -DestinationPath .\ -Force
        Remove-Item .\${value}
      }
    }
  }
}
#Remove-Item .\${packs}
Write-Output "正常に完了しました。マインクラフトのランチャーを起動して、起動構成「A-B-C-D $ver」から起動してください。"
pause
