<#
.SYNOPSIS
  画質評価メトリクス (SSIMULACRA2 / VMAF / SSIM / PSNR) 自動計測スクリプト
  Amatsukaze 実行後バッチ 連携仕様

.DESCRIPTION
  ■ 概要

    エンコードした映像の画質を評価します。
    評価対象とリファレンスを比較して画質劣化を数値化します(FFmpeg使用)。
    Amatsukazeのタスクログを解析し、圧縮効率・エンコード設定・ハードウェア情報をレポートします。

      評価対象: ソースをエンコードした映像
      リファレンス: 評価の基準になる映像

  ■ リファレンスはロスレスを使用

    VMAF等の評価指標は、リファレンスを「絶対的な正解(100点)」として差分を計測します。
    このスクリプトでは、ソースのロスレス出力をリファレンスとして使用します。
    リファレンスは下記の手順に従ってユーザーが自分で用意する必要があります。

  ■ 画質評価のフロー

    1. 評価対象用のプロファイルを作成
    2. リファレンス用のプロファイルを作成（評価対象用のプロファイルをコピー）
    3. リファレンスを出力（Amatsukazeのタスクをテストモードで実行）
    4. 評価対象を出力（Amatsukazeのタスクをテストモードで実行）
      -> 画質評価が実行される (実行後バッチ)

  ■ 画質評価のフロー詳細

    1. 評価対象用のプロファイルを作成
      - エンコーダ
        - 任意。
      - エンコーダ追加オプション
        - 10bitを指定。他は任意。
      - 出力選択
        - 任意。
      - 実行後バッチ
        - 実行後_Report-EncodingQuality.cmd
      - フィルタ設定
        - インターレース解除
          - ON  インターレース解除は必須。
            - 解除方法
              - 任意。
        - デブロッキング
          - 任意。
        - 時間軸安定化
          - 任意。
        - バンディング低減
          - 任意。
        - エッジ強調（アニメ用）
          - 任意。
      - その他の設定
        - ロゴ消ししない
          - 任意。
        - ログファイルを出力先に生成しない
          - OFF  レポートにログファイルの参照が必要。
        - プロファイルの情報を出力先にテキストとして保存
          - ON   レポートにプロファイルの参照が必要。

    2. リファレンス用のプロファイルを作成（評価対象用のプロファイルをコピー）
      - エンコーダ
        - 評価対象と同じ。
      - エンコーダ追加オプション
        - ロスレスを指定。10bitを指定。
          (NVEncの例: --codec hevc --lossless --output-depth 10)
      - 出力選択
        - 評価対象と同じ。
      - 実行後バッチ
        - 実行後_Setup-Reference.cmd
      - フィルタ設定
        - インターレース解除
          - ON  インターレース解除は必須。
            - 解除方法/設定
              - 評価対象と同じ。
        - デブロッキング
          - OFF
        - 時間軸安定化
          - OFF
        - バンディング低減
          - OFF
        - エッジ強調（アニメ用）
          - OFF
      - その他の設定
        - ロゴ消ししない
          - 評価対象と同じ。
        - ログファイルを出力先に生成しない
          - 任意。
        - プロファイルの情報を出力先にテキストとして保存
          - 任意。

    3. リファレンスを出力（Amatsukazeのタスクをテストモードで実行）
      - ソースTSを入力に、リファレンス用プロファイルを使用して出力
        - 実行後_Setup-Reference.cmd
          - 出力されたファイルがリファレンスとして配置される
            - 命名規則：[ソースファイル名].lossless.[拡張子]
              (例：video.ts -> video.lossless.mp4)
            - 配置先：ソースTSと同一フォルダ

    4. 評価対象を出力（Amatsukazeのタスクをテストモードで実行）
      - ソースTSを入力に、評価対象用プロファイルを使用して出力
      - 実行後バッチで画質評価が実行
      - 画質評価の結果はファイルで出力
        - 命名規則：[評価対象ファイル名].report.txt
          (例：video.mp4 -> video.mp4.report.txt)
        - 配置先：評価対象ファイルと同一フォルダ

  ■ 補足事項

    - インターレース解除のフィルタ適用によるフレーム構造について
      - プロファイルをコピーするので評価対象とリファレンスのフレーム特性/フレームシーケンスは一致します。
    - デブロッキング等のフィルタ適用による意図的な映像の変化について
      - ソース/エンコーダオプションが高画質/低圧縮の場合
        - フィルタ適用が画質評価を下げる場合があります。
      - ソース/エンコーダオプションが低画質/高圧縮の場合
        - フィルタ適用が画質評価を上げる場合があります。
    - 画質評価の対象について
      - 対象はフィルタ適用も含めた出力であり、エンコーダ単独の出力ではありません。
        - エンコーダ単独の出力を純粋に評価したい場合は、
          評価対象用プロファイルでもリファレンス用プロファイルと同様にデブロッキング等のフィルタ適用をすべて解除してください。
    - VMAFモデルについて
      - デフォルトのモデルが使用されます。
      - オプションでモデルを vmaf_v0.6.1neg.json に変更が可能です。
        - vmaf_v0.6.1neg.json は劣化の過小評価を防ぎ、厳格なスコアリングを行うNegativeモードなモデルです。

