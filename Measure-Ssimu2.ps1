<#
.SYNOPSIS
  SSIMULACRA2 (FFVship) 自動計測スクリプト

.DESCRIPTION
  指定された「評価対象動画」と「リファレンス動画」を比較し、
  FFVship (SSIMULACRA2) を実行してスコアを算出・返却します。
#>

[CmdletBinding()]
param(
  # 評価対象動画のパス (必須)
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$DistortedFilePath,

  # リファレンス動画のパス (必須)
  [Parameter(Mandatory = $true, Position = 1)]
  [string]$ReferenceFilePath,

  # 生のJSONデータを保存する場合のパス
  [string]$RawJsonFilePath = "",

  # クリップ済みJSONデータを保存する場合のパス
  [string]$ClippedJsonFilePath = ""
)

# PowerShellの実行時エラーで「停止」して、適切に Catch 節へ飛ばす設定
$ErrorActionPreference = "Stop"
$NewLine = [Environment]::NewLine

# =========================================================
# クラス定義
# =========================================================

# SSIMULACRA2 の統計データを保持するクラス
class Ssimu2Metrics {
  [string]$Average = "N/A"
  [string]$StandardDeviation = ""
  [string]$Median = ""
  [string]$Percentile5 = ""
  [string]$Percentile95 = ""
  [string]$Minimum = ""
  [string]$Maximum = ""
  [Ssimu2Metrics]$Clipped
}

# =========================================================
# 関数
# =========================================================

<#
.SYNOPSIS
  SSIMULACRA2計測のメイン処理を実行します。
  FFVship.exe はパスに含まれる日本語（マルチバイト文字）によって引数の解析に失敗することがあります。
  これを防ぐため、ファイルを一時フォルダにコピーした上で、コピー先のパスを
  ASCII文字のみで構成されるショートパスに変換して FFVship.exe に渡します。
