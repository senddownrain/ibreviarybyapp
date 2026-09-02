$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== Starting Flutter Environment Check ===" -ForegroundColor Yellow

# 1. Check Flutter installation
Write-Host "`n[1/6] Checking Flutter SDK..." -ForegroundColor Yellow
$flutterCheck = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCheck) {
    Write-Host "Error: Flutter not found in your PATH." -ForegroundColor Red
    Write-Host "Please download Flutter SDK and add flutter\bin to system PATH." -ForegroundColor Cyan
    Exit
} else {
    Write-Host "Flutter is installed." -ForegroundColor Green
    flutter --version
}

# 2. Diagnostics
Write-Host "`n[2/6] Running flutter doctor..." -ForegroundColor Yellow
flutter doctor

# 3. Android Licenses
Write-Host "`n[3/6] Accepting Android SDK Licenses..." -ForegroundColor Yellow
echo "y" | flutter doctor --android-licenses

# 4. Fetch Dependencies
Write-Host "`n[4/6] Fetching project dependencies (pub get)..." -ForegroundColor Yellow
if (Test-Path "pubspec.yaml") {
    flutter pub get
    Write-Host "Dependencies downloaded successfully." -ForegroundColor Green
} else {
    Write-Host "Warning: pubspec.yaml not found in this directory!" -ForegroundColor Red
    Write-Host "Make sure you run this script from the root of your Flutter project." -ForegroundColor Cyan
}

# 5. Check and Launch Android Emulator
Write-Host "`n[5/6] Checking available Android Emulators..." -ForegroundColor Yellow
$emulators = flutter emulators

if ($emulators -match "No emulators available") {
    Write-Host "No emulators found." -ForegroundColor Red
    Write-Host "Tip: Open Android Studio -> Device Manager and create a virtual device (AVD)." -ForegroundColor Cyan
} else {
    $emulatorLine = $emulators | Where-Object { $_ -match "•" } | Select-Object -First 1
    if ($emulatorLine) {
        $emulatorId = ($emulatorLine -split "•")[0].Trim()
        Write-Host "Found emulator: $emulatorId. Launching..." -ForegroundColor Green
        Start-Process flutter -ArgumentList "emulators --launch $emulatorId" -WindowStyle Hidden
    }
}

# 6. Check Ready Devices
Write-Host "`n[6/6] Available devices (flutter devices):" -ForegroundColor Yellow
flutter devices

Write-Host "`n=== Check Complete! ===" -ForegroundColor Green
Write-Host "To run your app, type: flutter run" -ForegroundColor Yellow