#>

[CmdletBinding()]
param(
  # 評価対象 (Distorted) のパスまたは拡張子抜きのベースパス
  # エンコード後の画質を評価したいファイルのパスを指定します。
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$DistortedFilePathBase,

  # ソースTSのパス
  # このパスから評価の基準になるリファレンスを探索します。
  [Parameter(Mandatory = $true, Position = 1)]
  [string]$SourceFilePath,

  # レポート出力先フォルダ
  # 未指定時は評価対象と同じフォルダになります。
  [Parameter(Position = 2)]
  [string]$OutputDirPath = "",

  # SSIMULACRA2の計測データをJSONで保存するかどうか
  [switch]$SaveSsimu2Json,

  # レポート全体をJSON形式でも保存するかどうか
  [switch]$SaveReportJson,

  # 出力ファイル名をユニークにするかどうか
  [switch]$UniqueOutputName
)

# PowerShellの実行時エラーで「停止」して、適切に Catch 節へ飛ばす設定
$ErrorActionPreference = "Stop"
$NewLine = [Environment]::NewLine

# =========================================================
# 環境設定
# =========================================================

# スクリプト全体で使用する設定値
$Script:GlobalConfig = @{
  # SSIMULACRA2計測用スクリプトのパス
  Ssimu2ScriptFilePath    = "Measure-Ssimu2.ps1"

  # VMAF/SSIM/PSNR計測用スクリプトのパス
  VmafScriptFilePath      = "Measure-Vmaf.ps1"

  # VMAFモデルパス (空文字の場合は FFmpeg 内蔵のデフォルトモデルを使用)
  # vmaf_v0.6.1neg.json などの外部ファイルを指定可能
  VmafModelFilePath       = ""

  # libvmaf オプション設定
  # n_threads      : 並列処理スレッド数
  # shortest=1     : 短い方の動画（通常はエンコード済み側）が終了した時点で計測を打ち切り
  # ts_sync_mode=1 : タイムスタンプに基づいて同期（フレームドロップ対策）
  LibvmafOptions          = "n_threads=8:shortest=1:repeatlast=0:ts_sync_mode=1"

  # FFmpeg ハードウェアデコード設定
  # "auto", "cuda", "qsv", "d3d11va" 等。VMAFスコアへの影響を避けるため空文字(CPU処理)を推奨
  FfmpegHwAccel           = ""

  # ロスレスのリファレンス動画を特定するための識別子
  # ファイル名と拡張子の間に挿入されます (例: video.lossless.mp4)。
  ReferenceSuffix         = ".lossless"

  # 出力ファイルの拡張子定義
  Ssimu2RawJsonSuffix     = ".ssimu2.raw.json"
  Ssimu2ClippedJsonSuffix = ".ssimu2.clipped.json"
  ReportJsonSuffix        = ".report.json"
  ReportTextSuffix        = ".report.txt"

  # ファイル名の重複を防ぐためのサフィックス (日時)
  UniqueSuffix            = if ($UniqueOutputName) { "." + (Get-Date -Format "yyyyMMdd-HHmmss") } else { "" }
}

# =========================================================
# クラス定義
# =========================================================

# 最終的な画質評価スコアをまとめるクラス
class ReportMetrics {
  # N/A(文字列) または 外部スクリプトが返すオブジェクトを許容するため System.Object型を使用
  [System.Object]$Ssimu2 = "N/A"
  [string]$VMAF = "N/A"
  [string]$VmafModelName = "-"
  [string]$SSIM = "N/A"
  [string]$PSNR = "N/A"
}

# エンコードログから抽出したデータを保持するクラス
class AmatsukazeLogInfo {
  [string]$Bitrate = "-"
  [string]$FPS = "-"
  [string]$EncodingTime = "-"
  [string]$CPU = "-"
  [string]$GPU = "-"
  [string]$EncoderSpec = "-"

