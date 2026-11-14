# Onda local server: serves the app folder on http://localhost:47800 (only reachable from this computer).
param([int]$Port = 47800, [string]$Root = (Join-Path $PSScriptRoot 'app'))
$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
$types = @{ '.html'='text/html; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.svg'='image/svg+xml';
            '.webmanifest'='application/manifest+json'; '.png'='image/png'; '.ico'='image/x-icon'; '.css'='text/css' }
$rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $restart = $false
  try {
    # /api/update: if update.txt names a source with a higher build in app/version.json, download the listed files.
    # Only files named in that list, only into the app folder or next to this script. Your playlists.js is never touched.
    if ($ctx.Request.Url.AbsolutePath -eq '/api/update') {
      $res = @{ status = 'off' }
      $base = Get-Content (Join-Path $PSScriptRoot 'update.txt') -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($base -and $base -match '^(https://|http://localhost:)') {
        $base = $base.Trim().TrimEnd('/'); $n = [DateTime]::UtcNow.Ticks
        $local = Get-Content (Join-Path $Root 'version.json') -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
        $remote = Invoke-RestMethod "$base/app/version.json?t=$n" -UseBasicParsing
        if ([int]$remote.build -gt [int]$local.build) {
          foreach ($f in $remote.files) {
            if ($f -notmatch '^(app|desktop)/[A-Za-z0-9._-]+$' -or $f -eq 'app/playlists.js') { continue }
            $target = if ($f.StartsWith('app/')) { Join-Path $Root $f.Substring(4) } else { Join-Path $PSScriptRoot $f.Substring(8) }
            Invoke-WebRequest "$base/$($f)?t=$n" -UseBasicParsing -OutFile "$target.new"
            Move-Item "$target.new" $target -Force
            if ($f -eq 'desktop/server.ps1') { $restart = $true }
          }
          ($remote | ConvertTo-Json -Depth 3) | Set-Content (Join-Path $Root 'version.json') -Encoding UTF8
          $res = @{ status = 'updated'; build = $remote.build; restart = $restart }
        } else { $res = @{ status = 'current'; build = $local.build } }
      }
      $b = [Text.Encoding]::UTF8.GetBytes(($res | ConvertTo-Json -Compress))
      $ctx.Response.ContentType = 'application/json; charset=utf-8'; $ctx.Response.OutputStream.Write($b, 0, $b.Length); continue
    }
    # /api/spotify?kind=playlist|track&id=<22-char id>: reads Spotify's public embed page (the browser can't, CORS) and returns "Artista - Canción" lines.
    if ($ctx.Request.Url.AbsolutePath -eq '/api/spotify') {
      $kind = $ctx.Request.QueryString['kind']; $id = $ctx.Request.QueryString['id']
      if (($kind -ne 'playlist' -and $kind -ne 'track') -or $id -notmatch '^[A-Za-z0-9]{22}$') { $ctx.Response.StatusCode = 400; continue }
      $h = [Text.Encoding]::UTF8.GetString((Invoke-WebRequest "https://open.spotify.com/embed/$kind/$id" -UseBasicParsing -UserAgent 'Mozilla/5.0').RawContentStream.ToArray())
      $e = ([regex]::Match($h, '<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', 'Singleline').Groups[1].Value | ConvertFrom-Json).props.pageProps.state.data.entity
      if ($kind -eq 'playlist') { $out = @{ name = $e.name; tracks = @($e.trackList | ForEach-Object { ("$($_.subtitle)" -replace [char]0xA0, ' ') + ' - ' + $_.title }) } }
      else { $out = @{ name = $e.name; tracks = @(((@($e.artists | ForEach-Object { $_.name })) -join ', ') + ' - ' + $e.name) } }
      $b = [Text.Encoding]::UTF8.GetBytes(($out | ConvertTo-Json -Compress -Depth 3))
      $ctx.Response.ContentType = 'application/json; charset=utf-8'; $ctx.Response.OutputStream.Write($b, 0, $b.Length); continue
    }
    $rel =[Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    if (-not $rel) { $rel = 'index.html' }
    $file = [IO.Path]::GetFullPath((Join-Path $rootFull $rel))
    # only files inside the app folder are served
    if ($file.StartsWith($rootFull) -and (Test-Path -LiteralPath $file -PathType Leaf)) {
      $bytes = [IO.File]::ReadAllBytes($file)
      $ctx.Response.ContentType = $types[[IO.Path]::GetExtension($file).ToLower()]
      $ctx.Response.Headers['Cache-Control'] = 'no-store'
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else { $ctx.Response.StatusCode = 404 }
  } catch { } finally { $ctx.Response.Close() }
  # the server itself was updated: hand over to the new version
  if ($restart) { $listener.Stop(); Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""; break }
}
