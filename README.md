# Report-EncodingQuality

`Amatsukaze` でエンコードした映像の画質を評価します(SSIMULACRA2 / VMAF)。  
評価対象とリファレンスを比較して画質劣化を数値化します。  
`Amatsukaze` のタスクログを解析し、圧縮効率・エンコード設定などをレポートします。

## 使い方
1. `Amatsukaze\bat` フォルダに `.ps1` `.cmd` ファイルを配置します。
2. `Report-EncodingQuality.ps1` `.DESCRIPTION` に従ってリファレンスを用意します。
3. `Amatsukaze` プロファイルで実行後バッチに `実行後_Report-EncodingQuality.cmd` を設定します。
4. `Amatsukaze` タスクをテストモードで実行して評価対象を出力します。
5. 画質評価レポート `.report.txt` が出力されます。  
オプション: 画質評価レポートに加えて、レポートに使用するJSONデータを保存

## 必要要件
* [Amatsukaze 改造版](https://github.com/rigaya/Amatsukaze): 1.0.4.7 以上
* [PowerShell](https://github.com/PowerShell/PowerShell): Core 7 以上
* [FFVship](https://codeberg.org/Line-fr/Vship): 環境変数 PATH が通っていること
* [FFmpeg](https://www.gyan.dev/ffmpeg/builds/): 環境変数 PATH が通っていること

## 謝辞
[rigaya](https://github.com/rigaya/)氏の多大な貢献に深く感謝いたします。