  # ログファイルを解析してインスタンスを生成
  static [AmatsukazeLogInfo] Parse([string]$VideoFilePath) {
    $Metadata = [AmatsukazeLogInfo]::new()
    # 動画ファイルのパスからログファイルのパスを導出 (.mp4 -> -enc.log)
    $LogFilePath = $VideoFilePath -replace "\.[^.]+$", "-enc.log"

    if (-not (Test-Path -LiteralPath $LogFilePath -ErrorAction SilentlyContinue)) {
      return $Metadata
    }

    try {
      # Amatsukazeのログは Shift-JIS (932) であるためエンコーディングを指定
      $EncodingSJIS = [System.Text.Encoding]::GetEncoding(932)
      $LogLines = [System.IO.File]::ReadAllLines($LogFilePath, $EncodingSJIS)

      # ログの各行を正規表現で解析
      switch -Regex ($LogLines) {
        # エンコード結果行
        "encoded (\d+) frames, ([\d\.]+) fps, ([\d\.]+) kbps" {
          # 最初に出現した値のみを採用（メインパート）
          if ($Metadata.FPS -eq "-") {
            $Metadata.FPS = $Matches[2]
            $Metadata.Bitrate = $Matches[3]
          }
        }
        # 所要時間
        "encode time (\d+:\d+:\d+)" {
          # 最初に出現した値のみを採用（メインパート）
          if ($Metadata.EncodingTime -eq "-") {
            $Metadata.EncodingTime = $Matches[1]
          }
        }
        # CPU情報
        "^CPU\s+(.+)" {
          $Metadata.CPU = $Matches[1].Trim()
        }
        # GPU情報
        "^GPU\s+#\d+:\s+(.+)$" {
          $Metadata.GPU = $Matches[1].Trim()
        }
        # エンコーダ名 (NVEncC, x264等)
        "^(NVEncC|QSVEncC|VCEEncC|x264|x265|svt-av1).+\d{4}.+\)$" {
          $Metadata.EncoderSpec = $_.Trim()
        }
      }
    }
    catch {
      Write-Warning "Amatsukaze log parsing error: $($_.Exception.Message)"
    }
    return $Metadata
  }
}

# Amatsukazeのプロファイル設定を保持するクラス
class AmatsukazeProfileInfo {
  [string]$ProfileName = "-"
  [string]$Encoder = "-"
  [string]$Params = "-"
  [string]$FilterStatus = "No"
  [string]$MainFilter = "-"
  [string]$PostFilter = "-"
  [string]$CudaProcess = "No"
  [string]$Deinterlace = "No"
  [string]$DeinterlaceMethod = "-"
  [string]$SMDegrainNR = "No"
  [string]$DecombUCF = "No"
  [string]$OutputFPS = "-"
  [string]$VFRTiming = "-"
  [string]$D3dvpGpu = "-"
  [string]$QTGMCPreset = "-"
  [string]$AutoVfr30 = "-"
  [string]$AutoVfr60 = "-"
  [string]$AutoVfrSkip = "-"
  [string]$AutoVfrRef = "-"
  [string]$AutoVfrCrop = "-"
  [string]$Deblock = "No"
  [string]$DeblockStrength = "-"
  [string]$DeblockQuality = "-"
  [string]$DeblockSharpen = "-"
  [string]$Resize = "No"
  [string]$ResizeW = "-"
  [string]$ResizeH = "-"
  [string]$TimeStability = "No"
  [string]$ReduceBanding = "No"
  [string]$EdgeEnhance = "No"

