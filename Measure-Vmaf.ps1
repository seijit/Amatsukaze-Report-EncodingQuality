<#
.SYNOPSIS
  FFmpeg画質評価 (VMAF / SSIM / PSNR) 自動計測スクリプト

.DESCRIPTION
  指定された「評価対象動画」と「リファレンス動画」を比較し、
  FFmpeg (libvmaf / ssim / psnr) を実行してスコアを算出・返却します。
#>

[CmdletBinding()]
param(
  # 評価対象動画のパス (必須)
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$DistortedFilePath,

  # リファレンス動画のパス (必須)
  [Parameter(Mandatory = $true, Position = 1)]
  [string]$ReferenceFilePath,

  # VMAFモデルパス (空文字の場合は FFmpeg 内蔵のデフォルトモデルを使用)
  # vmaf_v0.6.1neg.json などの外部ファイルを指定可能
  [string]$VmafModelFilePath = "",

  # libvmaf オプション設定
  # n_threads      : 並列処理スレッド数
  # shortest=1     : 短い方の動画（通常はエンコード済み側）が終了した時点で計測を打ち切り
  # ts_sync_mode=1 : タイムスタンプに基づいて同期（フレームドロップ対策）
  [string]$LibvmafOptions = "n_threads=8:shortest=1:repeatlast=0:ts_sync_mode=1",

  # FFmpeg ハードウェアデコード設定
  # "auto", "cuda", "qsv", "d3d11va" 等。VMAFスコアへの影響を避けるため空文字(CPU処理)を推奨
  [string]$FfmpegHwAccel = ""
)

# PowerShellの実行時エラーで「停止」して、適切に Catch 節へ飛ばす設定
$ErrorActionPreference = "Stop"
$NewLine = [Environment]::NewLine

# =========================================================
# クラス定義
# =========================================================

# FFmpeg の統計データを保持するクラス
class VmafMetrics {
  [string]$VMAF = "N/A"
  [string]$VmafModelName = "-"
  [string]$SSIM = "N/A"
  [string]$PSNR = "N/A"
}

# =========================================================
# 関数
# =========================================================

<#
.SYNOPSIS
  VMAF計測のメイン処理を実行します。
#>
function Invoke-VmafMeasurement {
  [CmdletBinding()]
  param (
    [string]$FfmpegFilePath,
    [string]$DistortedFilePath,
    [string]$ReferenceFilePath,
    [string]$VmafModelFilePath,
    [string]$LibvmafOptions,
    [string]$FfmpegHwAccel
  )

  if ([string]::IsNullOrEmpty($FfmpegFilePath) -or -not (Test-Path -LiteralPath $FfmpegFilePath)) {
    Write-Warning "ffmpeg.exe not found in PATH."
    return [VmafMetrics]::new()
  }

  $ResultStats = [VmafMetrics]::new()

  try {
    # フィルタ文字列の生成
    $FfmpegFilterComplex = New-VmafFilterComplex `
      -VmafModelFilePath $VmafModelFilePath `
      -LibvmafOptions $LibvmafOptions

    # FFmpeg実行
    $FfmpegOutput = Invoke-VmafProcess `
      -ExecutableFilePath $FfmpegFilePath `
      -InputFilePaths @($DistortedFilePath, $ReferenceFilePath) `
      -FilterComplex $FfmpegFilterComplex `
      -FfmpegHwAccel $FfmpegHwAccel

    # 結果解析
    $ResultStats = ConvertFrom-FfmpegOutput `
      -FfmpegOutput $FfmpegOutput `
      -VmafModelFilePath $VmafModelFilePath
  }
  catch {
    Write-Warning "FFmpeg Measurement Error: $($_.Exception.Message)"
  }

  return $ResultStats
}

<#
.SYNOPSIS
  FFmpegを実行し、標準エラー出力を返却します。
