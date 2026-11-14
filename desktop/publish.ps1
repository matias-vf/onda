# Publishes a new version of Onda: bumps the build number, commits and pushes to the update source (a git repository).
# Every installed Onda picks it up on its next start, or within an hour while open. No reinstall needed.
param([string]$Message = 'Nueva versión de Onda')
$src = Split-Path $PSScriptRoot -Parent; $vf = Join-Path $src 'app\version.json'
$v = Get-Content $vf -Raw | ConvertFrom-Json; $v.build = [int]$v.build + 1
($v | ConvertTo-Json -Compress -Depth 3) | Set-Content $vf -Encoding ASCII
git -C $src add -A
git -C $src commit -m "$Message (build $($v.build))"
git -C $src push
"Publicada la build $($v.build)"