  # プロファイル情報を解析してインスタンスを生成
  static [AmatsukazeProfileInfo] Parse([string]$VideoFilePath) {
    $Settings = [AmatsukazeProfileInfo]::new()
    $ProfileFilePath = $VideoFilePath -replace "\.[^.]+$", ".profile.txt"

    if (-not (Test-Path -LiteralPath $ProfileFilePath -ErrorAction SilentlyContinue)) {
      return $Settings
    }

    try {
      # プロファイル情報はUTF-8で出力される 
      $Lines = [System.IO.File]::ReadAllLines($ProfileFilePath, [System.Text.Encoding]::UTF8)
      foreach ($Line in $Lines) {
        # プロファイルの各設定項目を正規表現で抽出
        switch -Regex ($Line) {
          "^プロファイル名:\s*(.+)" { $Settings.ProfileName = $Matches[1].Trim(); break }
          "^エンコーダ:\s*(.+)" { $Settings.Encoder = $Matches[1].Trim(); break }
          "^エンコーダ追加オプション:\s*(.+)" { $Settings.Params = $Matches[1].Trim(); break }

          "^フィルタ:\s*なし" { $Settings.FilterStatus = "No"; break }
          "^メインフィルタ:\s*(.+)" { $Settings.MainFilter = $Matches[1].Trim(); $Settings.FilterStatus = "Custom"; break }
          "^ポストフィルタ:\s*(.+)" { $Settings.PostFilter = $Matches[1].Trim(); $Settings.FilterStatus = "Custom"; break }
          "^フィルタ-CUDAで処理:\s*(Yes|No)" { $Settings.CudaProcess = $Matches[1]; $Settings.FilterStatus = "Yes"; break }
          "^フィルタ-インターレース解除:\s*(Yes|No)" { $Settings.Deinterlace = $Matches[1]; break }
          "^フィルタ-インターレース解除方法:\s*(.+)" { $Settings.DeinterlaceMethod = $Matches[1].Trim(); break }
          "^フィルタ-SMDegrainによるNR:\s*(Yes|No)" { $Settings.SMDegrainNR = $Matches[1]; break }
          "^フィルタ-DecombUCF:\s*(Yes|No)" { $Settings.DecombUCF = $Matches[1]; break }
          "^フィルタ-出力fps:\s*(.+)" { $Settings.OutputFPS = $Matches[1].Trim(); break }
          "^フィルタ-VFRフレームタイミング:\s*(.+)" { $Settings.VFRTiming = $Matches[1].Trim(); break }
          "^フィルタ-使用GPU:\s*(.+)" { $Settings.D3dvpGpu = $Matches[1].Trim(); break }
          "^フィルタ-QTGMCプリセット:\s*(.+)" { $Settings.QTGMCPreset = $Matches[1].Trim(); break }
          "^フィルタ-30fpsを使用する:\s*(.+)" { $Settings.AutoVfr30 = $Matches[1].Trim(); break }
          "^フィルタ-60fpsを使用する:\s*(.+)" { $Settings.AutoVfr60 = $Matches[1].Trim(); break }
          "^フィルタ-SKIP:\s*(.+)" { $Settings.AutoVfrSkip = $Matches[1].Trim(); break }
          "^フィルタ-REF:\s*(.+)" { $Settings.AutoVfrRef = $Matches[1].Trim(); break }
          "^フィルタ-CROP:\s*(.+)" { $Settings.AutoVfrCrop = $Matches[1].Trim(); break }
          "^フィルタ-デブロッキング:\s*(Yes|No)" { $Settings.Deblock = $Matches[1]; break }
          "^フィルタ-デブロッキング強度:\s*(.+)" { $Settings.DeblockStrength = $Matches[1].Trim(); break }
          "^フィルタ-デブロッキング品質:\s*(.+)" { $Settings.DeblockQuality = $Matches[1].Trim(); break }
          "^フィルタ-デブロッキングシャープ化:\s*(Yes|No)" { $Settings.DeblockSharpen = $Matches[1]; break }
          "^フィルタ-リサイズ:\s*(Yes|No)" { $Settings.Resize = $Matches[1]; break }
          "^フィルタ-リサイズ-横:\s*(.+)" { $Settings.ResizeW = $Matches[1].Trim(); break }
          "^フィルタ-リサイズ-縦:\s*(.+)" { $Settings.ResizeH = $Matches[1].Trim(); break }
          "^フィルタ-時間軸安定化:\s*(Yes|No)" { $Settings.TimeStability = $Matches[1]; break }
          "^フィルタ-バンディング低減:\s*(Yes|No)" { $Settings.ReduceBanding = $Matches[1]; break }
          "^フィルタ-エッジ強調:\s*(Yes|No)" { $Settings.EdgeEnhance = $Matches[1]; break }
        }
      }
    }
    catch {
      Write-Warning "Profile parsing error: $($_.Exception.Message)"
    }
    return $Settings
  }
}

# =========================================================
# 関数
# =========================================================

<#
.SYNOPSIS
  メイン処理: 画質評価プロセス全体を制御します。
