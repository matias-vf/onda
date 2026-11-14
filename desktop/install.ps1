# Installs Onda for the current user: copies it to %LOCALAPPDATA%\Onda and adds Desktop + Start menu shortcuts.
# Run again after changing the app to update the installed copy (your lists and settings are kept).
$src  = Split-Path $PSScriptRoot -Parent
$dest = Join-Path $env:LOCALAPPDATA 'Onda'
New-Item -ItemType Directory -Force (Join-Path $dest 'app') | Out-Null
Copy-Item (Join-Path $src 'app\*') (Join-Path $dest 'app') -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot 'server.ps1'), (Join-Path $PSScriptRoot 'onda.ps1'), (Join-Path $PSScriptRoot 'onda.vbs') $dest -Force
# where automatic updates come from (written by publish.ps1); without it Onda simply doesn't self-update
$upd = Join-Path $PSScriptRoot 'update.txt'; if (Test-Path $upd) { Copy-Item $upd $dest -Force }
$pl = Join-Path $dest 'app\playlists.js'; if (-not (Test-Path $pl)) { Set-Content $pl 'window.SPOTIFY_PLAYLISTS=[];' -Encoding ASCII }

# Icon: draw the Onda wave on an orange rounded square, save as a PNG-based .ico
Add-Type -AssemblyName System.Drawing
$s = 256; $bmp = New-Object Drawing.Bitmap $s, $s; $g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.Clear([Drawing.Color]::Transparent)
$rect = New-Object Drawing.Rectangle 0, 0, $s, $s
$brush = New-Object Drawing.Drawing2D.LinearGradientBrush $rect, ([Drawing.Color]::FromArgb(255,154,92)), ([Drawing.Color]::FromArgb(226,80,58)), 45
$path = New-Object Drawing.Drawing2D.GraphicsPath; $r = 56
$path.AddArc(0,0,$r*2,$r*2,180,90); $path.AddArc($s-$r*2,0,$r*2,$r*2,270,90); $path.AddArc($s-$r*2,$s-$r*2,$r*2,$r*2,0,90); $path.AddArc(0,$s-$r*2,$r*2,$r*2,90,90); $path.CloseFigure()
$g.FillPath($brush, $path)
$pen = New-Object Drawing.Pen ([Drawing.Color]::White), 22; $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
$g.DrawBezier($pen, 48,140, 78,85, 98,85, 128,140); $g.DrawBezier($pen, 128,140, 158,195, 178,195, 208,120)
$g.Dispose()
$ms = New-Object IO.MemoryStream; $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png); $png = $ms.ToArray()
$ico = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ico
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]1)
$w.Write([byte]0); $w.Write([byte]0); $w.Write([byte]0); $w.Write([byte]0); $w.Write([uint16]1); $w.Write([uint16]32)
$w.Write([uint32]$png.Length); $w.Write([uint32]22); $w.Write($png); $w.Flush()
[IO.File]::WriteAllBytes((Join-Path $dest 'onda.ico'), $ico.ToArray())

# Shortcuts
$sh = New-Object -ComObject WScript.Shell
foreach ($dir in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
  $lnk = $sh.CreateShortcut((Join-Path $dir 'Onda.lnk'))
  $lnk.TargetPath = "$env:WINDIR\System32\wscript.exe"
  $lnk.Arguments = "`"$dest\onda.vbs`""
  $lnk.WorkingDirectory = $dest
  $lnk.IconLocation = "$dest\onda.ico"
  $lnk.Description = 'Onda: tu música, sin anuncios'
  $lnk.Save()
}
"Onda instalada en $dest"
