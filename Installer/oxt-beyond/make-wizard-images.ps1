<#
.SYNOPSIS
    Makes the wizard images of the OXT-Beyond installer from the OXT-Beyond
    icon art.

.DESCRIPTION
    Writes 24-bit BMP files to OutDir:

      wizard-image-<w>x<h>.bmp    for WizardImageFile: the tall image on the
                                  left of the Welcome and Setup Completed
                                  pages: the tall art (-Art, by default
                                  Installer\oxt-beyond\branding\art\
                                  oxt-beyond-wizard.png) scaled to fill it,
                                  or without tall art the icon and the
                                  product name on a dark background
      wizard-small-image-<n>.bmp  for WizardSmallImageFile: the square image
                                  in the top right corner of the other pages
                                  (the icon on white)

    in the sizes Inno Setup 6.6 and later use at 100% to 250% display scaling;
    Setup picks the closest one. Returns an object whose WizardImageFile and
    WizardSmallImageFile properties are the comma-separated file lists for
    those directives (tools/ci/build-installer.ps1 passes them to the
    compiler as defines), and whose Source property names the art used.

    The source art is the first of:
      1. -Source (a .png or .ico file)
      2. the largest square .png in Installer\oxt-beyond\branding (names
         containing "beyond" preferred)
      3. the largest image in ide\OXT-Beyond.ico
      4. the largest image in ide\OpenXTalk-lite_1024.ico, as a placeholder
         (a warning is printed, because that art says "Lite")

    Needs System.Drawing: Windows PowerShell 5.1, or PowerShell 7 on Windows.

.PARAMETER OutDir
    Folder for the images; created if missing. Existing images with the same
    names are replaced.

.PARAMETER RepoRoot
    Repository root. Default: two levels up from this script.

.PARAMETER Source
    A .png or .ico file to use instead of the search described above.

.PARAMETER Art
    A tall .png file for the tall image, instead of
    Installer\oxt-beyond\branding\art\oxt-beyond-wizard.png. It is scaled to
    cover each size and centred; the edges that do not fit are cut off.
.PARAMETER Title
    Text under the icon in the tall image. Default: OXT-Beyond.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutDir,
    [string]$RepoRoot,
    [string]$Source,
    [string]$Art,
    [string]$Title = 'OXT-Beyond'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

# Image area sizes at 100%, 125%, 150%, 200% and 250% scaling
# (Inno Setup help, WizardImageFile and WizardSmallImageFile)
$LargeSizes = @(@(202, 386), @(269, 515), @(336, 643), @(430, 824), @(534, 1022))
$SmallSizes = @(58, 77, 97, 124, 159)

# Tall image: vertical gradient, top and bottom colour
$BackTop = [System.Drawing.Color]::FromArgb(38, 48, 63)
$BackBottom = [System.Drawing.Color]::FromArgb(16, 21, 29)
$TitleColor = [System.Drawing.Color]::White
$SmallBack = [System.Drawing.Color]::White

if (-not $RepoRoot) { $RepoRoot = Join-Path $PSScriptRoot '..\..' }
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath

# --- Reading the art ---

function Test-PngSignature([byte[]]$Data, [int]$Offset) {
    return ($Data.Length -ge $Offset + 24 -and $Data[$Offset] -eq 0x89 -and $Data[$Offset + 1] -eq 0x50 -and
        $Data[$Offset + 2] -eq 0x4E -and $Data[$Offset + 3] -eq 0x47)
}

# Big-endian 32-bit integer (PNG header fields)
function Get-UInt32BE([byte[]]$Data, [int]$Offset) {
    return ([int64]$Data[$Offset] -shl 24) -bor ([int64]$Data[$Offset + 1] -shl 16) -bor
        ([int64]$Data[$Offset + 2] -shl 8) -bor [int64]$Data[$Offset + 3]
}