#>
function Measure-EncodingQuality {
  [CmdletBinding()]
  param()

  # パスの確定
  $DistortedFilePath = Get-VideoFilePath -FilePathBase $DistortedFilePathBase
  $DistortedFileItem = Get-Item -LiteralPath $DistortedFilePath
  $SourceFileItem = Get-Item -LiteralPath $SourceFilePath

  # リファレンスの探索
  $ReferenceFileName = "$($SourceFileItem.BaseName)$($Script:GlobalConfig.ReferenceSuffix)$($DistortedFileItem.Extension)"
  $ReferenceFilePath = Join-Path -Path $SourceFileItem.DirectoryName -ChildPath $ReferenceFileName
  $ReferenceExists = Test-Path -LiteralPath $ReferenceFilePath

  # 出力ディレクトリ決定
  $TargetOutputDirPath = if (-not [string]::IsNullOrEmpty($OutputDirPath)) {
    if (-not (Test-Path -LiteralPath $OutputDirPath)) {
      New-Item -Path $OutputDirPath -ItemType Directory -Force | Out-Null
    }
    $OutputDirPath
  }
  else {
    $DistortedFileItem.DirectoryName
  }

  Write-Host "${NewLine}=======================================================" -ForegroundColor Cyan
  Write-Host "Starting Video Encoding Quality Report" -ForegroundColor Cyan
  Write-Host "=======================================================" -ForegroundColor Cyan
  Write-Host "Distorted : $(Split-Path $DistortedFilePath -Leaf)"
  if ($ReferenceExists) {
    Write-Host "Reference : $(Split-Path $ReferenceFilePath -Leaf)"
  }
  else {
    Write-Warning "Reference : Not Found (Skipping Quality Metrics)"
    $ReferenceFilePath = ""
  }

  # 画質評価実行
  $Scores = [ReportMetrics]::new()
  if ($ReferenceExists) {
    $Scores = Invoke-QualityMetrics `
      -DistortedFilePath $DistortedFilePath `
      -ReferenceFilePath $ReferenceFilePath `
      -OutputDirPath $TargetOutputDirPath `
      -SaveSsimu2Json $SaveSsimu2Json
  }

  # レポート出力
  Export-QualityReport `
    -DistortedFilePath $DistortedFilePath `
    -SourceFilePath $SourceFilePath `
    -ReferenceFilePath $ReferenceFilePath `
    -OutputDirPath $TargetOutputDirPath `
    -Scores $Scores `
    -SaveReportJson $SaveReportJson

  Write-Host "${NewLine}=======================================================" -ForegroundColor Cyan
  Write-Host "All processes completed" -ForegroundColor Cyan
  Write-Host "=======================================================" -ForegroundColor Cyan
}

<#
.SYNOPSIS
  画質評価処理（外部スクリプトの呼び出し）を実行します。