#>
function Invoke-VmafProcess {
  [CmdletBinding()]
  param(
    [string]$ExecutableFilePath,
    [string[]]$InputFilePaths,
    [string]$FilterComplex,
    [string]$FfmpegHwAccel
  )

  # .NETのProcessクラスを使用して、FFmpegの標準エラー出力をキャプチャする
  $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
  $ProcessInfo.FileName = $ExecutableFilePath
  $ProcessInfo.RedirectStandardError = $true
  $ProcessInfo.UseShellExecute = $false
  $ProcessInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
  
  # 引数リストの構築
  $ArgsList = $ProcessInfo.ArgumentList
  $ArgsList.Add("-hide_banner")

  foreach ($InputPath in $InputFilePaths) {
    if (-not [string]::IsNullOrEmpty($FfmpegHwAccel)) {
      $ArgsList.Add("-hwaccel")
      $ArgsList.Add($FfmpegHwAccel)
    }
    $ArgsList.Add("-i")
    $ArgsList.Add($InputPath)
  }

  $ArgsList.Add("-filter_complex")
  $ArgsList.Add($FilterComplex)
  $ArgsList.Add("-an") # 音声無効化
  $ArgsList.Add("-f")
  $ArgsList.Add("null") # null 出力デバイス
  $ArgsList.Add("-")

  # コマンド確認用出力
  $DisplayCmd = "`"$($ProcessInfo.FileName)`" " + ($ArgsList -join " ")
  Write-Host "${NewLine}[FFmpeg Command]" -ForegroundColor DarkGray
  Write-Host "$DisplayCmd${NewLine}" -ForegroundColor DarkGray

  # プロセス実行
  $Process = New-Object System.Diagnostics.Process
  $Process.StartInfo = $ProcessInfo
  $Process.Start() | Out-Null
  
  # FFmpegのログは標準エラー出力に出る
  $OutputLog = $Process.StandardError.ReadToEnd()
  $Process.WaitForExit()

  return $OutputLog
}

<#
.SYNOPSIS
  FFmpegのログからスコアを抽出してオブジェクトに格納します。
#>
function ConvertFrom-FfmpegOutput {
  [CmdletBinding()]
  param(
    [string]$FfmpegOutput,
    [string]$VmafModelFilePath
  )

  $ResultStats = [VmafMetrics]::new()
  
  # 数値フォーマット用ヘルパー
  $FormatScore = {
    param($Value)
    if ($Value -is [string] -and ($null -eq ($Value -as [double]))) { return $Value.PadLeft(10) }
    "{0,10:F6}" -f [double]$Value
  }

  # 正規表現によるスコア抽出
  if ($FfmpegOutput -match "VMAF score:\s*([0-9.]+)") { 
    $ResultStats.VMAF = & $FormatScore $Matches[1] 
  }
  
  # モデル名の抽出
  $ResultStats.VmafModelName = if (-not [string]::IsNullOrEmpty($VmafModelFilePath)) { 
    Split-Path $VmafModelFilePath -Leaf 
  }
  else { 
    "default" 
  }
  
  if ($FfmpegOutput -match "SSIM.*?All:([0-9.]+)") { 
    $ResultStats.SSIM = & $FormatScore $Matches[1] 
  }
  
  if ($FfmpegOutput -match "PSNR.*?average:([0-9.]+)") { 
    $ResultStats.PSNR = & $FormatScore $Matches[1] 
  }

  return $ResultStats
}

<#
.SYNOPSIS
  VMAF計測用の filter_complex 文字列を生成します。
#>
function New-VmafFilterComplex {
  [CmdletBinding()]
  param(
    [string]$VmafModelFilePath,
    [string]$LibvmafOptions
  )

  $VmafModelOption = ""
  if (-not [string]::IsNullOrEmpty($VmafModelFilePath)) {
    # フィルタパス内のエスケープ処理: バックスラッシュをスラッシュに、コロンをエスケープ
    $EscapedModelFilePath = $VmafModelFilePath.Replace("\", "/").Replace(":", "\\\:")
    $VmafModelOption = "model='path=${EscapedModelFilePath}':"
  }

  # フィルタグラフ構築
  # [1:v]... split=3 ... : リファレンスを3分岐 (PSNR用, SSIM用, VMAF用)
  # [0:v]... [main]      : 評価対象を main ラベルへ
  $FilterComplex = @(
    "[1:v]setpts=PTS-STARTPTS,split=3[ref1][ref2][ref3];"
    "[0:v]setpts=PTS-STARTPTS[main];"
    "[main][ref1]psnr=ts_sync_mode=1[v_psnr];"
    "[v_psnr][ref2]ssim=ts_sync_mode=1[v_ssim];"
    "[v_ssim][ref3]libvmaf=${VmafModelOption}${LibvmafOptions}"
  ) -join ""

  return $FilterComplex
}

# =========================================================
# 実行エントリポイント
# =========================================================

# FFmpeg.exe のパスをPATH環境変数から探索
$FfmpegFilePath = (Get-Command "ffmpeg.exe" -ErrorAction SilentlyContinue).Source

# メイン関数を呼び出して結果をパイプラインに出力
Invoke-VmafMeasurement `
  -FfmpegFilePath $FfmpegFilePath `
  -DistortedFilePath $DistortedFilePath `
  -ReferenceFilePath $ReferenceFilePath `
  -VmafModelFilePath $VmafModelFilePath `
  -LibvmafOptions $LibvmafOptions `
  -FfmpegHwAccel $FfmpegHwAccel