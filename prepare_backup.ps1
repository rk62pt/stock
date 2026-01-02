Write-Host "Starting project cleanup for backup..."

# 1. Clean Flutter App
$flutterPath = ".\stock_flutter_app"
if (Test-Path $flutterPath) {
    Write-Host "Cleaning Flutter project..."
    Push-Location $flutterPath
    flutter clean
    Pop-Location
}

# 2. Clean Next.js App (stock-app)
$nodeAppPath = ".\stock-app"
if (Test-Path $nodeAppPath) {
    Write-Host "Cleaning Node.js project (stock-app)..."
    if (Test-Path "$nodeAppPath\node_modules") {
        Remove-Item "$nodeAppPath\node_modules" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed node_modules."
    }
    if (Test-Path "$nodeAppPath\.next") {
        Remove-Item "$nodeAppPath\.next" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed .next build folder."
    }
}

# 3. Clean stock-mobile (if applicable)
$mobileAppPath = ".\stock-mobile"
if (Test-Path $mobileAppPath) {
    if (Test-Path "$mobileAppPath\node_modules") {
        Write-Host "Cleaning stock-mobile..."
        Remove-Item "$mobileAppPath\node_modules" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Cleanup complete!"
Write-Host "You can now zip the 'Stock' folder and upload it to Google Drive."
Write-Host "Tip: When you download it on another computer:"
Write-Host "1. Flutter: Run 'flutter pub get'"
Write-Host "2. Node.js: Run 'npm install'"