#>
function Invoke-QualityMetrics {
  [CmdletBinding()]
  param(
    [string]$DistortedFilePath,
    [string]$ReferenceFilePath,
    [string]$OutputDirPath,
    [bool]$SaveSsimu2Json
  )
  
  $Scores = [ReportMetrics]::new()
  $DistortedFileName = Split-Path $DistortedFilePath -Leaf

  # SSIMULACRA2 計測 (外部スクリプト)
  # パス解決 (相対パスなら結合、絶対パスならそのまま)
  $Ssimu2ScriptFilePath = Resolve-ScriptFilePath -RelativeFilePath $Script:GlobalConfig.Ssimu2ScriptFilePath -BaseDirPath $PSScriptRoot
  
  # ガード節: エラー(不在)を処理
  if (-not (Test-Path -LiteralPath $Ssimu2ScriptFilePath)) {
    Write-Warning "SSIMULACRA2 script not found at: $Ssimu2ScriptFilePath"
  }
  else {
    Write-Host "${NewLine}[1/3] Measuring SSIMULACRA2 (via FFVship)..." -ForegroundColor Yellow
    
    $RawJsonFilePath = ""
    $ClippedJsonFilePath = ""
    if ($SaveSsimu2Json) {
      $Ssimu2FileBaseName = "$DistortedFileName$($Script:GlobalConfig.UniqueSuffix)"
      $RawJsonFilePath = Join-Path -Path $OutputDirPath -ChildPath "${Ssimu2FileBaseName}$($Script:GlobalConfig.Ssimu2RawJsonSuffix)"
      $ClippedJsonFilePath = Join-Path -Path $OutputDirPath -ChildPath "${Ssimu2FileBaseName}$($Script:GlobalConfig.Ssimu2ClippedJsonSuffix)"
    }

    try {
      # 外部スクリプトを呼び出し、戻り値（統計情報オブジェクト）を受け取る
      $Scores.Ssimu2 = & $Ssimu2ScriptFilePath `
        -DistortedFilePath $DistortedFilePath `
        -ReferenceFilePath $ReferenceFilePath `
        -RawJsonFilePath $RawJsonFilePath `
        -ClippedJsonFilePath $ClippedJsonFilePath
    }
    catch {
      Write-Warning "SSIMULACRA2 Script execution failed: $($_.Exception.Message)"
    }
  }

  # VMAF/SSIM/PSNR 計測 (外部スクリプト)
  # パス解決 (相対パスなら結合、絶対パスならそのまま)
  $VmafScriptFilePath = Resolve-ScriptFilePath -RelativeFilePath $Script:GlobalConfig.VmafScriptFilePath -BaseDirPath $PSScriptRoot
  
  # ガード節: 存在しない場合は早期リターン
  if (-not (Test-Path -LiteralPath $VmafScriptFilePath)) {
    return $Scores
  }

  Write-Host "${NewLine}[2/3] Measuring VMAF/SSIM/PSNR (via FFmpeg)..." -ForegroundColor Yellow
  try {
    # 外部スクリプトを呼び出し、戻り値（統計情報オブジェクト）を受け取る
    $FfmpegStats = & $VmafScriptFilePath `
      -DistortedFilePath $DistortedFilePath `
      -ReferenceFilePath $ReferenceFilePath `
      -VmafModelFilePath $Script:GlobalConfig.VmafModelFilePath `
      -LibvmafOptions $Script:GlobalConfig.LibvmafOptions `
      -FfmpegHwAccel $Script:GlobalConfig.FfmpegHwAccel
    
    # 結果の反映
    $Scores.VMAF = $FfmpegStats.VMAF
    $Scores.VmafModelName = $FfmpegStats.VmafModelName
    $Scores.SSIM = $FfmpegStats.SSIM
    $Scores.PSNR = $FfmpegStats.PSNR
  }
  catch {
    Write-Warning "VMAF/FFmpeg Script execution failed: $($_.Exception.Message)"
  }

  return $Scores
}

<#
.SYNOPSIS
  レポートの出力・保存処理を実行します。
#>
function Export-QualityReport {
  [CmdletBinding()]
  param(
    [string]$DistortedFilePath,
    [string]$SourceFilePath,
    [string]$ReferenceFilePath,
    [string]$OutputDirPath,
    [ReportMetrics]$Scores,
    [bool]$SaveReportJson
  )

  # メタデータ収集
  Write-Host "${NewLine}[3/3] Collecting metadata from Amatsukaze logs..." -ForegroundColor Yellow
  
  $EncoderInfo = try { [AmatsukazeLogInfo]::Parse($DistortedFilePath) } catch { [AmatsukazeLogInfo]::new() }
  $ProfileInfo = try { [AmatsukazeProfileInfo]::Parse($DistortedFilePath) } catch { [AmatsukazeProfileInfo]::new() }

  # 圧縮率計算
  $SourceSize = (Get-Item -LiteralPath $SourceFilePath).Length
  $DistortedSize = (Get-Item -LiteralPath $DistortedFilePath).Length
  $CompressionRatio = if ($SourceSize -gt 0) { ($DistortedSize / $SourceSize) * 100 } else { 0 }
  $SizeSummary = "{0:N2}% ({1:N1} MB -> {2:N1} MB)" -f $CompressionRatio, ($SourceSize / 1MB), ($DistortedSize / 1MB)

  # レポートデータ構築
  $ReportData = [Ordered]@{
    QualityMetrics = $Scores
    Compression    = @{ Ratio = $CompressionRatio; SrcSize = $SourceSize; EncSize = $DistortedSize }
    EncInfo        = $EncoderInfo
    ProfInfo       = $ProfileInfo
    FileInfo       = @{ 
      Reference = if (-not [string]::IsNullOrEmpty($ReferenceFilePath)) { Split-Path $ReferenceFilePath -Leaf } else { "-" }
      Distorted = (Split-Path $DistortedFilePath -Leaf) 
    }
    ReportDate     = (Get-Date -Format 'yyyy/MM/dd HH:mm:ss')
  }

  # パス決定
  $DistortedName = Split-Path $DistortedFilePath -Leaf
  $ReportFileName = "$DistortedName$($Script:GlobalConfig.UniqueSuffix)$($Script:GlobalConfig.ReportTextSuffix)"
  $ReportFilePath = Join-Path -Path $OutputDirPath -ChildPath $ReportFileName
  
  # 一時JSON出力
  $TempJsonFilePath = Join-Path ([System.IO.Path]::GetTempPath()) "$DistortedName.report.temp.json"
  $ReportData | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $TempJsonFilePath -Encoding UTF8

  # テキストレポート保存
  $ReportBody = New-ReportBodyText -ReportData $ReportData -SizeSummary $SizeSummary
  Set-Content -LiteralPath $ReportFilePath -Value $ReportBody -Encoding UTF8

  # JSONレポート保存 (オプション)
  if ($SaveReportJson) {
    $JsonReportFilePath = $ReportFilePath -replace ([regex]::Escape($Script:GlobalConfig.ReportTextSuffix) + "$"), $Script:GlobalConfig.ReportJsonSuffix
    Copy-Item -LiteralPath $TempJsonFilePath -Destination $JsonReportFilePath -Force
  }

  if (Test-Path -LiteralPath $TempJsonFilePath) { Remove-Item -LiteralPath $TempJsonFilePath -Force }
}

<#
.SYNOPSIS
  テキストレポートの本文を生成します。
#>
function New-ReportBodyText {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.Collections.IDictionary]$ReportData,

    [Parameter(Mandatory = $true)]
    [string]$SizeSummary
  )

  # データの展開
  $Scores = $ReportData.QualityMetrics
  $EncoderInfo = $ReportData.EncInfo
  $ProfileInfo = $ReportData.ProfInfo

  # テキスト生成
  $Ssimu2Text = Get-Ssimu2DetailText -ScoreObject $Scores.Ssimu2
  $ProfileText = Get-ProfileSettingsText -ProfileInfo $ProfileInfo

  $ReportBody = @"
===========================================================
 [Quality Metrics]
   SSIMULACRA2     : $Ssimu2Text
   VMAF Score      : $($Scores.VMAF) ($($Scores.VmafModelName))
   SSIM (All)      : $($Scores.SSIM)
   PSNR (Avg)      : $($Scores.PSNR)

 [Compression & Performance (main only)]
   Size Ratio      : $SizeSummary
   Bit Rate        : $($EncoderInfo.Bitrate) kbps
   Enc Speed       : $($EncoderInfo.FPS) fps
   Enc Time        : $($EncoderInfo.EncodingTime)

 [System Hardware & Encoder]
   CPU             : $($EncoderInfo.CPU)
   GPU             : $($EncoderInfo.GPU)
   Encoder Spec    : $($EncoderInfo.EncoderSpec)

 [Profile Settings]
$ProfileText

 [File Info]
   Distorted       : $($ReportData.FileInfo.Distorted)
   Reference       : $($ReportData.FileInfo.Reference)

 Report Date       : $($ReportData.ReportDate)
===========================================================
"@

  return $ReportBody
}

<#
.SYNOPSIS
  SSIMULACRA2 の詳細テキスト生成
#>
function Get-Ssimu2DetailText {
  param ($ScoreObject)

  if ($null -eq $ScoreObject -or $null -eq $ScoreObject.Average -or $ScoreObject.Average -eq "N/A") {
    return @"
N/A
   - Std Dev       : 
   - Median        : 
   - 5th %         : 
   - 95th %        : 
   - Min / Max     :    / 
"@
  }

  return @"
$($ScoreObject.Average)
   - Std Dev       : $($ScoreObject.StandardDeviation)
   - Median        : $($ScoreObject.Median)
   - 5th %         : $($ScoreObject.Percentile5)
   - 95th %        : $($ScoreObject.Percentile95)
   - Min / Max     : $($ScoreObject.Minimum) / $($ScoreObject.Maximum)
"@
}

<#
.SYNOPSIS
  プロファイル情報のテキスト生成
#>
function Get-ProfileSettingsText {
  param ([AmatsukazeProfileInfo]$ProfileInfo)

  $Lines = [System.Collections.Generic.List[string]]::new()
  $Lines.Add("   Profile Name    : $($ProfileInfo.ProfileName)")
  $Lines.Add("   Encoder         : $($ProfileInfo.Encoder)")
  $Lines.Add("   Parameters      : $($ProfileInfo.Params)")

  if ($ProfileInfo.FilterStatus -eq "Custom") {
    $Lines.Add("   Filter          : カスタムフィルタを設定")
    $Lines.Add("   MainFilter      : $($ProfileInfo.MainFilter)")
    $Lines.Add("   PostFilter      : $($ProfileInfo.PostFilter)")
    return $Lines -join "${NewLine}"
  }

  if ($ProfileInfo.FilterStatus -eq "No") {
    $Lines.Add("   Filter          : フィルタなし")
    return $Lines -join "${NewLine}"
  }

  $Lines.Add("   Filter          : フィルタを設定")
  $Lines.Add("   CUDA Process    : $($ProfileInfo.CudaProcess)")
  $Lines.Add("   DeInterlace     : $($ProfileInfo.Deinterlace)")
  $Lines.Add("   - Method        : $($ProfileInfo.DeinterlaceMethod)")

  switch ($ProfileInfo.DeinterlaceMethod) {
    "KFM" {
      $Lines.Add("   - SMDegrain NR  : $($ProfileInfo.SMDegrainNR)")
      $Lines.Add("   - DecombUCF     : $($ProfileInfo.DecombUCF)")
      $Lines.Add("   - Output FPS    : $($ProfileInfo.OutputFPS)")
      $Lines.Add("   - Frame Timing  : $($ProfileInfo.VFRTiming)")
    }
    "D3DVP" {
      $Lines.Add("   - D3DVP GPU     : $($ProfileInfo.D3dvpGpu)")
    }
    "QTGMC" {
      $Lines.Add("   - QTGMC Preset  : $($ProfileInfo.QTGMCPreset)")
    }
    "Yadif" {
      $Lines.Add("   - Output FPS    : $($ProfileInfo.OutputFPS)")
    }
    "AutoVfr" {
      $Lines.Add("   - 30fps         : $($ProfileInfo.AutoVfr30)")
      $Lines.Add("   - 60fps         : $($ProfileInfo.AutoVfr60)")
      $Lines.Add("   - SKIP          : $($ProfileInfo.AutoVfrSkip)")
      $Lines.Add("   - REF           : $($ProfileInfo.AutoVfrRef)")
      $Lines.Add("   - CROP          : $($ProfileInfo.AutoVfrCrop)")
    }
  }

  $Lines.Add("   Deblock         : $($ProfileInfo.Deblock) (Strength: $($ProfileInfo.DeblockStrength), Quality: $($ProfileInfo.DeblockQuality), Sharpen: $($ProfileInfo.DeblockSharpen))")

  $ResizeInfo = "No"
  if ($ProfileInfo.Resize -eq "Yes") {
    $ResizeInfo = "$($ProfileInfo.ResizeW) x $($ProfileInfo.ResizeH)"
  }
  $Lines.Add("   Resize          : $ResizeInfo")
  $Lines.Add("   Time Stability  : $($ProfileInfo.TimeStability)")
  $Lines.Add("   Reduce Banding  : $($ProfileInfo.ReduceBanding)")
  $Lines.Add("   Edge Enhance    : $($ProfileInfo.EdgeEnhance)")

  return $Lines -join "${NewLine}"
}

<#
.SYNOPSIS
  指定されたパスが相対パスの場合、ベースパスと結合して絶対パスにします。
#>
function Resolve-ScriptFilePath {
  param (
    [string]$RelativeFilePath,
    [string]$BaseDirPath
  )
  if ([string]::IsNullOrEmpty($RelativeFilePath)) { return $RelativeFilePath }
  
  # 絶対パスかどうか判定
  if ([System.IO.Path]::IsPathRooted($RelativeFilePath)) {
    return $RelativeFilePath
  }
  else {
    return Join-Path $BaseDirPath $RelativeFilePath
  }
}

<#
.SYNOPSIS
  拡張子なしのパスから、実在する動画ファイルのフルパスを取得します。
#>
function Get-VideoFilePath {
  [CmdletBinding()]
  param([string]$FilePathBase)

  # Amatsukazeが対応している拡張子を順番に試行する
  $TargetExtensions = @(".mkv", ".mp4", ".m2ts", ".ts")
  foreach ($Extension in $TargetExtensions) {
    $TestPath = "${FilePathBase}${Extension}"
    if (Test-Path -LiteralPath $TestPath -PathType Leaf) {
      return (Get-Item -LiteralPath $TestPath).FullName
    }
  }
  # 引数のパスのファイルが拡張子を補わずに存在する場合はそのまま返す
  if (Test-Path -LiteralPath $FilePathBase -PathType Leaf) {
    return (Get-Item -LiteralPath $FilePathBase).FullName
  }

  throw "[ERROR] Distorted file not found: $FilePathBase"
}

# =========================================================
# 実行エントリポイント
# =========================================================

Measure-EncodingQuality