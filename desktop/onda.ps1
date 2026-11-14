# Starts the local server if it is not running yet, then opens Onda in its own app window (Edge, else Chrome).
$port = 47800
$up = $false
try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1', $port); $up = $true; $c.Close() } catch { }
if (-not $up) {
  Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSScriptRoot\server.ps1`""
  for ($i = 0; $i -lt 20 -and -not $up; $i++) {
    Start-Sleep -Milliseconds 250
    try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1', $port); $up = $true; $c.Close() } catch { }
  }
}
$url = "http://localhost:$port/"
try { Start-Process msedge -ArgumentList "--app=$url" -ErrorAction Stop }
catch { try { Start-Process chrome -ArgumentList "--app=$url" -ErrorAction Stop } catch { Start-Process $url } }