function Get-PngSize([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $head = New-Object byte[] 24
        if ($stream.Read($head, 0, 24) -ne 24 -or -not (Test-PngSignature $head 0)) { return $null }
    }
    finally { $stream.Dispose() }
    return @((Get-UInt32BE $head 16), (Get-UInt32BE $head 20))
}

function ConvertFrom-PngBytes([byte[]]$Bytes) {
    $ms = New-Object System.IO.MemoryStream(, $Bytes)
    try {
        $img = [System.Drawing.Image]::FromStream($ms)
        try { $bmp = New-Object System.Drawing.Bitmap($img) } finally { $img.Dispose() }
    }
    finally { $ms.Dispose() }
    return $bmp
}

# A 32-bit DIB from an .ico entry (bottom-up BGRA rows followed by the AND
# mask, which is ignored). Icons without any alpha are drawn opaque.
function ConvertFrom-IcoDib([byte[]]$Data, [int]$Offset) {
    $headerSize = [BitConverter]::ToInt32($Data, $Offset)
    $w = [BitConverter]::ToInt32($Data, $Offset + 4)
    $h = [BitConverter]::ToInt32($Data, $Offset + 8) -shr 1
    $bpp = [BitConverter]::ToUInt16($Data, $Offset + 14)
    if ($bpp -ne 32) { throw "Only 32-bit icon images are supported (found $bpp-bit)." }
    $stride = $w * 4
    $start = $Offset + $headerSize
    $buffer = New-Object byte[] ($stride * $h)
    for ($y = 0; $y -lt $h; $y++) {
        [Array]::Copy($Data, $start + ($h - 1 - $y) * $stride, $buffer, $y * $stride, $stride)
    }
    $hasAlpha = $false
    for ($i = 3; $i -lt $buffer.Length; $i += 4) {
        if ($buffer[$i] -ne 0) { $hasAlpha = $true; break }
    }
    if (-not $hasAlpha) {
        for ($i = 3; $i -lt $buffer.Length; $i += 4) { $buffer[$i] = 255 }
    }
    $format = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    $bmp = New-Object System.Drawing.Bitmap($w, $h, $format)
    $bits = $bmp.LockBits((New-Object System.Drawing.Rectangle(0, 0, $w, $h)), [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $format)
    try {
        for ($y = 0; $y -lt $h; $y++) {
            $row = [IntPtr]($bits.Scan0.ToInt64() + [int64]$y * $bits.Stride)
            [System.Runtime.InteropServices.Marshal]::Copy($buffer, $y * $stride, $row, $stride)
        }
    }
    finally { $bmp.UnlockBits($bits) }
    return $bmp
}

# The largest PNG or 32-bit image in an .ico file
function Read-IcoImage([string]$Path) {
    $data = [System.IO.File]::ReadAllBytes($Path)
    if ($data.Length -lt 6 -or [BitConverter]::ToUInt16($data, 0) -ne 0 -or [BitConverter]::ToUInt16($data, 2) -ne 1) {
        throw "$Path is not an .ico file."
    }
    $count = [BitConverter]::ToUInt16($data, 4)
    $best = $null
    for ($i = 0; $i -lt $count; $i++) {
        $entry = 6 + 16 * $i
        $size = [int][BitConverter]::ToUInt32($data, $entry + 8)
        $offset = [int][BitConverter]::ToUInt32($data, $entry + 12)
        if ($offset + $size -gt $data.Length) { continue }
        $png = Test-PngSignature $data $offset
        if ($png) {
            $width = [int](Get-UInt32BE $data ($offset + 16))
        }
        elseif ([BitConverter]::ToUInt16($data, $offset + 14) -eq 32) {
            $width = [BitConverter]::ToInt32($data, $offset + 4)
        }
        else {
            continue
        }
        if ($null -eq $best -or $width -gt $best.Width -or ($width -eq $best.Width -and $png -and -not $best.Png)) {
            $best = New-Object PSObject -Property @{ Width = $width; Png = $png; Offset = $offset; Size = $size }
        }
    }
    if ($null -eq $best) { throw "$Path has no PNG or 32-bit image." }
    if ($best.Png) {
        $bytes = New-Object byte[] $best.Size
        [Array]::Copy($data, $best.Offset, $bytes, 0, $best.Size)
        return (ConvertFrom-PngBytes $bytes)
    }
    return (ConvertFrom-IcoDib $data $best.Offset)
}

function Read-Art([string]$Path) {
    if ($Path -like '*.ico') { return (Read-IcoImage $Path) }
    return (ConvertFrom-PngBytes ([System.IO.File]::ReadAllBytes($Path)))
}

# --- Choosing the art ---
$placeholder = $false
if ($Source) {
    $artPath = (Resolve-Path -LiteralPath $Source).ProviderPath
}
else {
    $artPath = $null
    $brandingDir = Join-Path $PSScriptRoot 'branding'
    if (Test-Path -LiteralPath $brandingDir -PathType Container) {
        $candidates = @()
        foreach ($file in @(Get-ChildItem -LiteralPath $brandingDir -Filter '*.png' -File -Recurse)) {
            $size = Get-PngSize $file.FullName
            if ($null -eq $size -or $size[0] -ne $size[1] -or $size[0] -lt 128) { continue }
            $candidates += New-Object PSObject -Property @{
                Path = $file.FullName
                Beyond = ($file.Name -like '*beyond*')
                Area = [int64]$size[0] * $size[1]
            }
        }
        $pick = $candidates | Sort-Object -Property @{ Expression = 'Beyond'; Descending = $true }, @{ Expression = 'Area'; Descending = $true } | Select-Object -First 1
        if ($pick) { $artPath = $pick.Path }
    }
    if (-not $artPath) {
        $icon = Join-Path $RepoRoot 'ide\OXT-Beyond.ico'
        if (Test-Path -LiteralPath $icon -PathType Leaf) { $artPath = $icon }
    }
    if (-not $artPath) {
        $icon = Join-Path $RepoRoot 'ide\OpenXTalk-lite_1024.ico'
        if (-not (Test-Path -LiteralPath $icon -PathType Leaf)) {
            throw 'No icon art found (Installer\oxt-beyond\branding\*.png, ide\OXT-Beyond.ico or ide\OpenXTalk-lite_1024.ico).'
        }
        $artPath = $icon
        $placeholder = $true
        Write-Warning "No OXT-Beyond art found; making placeholder wizard images from $icon."
    }
}

if (-not $Art) {
    $defaultArt = Join-Path $PSScriptRoot 'branding\art\oxt-beyond-wizard.png'
    if (Test-Path -LiteralPath $defaultArt -PathType Leaf) { $Art = $defaultArt }
}
$tall = $null
$tallPath = $null
if ($Art) {
    $tallPath = (Resolve-Path -LiteralPath $Art).ProviderPath
    Write-Host "Tall wizard image art: $tallPath"
    $tall = ConvertFrom-PngBytes ([System.IO.File]::ReadAllBytes($tallPath))
}

Write-Host "Wizard image art: $artPath"
$art = Read-Art $artPath
Write-Host ("  {0} x {1} pixels" -f $art.Width, $art.Height)

# --- Drawing ---
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).ProviderPath

