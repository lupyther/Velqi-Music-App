# Build completo de Android: paso 1 (serious_python) + trim seguro + paso 2 (flutter build)
$ErrorActionPreference = "Stop"
$root = "C:\Users\Admin\Desktop\Nueva carpeta\Harmony-Music"
Set-Location $root

Write-Host "== PASO 1: Empaquetar Python con serious_python (instala yt-dlp fresco) =="
$env:SERIOUS_PYTHON_SITE_PACKAGES = "$root\build\python-site-packages"

dart run serious_python:main package python `
  --platform Android `
  --asset assets/python_app.zip `
  -r "yt-dlp,ytmusicapi==1.12.1"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Paso 1 fallo. Abortando."
    exit 1
}

Write-Host ""
Write-Host "== PASO 1.5: Aplicar trim seguro (solo _extractors.py, sin borrar archivos) =="
python scripts/trim_ytdlp.py build/python-site-packages

Write-Host ""
Write-Host "== PASO 1.6: Recrear python_app.zip limpio (sin site-packages.zip innecesario) =="
if (Test-Path "assets/python_app.zip") { Remove-Item "assets/python_app.zip" -Force }
Compress-Archive -Path "python\main.py","python\ytdlp_backend.py","python\ytmusic_backend.py","python\cookies.txt" `
    -DestinationPath "assets\python_app.zip" -Force
Write-Host "  python_app.zip recreado"

Write-Host ""
Write-Host "== PASO 2: Compilar APKs split por ABI =="
flutter build apk --release --split-per-abi

Write-Host ""
Write-Host "== FIN: APKs en build\app\outputs\flutter-apk\ =="
Get-ChildItem "build\app\outputs\flutter-apk\" -Filter "*.apk" | `
    Select-Object Name, @{N='SizeMB';E={[math]::Round($_.Length/1MB,1)}}
