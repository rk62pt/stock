Write-Host "Starting project cleanup for backup..."

# 1. Clean Flutter App
$flutterPath = ".\stock_flutter_app"
if (Test-Path $flutterPath) {
    Write-Host "Cleaning Flutter project..."
    Push-Location $flutterPath
    flutter clean
    Pop-Location
}


Write-Host "Cleanup complete!"
Write-Host "You can now zip the 'Stock' folder and upload it to Google Drive."
Write-Host "Tip: When you download it on another computer:"
Write-Host "1. Flutter: Run 'flutter pub get'"
Write-Host "2. Node.js: Run 'npm install'"