# Clamp the edges when scaling, so no border from outside the image bleeds in
$attributes = New-Object System.Drawing.Imaging.ImageAttributes
$attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)

function New-Canvas([int]$Width, [int]$Height) {
    $bmp = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    return @($bmp, $g)
}

function Add-Art($Graphics, [int]$X, [int]$Y, [int]$Size) {
    $dest = New-Object System.Drawing.Rectangle($X, $Y, $Size, $Size)
    $Graphics.DrawImage($art, $dest, 0, 0, $art.Width, $art.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
}

$large = @()
$small = @()
try {
    foreach ($s in $LargeSizes) {
        $w = $s[0]; $h = $s[1]
        $canvas = New-Canvas $w $h
        $bmp = $canvas[0]; $g = $canvas[1]
        try {
            if ($tall) {
                # The tall art, scaled to cover the image and centred
                $scale = [Math]::Max($w / $tall.Width, $h / $tall.Height)
                $dw = [int][Math]::Ceiling($tall.Width * $scale)
                $dh = [int][Math]::Ceiling($tall.Height * $scale)
                $dest = New-Object System.Drawing.Rectangle([int](($w - $dw) / 2), [int](($h - $dh) / 2), $dw, $dh)
                $g.DrawImage($tall, $dest, 0, 0, $tall.Width, $tall.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
                $path = Join-Path $OutDir ('wizard-image-{0}x{1}.bmp' -f $w, $h)
                $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Bmp)
                $large += $path
                continue
            }
            $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
            $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $BackTop, $BackBottom, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
            try { $g.FillRectangle($brush, $rect) } finally { $brush.Dispose() }

            # The icon with the title under it, as one block a little above
            # the middle
            $iconSize = [int][Math]::Round($w * 0.8)
            $gap = [int][Math]::Round($h * 0.04)
            $font = $null
            $textHeight = 0
            if ($Title) {
                $fontSize = [single]($w * 0.13)
                $font = New-Object System.Drawing.Font('Segoe UI', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
                while ($g.MeasureString($Title, $font).Width -gt $w * 0.9 -and $fontSize -gt 6) {
                    $font.Dispose()
                    $fontSize = [single]($fontSize * 0.92)
                    $font = New-Object System.Drawing.Font('Segoe UI', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
                }
                $textHeight = [int][Math]::Ceiling($g.MeasureString($Title, $font).Height)
            }
            $blockHeight = $iconSize + $(if ($font) { $gap + $textHeight } else { 0 })
            $iconTop = [int][Math]::Round(($h - $blockHeight) * 0.42)
            Add-Art $g ([int](($w - $iconSize) / 2)) $iconTop $iconSize

            if ($font) {
                $format = New-Object System.Drawing.StringFormat
                $format.Alignment = [System.Drawing.StringAlignment]::Center
                $textBrush = New-Object System.Drawing.SolidBrush($TitleColor)
                try {
                    $textRect = New-Object System.Drawing.RectangleF(0, [single]($iconTop + $iconSize + $gap), $w, [single]$textHeight)
                    $g.DrawString($Title, $font, $textBrush, $textRect, $format)
                }
                finally {
                    $textBrush.Dispose(); $format.Dispose(); $font.Dispose()
                }
            }
            $path = Join-Path $OutDir ('wizard-image-{0}x{1}.bmp' -f $w, $h)
            $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Bmp)
            $large += $path
        }
        finally {
            $g.Dispose(); $bmp.Dispose()
        }
    }

    foreach ($n in $SmallSizes) {
        $canvas = New-Canvas $n $n
        $bmp = $canvas[0]; $g = $canvas[1]
        try {
            $g.Clear($SmallBack)
            $margin = [int][Math]::Round($n * 0.04)
            Add-Art $g $margin $margin ($n - 2 * $margin)
            $path = Join-Path $OutDir ('wizard-small-image-{0}.bmp' -f $n)
            $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Bmp)
            $small += $path
        }
        finally {
            $g.Dispose(); $bmp.Dispose()
        }
    }
}
finally {
    $attributes.Dispose()
    $art.Dispose()
    if ($tall) { $tall.Dispose() }
}

Write-Host "Wrote $($large.Count + $small.Count) wizard images to $OutDir"
New-Object PSObject -Property @{
    WizardImageFile = ($large -join ',')
    WizardSmallImageFile = ($small -join ',')
    Source = $artPath
    Art = $tallPath
    Placeholder = $placeholder
}
