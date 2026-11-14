# Builds Onda-compartir.zip: a copy of Onda anyone can install on Windows.
# Your own playlists are NOT included (playlists.js is replaced by an empty list); share lists with "⇪ Compartir" instead.
$src = Split-Path $PSScriptRoot -Parent
$tmp = Join-Path $env:TEMP ('onda-pkg-' + [guid]::NewGuid()); $root = Join-Path $tmp 'Onda'
New-Item -ItemType Directory -Force (Join-Path $root 'app'), (Join-Path $root 'desktop') | Out-Null
Copy-Item (Join-Path $src 'app\*') (Join-Path $root 'app') -Recurse -Force
Set-Content -Path (Join-Path $root 'app\playlists.js') -Value 'window.SPOTIFY_PLAYLISTS=[];' -Encoding ASCII
Copy-Item (Join-Path $PSScriptRoot 'server.ps1'), (Join-Path $PSScriptRoot 'onda.ps1'), (Join-Path $PSScriptRoot 'onda.vbs'), (Join-Path $PSScriptRoot 'install.ps1') (Join-Path $root 'desktop')
# friends' copies follow the same update source, so they update themselves too
$upd = Join-Path $PSScriptRoot 'update.txt'; if (Test-Path $upd) { Copy-Item $upd (Join-Path $root 'desktop') }
Set-Content -Path (Join-Path $root 'Instalar Onda.cmd') -Encoding ASCII -Value '@powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0desktop\install.ps1" & pause'
$leeme = @'
ONDA - tu musica, sin anuncios

Instalar (Windows):
 1. Descomprime este zip.
 2. Haz doble clic en "Instalar Onda.cmd".
 3. Abre Onda desde el icono del Escritorio.

Para escuchar canciones que no tienes en tu equipo, Onda usa el reproductor oficial de YouTube.
Cada persona necesita su propia clave gratuita de la API de YouTube:
 Google Cloud -> activa "YouTube Data API v3" -> Credenciales -> Crear credenciales -> Clave de API.
 Pegala en Onda -> Ajustes. No compartas tu clave con nadie.

Para recibir una lista de un amigo: Biblioteca -> Importar texto.
'@
Set-Content -Path (Join-Path $root 'LEEME.txt') -Value $leeme -Encoding UTF8
$zip = Join-Path $src 'Onda-compartir.zip'; if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path $root -DestinationPath $zip
Remove-Item $tmp -Recurse -Force
"Paquete creado: $zip"
