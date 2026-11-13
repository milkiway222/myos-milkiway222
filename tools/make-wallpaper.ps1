# Генерирует обои MyOS (1920x1080 PNG).
# Запуск: powershell -ExecutionPolicy Bypass -File .\tools\make-wallpaper.ps1
[CmdletBinding()]
param(
    [string]$OutFile = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not $OutFile) {
    $OutFile = Join-Path $PSScriptRoot '..\iso\airootfs\usr\share\wallpapers\MyOS\contents\images\1920x1080.png'
}
$OutFile = [IO.Path]::GetFullPath($OutFile)
New-Item -ItemType Directory -Path (Split-Path -Parent $OutFile) -Force | Out-Null

$width = 1920
$height = 1080
$bmp = New-Object Drawing.Bitmap($width, $height)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

# Фон: глубокий синий градиент
$rect = New-Object Drawing.Rectangle(0, 0, $width, $height)
$bg = New-Object Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [Drawing.Color]::FromArgb(8, 12, 24),
    [Drawing.Color]::FromArgb(16, 58, 102),
    35.0
)
$g.FillRectangle($bg, $rect)

# Мягкое свечение
$glow = New-Object Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(900, -300, 1400, 1400)
$pathBrush = New-Object Drawing.Drawing2D.PathGradientBrush($glow)
$pathBrush.CenterColor = [Drawing.Color]::FromArgb(70, 40, 130, 220)
$pathBrush.SurroundColors = @([Drawing.Color]::FromArgb(0, 40, 130, 220))
$g.FillPath($pathBrush, $glow)

$glow2 = New-Object Drawing.Drawing2D.GraphicsPath
$glow2.AddEllipse(-500, 600, 1200, 1200)
$pathBrush2 = New-Object Drawing.Drawing2D.PathGradientBrush($glow2)
$pathBrush2.CenterColor = [Drawing.Color]::FromArgb(45, 20, 90, 160)
$pathBrush2.SurroundColors = @([Drawing.Color]::FromArgb(0, 20, 90, 160))
$g.FillPath($pathBrush2, $glow2)

# Тонкая сетка
$pen = New-Object Drawing.Pen([Drawing.Color]::FromArgb(14, 255, 255, 255), 1)
for ($x = 0; $x -le $width; $x += 80) { $g.DrawLine($pen, $x, 0, $x, $height) }
for ($y = 0; $y -le $height; $y += 80) { $g.DrawLine($pen, 0, $y, $width, $y) }

# Заголовок
$titleFormat = New-Object Drawing.StringFormat
$titleFormat.Alignment = [Drawing.StringAlignment]::Center
$titleFormat.LineAlignment = [Drawing.StringAlignment]::Center

$titleFont = New-Object Drawing.Font('Segoe UI', 170, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
$titleRect = New-Object Drawing.RectangleF(0, 380, $width, 240)
$shadowBrush = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(120, 0, 0, 0))
$g.DrawString('MyOS', $titleFont, $shadowBrush, $titleRect, $titleFormat)
$titleRect.Offset(0, -6)
$g.DrawString('MyOS', $titleFont, [Drawing.Brushes]::White, $titleRect, $titleFormat)

# Акцентная линия
$accentPen = New-Object Drawing.Pen([Drawing.Color]::FromArgb(90, 120, 200, 255), 3)
$g.DrawLine($accentPen, 830, 660, 1090, 660)

# Подзаголовок
$subFont = New-Object Drawing.Font('Segoe UI', 42, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$subFormat = New-Object Drawing.StringFormat
$subFormat.Alignment = [Drawing.StringAlignment]::Center
$subRect = New-Object Drawing.RectangleF(0, 690, $width, 80)
$subBrush = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(200, 210, 225, 245))
$g.DrawString('твоя система — твои правила', $subFont, $subBrush, $subRect, $subFormat)

# Подпись
$smallFont = New-Object Drawing.Font('Segoe UI', 24, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$smallFormat = New-Object Drawing.StringFormat
$smallFormat.Alignment = [Drawing.StringAlignment]::Near
$smallRect = New-Object Drawing.RectangleF(80, 990, 700, 40)
$smallBrush = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(120, 180, 200, 230))
$g.DrawString('MyOS • Arch-based', $smallFont, $smallBrush, $smallRect, $smallFormat)

$bmp.Save($OutFile, [Drawing.Imaging.ImageFormat]::Png)

$g.Dispose()
$bg.Dispose()
$bmp.Dispose()
$pen.Dispose()
$titleFont.Dispose()
$subFont.Dispose()
$smallFont.Dispose()
$shadowBrush.Dispose()
$subBrush.Dispose()
$smallBrush.Dispose()

Write-Host "Обои сохранены: $OutFile"