#>
function Invoke-Ssimu2Measurement {
  [CmdletBinding()]
  param (
    [string]$FfvshipFilePath,
    [string]$DistortedFilePath,
    [string]$ReferenceFilePath,
    [string]$RawJsonFilePath,
    [string]$ClippedJsonFilePath
  )

  if ([string]::IsNullOrEmpty($FfvshipFilePath) -or -not (Test-Path -LiteralPath $FfvshipFilePath)) {
    Write-Warning "FFVship.exe not found in PATH."
    return [Ssimu2Metrics]::new()
  }

  # 一時ファイルパスの設定 (JSON出力用は常に必要)
  $TempJsonFilePath = [System.IO.Path]::GetTempFileName()
  $CleanupPaths = @($TempJsonFilePath)
  
  $ResultStats = [Ssimu2Metrics]::new()

  try {
    $TempContext = New-Ssimu2TempContext `
      -ReferenceFilePath $ReferenceFilePath `
      -DistortedFilePath $DistortedFilePath
    
    $CleanupPaths += $TempContext.CleanupPaths
    $ExecReferencePath = $TempContext.ExecReferencePath
    $ExecDistortedPath = $TempContext.ExecDistortedPath

    # コマンド引数の構築
    $FfvshipArguments = "--source `"$ExecReferencePath`" --encoded `"$ExecDistortedPath`" -m SSIMULACRA2 --json `"$TempJsonFilePath`""

    Write-Host "${NewLine}[FFVship Command]" -ForegroundColor DarkGray
    Write-Host "`"$FfvshipFilePath`" $FfvshipArguments`r`n" -ForegroundColor DarkGray

    # 外部プロセスの起動。Start-Process は完了待機や終了コード取得が可能
    $Process = Start-Process -FilePath $FfvshipFilePath -ArgumentList $FfvshipArguments -Wait -PassThru -NoNewWindow

    # ガード節：失敗時はここで終了
    if ($Process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $TempJsonFilePath)) {
      Write-Warning "FFVship execution failed or JSON not found."
      return $ResultStats
    }

    # 以下、成功時の処理

    # 生データの保存 (オプション)
    if (-not [string]::IsNullOrEmpty($RawJsonFilePath)) {
      Copy-Item -LiteralPath $TempJsonFilePath -Destination $RawJsonFilePath -Force
      Write-Host "SSIMULACRA2 raw JSON saved to: $RawJsonFilePath" -ForegroundColor Gray
    }

    # データの読み込み
    $RawScores = Read-Ssimu2Scores -JsonFilePath $TempJsonFilePath
    
    # メイン統計の算出
    $ResultStats = Measure-Ssimu2Statistics -InputScores $RawScores

    # クリップ済みデータの計算（負の値を0にする補正）
    $ClippedScores = Get-ClippedScores -InputScores $RawScores
    $ResultStats.Clipped = Measure-Ssimu2Statistics -InputScores $ClippedScores

    # クリップ済みデータの保存 (オプション)
    if (-not [string]::IsNullOrEmpty($ClippedJsonFilePath) -and $null -ne $ClippedScores) {
      $ClippedScores | ConvertTo-Json -Compress | Set-Content -LiteralPath $ClippedJsonFilePath -Encoding UTF8
      Write-Host "SSIMULACRA2 clipped JSON saved to: $ClippedJsonFilePath" -ForegroundColor Gray
    }
  }
  catch {
    Write-Warning "SSIMULACRA2 Measurement Error: $($_.Exception.Message)"
  }
  finally {
    # 一時ファイルのクリーンアップ
    foreach ($Path in $CleanupPaths) {
      if (Test-Path -LiteralPath $Path) {
        # -Recurse でフォルダごと削除
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }

  return $ResultStats
}

<#
.SYNOPSIS
  SSIMULACRA2のスコア配列から統計情報(平均、中央値など)を算出します。
#>
function Measure-Ssimu2Statistics {
  [CmdletBinding()]
  param([System.Array]$InputScores)

  $ResultStats = [Ssimu2Metrics]::new()

  if ($null -eq $InputScores -or $InputScores.Count -eq 0) {
    return $ResultStats
  }

  try {
    # Measure-Object は統計情報を一括計算するコマンドレット
    $Stats = $InputScores | Measure-Object -Average -Minimum -Maximum -StandardDeviation
    $Format = { param($Value) "{0,10:F6}" -f $Value }

    $ResultStats.Average = & $Format $Stats.Average
    $ResultStats.StandardDeviation = & $Format $Stats.StandardDeviation
    $ResultStats.Minimum = & $Format $Stats.Minimum
    $ResultStats.Maximum = & $Format $Stats.Maximum

    # パーセンタイル計算 (ソートして位置を特定)
    $SortedScores = $InputScores | Sort-Object
    $Count = $SortedScores.Count
    $GetPercentileVal = {
      param($Percent)
      $Index = [Math]::Floor(($Count - 1) * $Percent)
      return $SortedScores[$Index]
    }

    $ResultStats.Median = & $Format (& $GetPercentileVal 0.50)
    $ResultStats.Percentile5 = & $Format (& $GetPercentileVal 0.05)
    $ResultStats.Percentile95 = & $Format (& $GetPercentileVal 0.95)
  }
  catch {
    Write-Warning "Statistics Calculation Error: $($_.Exception.Message)"
  }
  return $ResultStats
}

<#
.SYNOPSIS
  JSONファイルまたは配列からスコアをフラットな配列として抽出します。
#>
function Read-Ssimu2Scores {
  [CmdletBinding()]
  param([string]$JsonFilePath)

  if (-not (Test-Path -LiteralPath $JsonFilePath)) {
    return $null
  }

  try {
    $RawJsonData = Get-Content -LiteralPath $JsonFilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    # 配列が入れ子になっている場合に対応するフラット化処理
    $Scores = $RawJsonData | ForEach-Object {
      if ($_ -is [System.Array]) { $_ } else { $_ }
    }
    return $Scores
  }
  catch {
    Write-Warning "JSON Parse Error: $($_.Exception.Message)"
    return $null
  }
}

<#
.SYNOPSIS
  スコア配列から負の値を除外（0に置換）した新しい配列を生成します。
#>
function Get-ClippedScores {
  [CmdletBinding()]
  param([System.Array]$InputScores)

  if ($null -eq $InputScores) { return @() }

  $ClippedScores = $InputScores | ForEach-Object {
    if ($_ -lt 0) { 0 } else { $_ }
  }
  return $ClippedScores
}

<#
.SYNOPSIS
  日本語パス問題回避のためのコンテキスト（一時ファイル情報）を作成します。
#>
function New-Ssimu2TempContext {
  [CmdletBinding()]
  param (
    [string]$ReferenceFilePath,
    [string]$DistortedFilePath
  )

  # 日本語パス問題回避の適用判定
  # FFVship が日本語パスに対応した場合は、ここを $false に変更
  $UseLegacyPathWorkaround = $true
  
  $Context = @{
    ExecReferencePath = $ReferenceFilePath
    ExecDistortedPath = $DistortedFilePath
    CleanupPaths      = @()
  }

  if ($UseLegacyPathWorkaround) {
    # 作業用親フォルダ (固定名)
    $ParentTempDirPath = Join-Path ([System.IO.Path]::GetTempPath()) "Amt_Ssimu2_Work"
    
    # ガベージコレクション (古い一時フォルダの削除)
    Clear-StaleTempArtifacts -ParentTempDirPath $ParentTempDirPath -ExpirationHours 24

    # 今回の実行用フォルダの作成
    # ディレクトリ作成時の競合を防ぐためランダム名を付与
    $RandomString = [System.IO.Path]::GetRandomFileName() -replace "\.", ""
    $CurrentWorkDirPath = Join-Path $ParentTempDirPath ("Run_" + $RandomString)
    
    if (-not (Test-Path -LiteralPath $CurrentWorkDirPath)) {
      New-Item -Path $CurrentWorkDirPath -ItemType Directory -Force | Out-Null
    }

    # クリーンアップ対象として「フォルダごと」登録
    $Context.CleanupPaths += $CurrentWorkDirPath

    # 一時ファイルパスの設定
    $TempReferenceFilePath = Join-Path $CurrentWorkDirPath ("tmp_ref" + (Get-Item $ReferenceFilePath).Extension)
    $TempDistortedFilePath = Join-Path $CurrentWorkDirPath ("tmp_dst" + (Get-Item $DistortedFilePath).Extension)

    # 一時ファイルパスにコピー
    Write-Host "${NewLine}Copying files to TEMP for FFVship processing..." -ForegroundColor DarkGray
    Copy-Item -LiteralPath $ReferenceFilePath -Destination $TempReferenceFilePath -Force
    Copy-Item -LiteralPath $DistortedFilePath -Destination $TempDistortedFilePath -Force

    # ASCII文字の構成となる 8.3形式(ショートパス)でパスを取得
    $Context.ExecReferencePath = Get-WindowsShortPath -FilePath $TempReferenceFilePath
    $Context.ExecDistortedPath = Get-WindowsShortPath -FilePath $TempDistortedFilePath
  }

  return $Context
}

<#
.SYNOPSIS
  古い一時作業フォルダを削除します。
#>
function Clear-StaleTempArtifacts {
  [CmdletBinding()]
  param (
    [string]$ParentTempDirPath,
    # 期限切れ時間の設定
    [int]$ExpirationHours = 24
  )

  if (-not (Test-Path -LiteralPath $ParentTempDirPath)) {
    return
  }

  try {
    # 親フォルダ直下のサブフォルダを取得
    $SubDirs = Get-ChildItem -LiteralPath $ParentTempDirPath -Directory -ErrorAction SilentlyContinue
    $ThresholdDate = (Get-Date).AddHours(-$ExpirationHours)

    foreach ($Dir in $SubDirs) {
      if ($Dir.CreationTime -lt $ThresholdDate) {
        # 期限切れのフォルダを削除 (他プロセスが使用中の場合はスキップ)
        Remove-Item -LiteralPath $Dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }
  catch {
    # GCの失敗はメイン処理に影響させない
    Write-Verbose "GC Warning: $($_.Exception.Message)"
  }
}

<#
.SYNOPSIS
  パスを短い形式 (8.3形式) に変換します。
#>
function Get-WindowsShortPath {
  [CmdletBinding()]
  param([string]$FilePath)

  if (-not (Test-Path -LiteralPath $FilePath)) {
    return $FilePath
  }
  try {
    $FileSystemObject = New-Object -ComObject Scripting.FileSystemObject
    return $FileSystemObject.GetFile($FilePath).ShortPath
  }
  catch {
    return $FilePath
  }
}

# =========================================================
# 実行エントリポイント
# =========================================================

# FFVship.exe のパスをPATH環境変数から探索
$FfvshipFilePath = (Get-Command "FFVship.exe" -ErrorAction SilentlyContinue).Source

# メイン関数を呼び出して結果をパイプラインに出力
Invoke-Ssimu2Measurement `
  -FfvshipFilePath $FfvshipFilePath `
  -DistortedFilePath $DistortedFilePath `
  -ReferenceFilePath $ReferenceFilePath `
  -RawJsonFilePath $RawJsonFilePath `
  -ClippedJsonFilePath $ClippedJsonFilePath