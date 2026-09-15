param(
    [int]$BootTimeoutSeconds = 480,
    [int]$SettingsTimeoutSeconds = 40
)

$ErrorActionPreference = 'Stop'
$avdName = 'Pixel7_API34_Audit'
$imagePackage = 'system-images;android-34;google_apis;x86_64'
$repo = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $repo 'audit-evidence\emulator'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$log = Join-Path $evidence 'recreation.log'
Set-Content -LiteralPath $log -Value "Android audit AVD recreation: $(Get-Date -Format o)" -Encoding UTF8

function Write-Log([string]$message) {
    Write-Host $message
    Add-Content -LiteralPath $log -Value $message -Encoding UTF8
}
function Fail([string]$message) {
    Write-Log "BLOCKER: $message"
    Set-Content -LiteralPath (Join-Path $evidence 'blocker.log') -Value $message -Encoding UTF8
    throw $message
}
function Run([string]$exe, [string[]]$arguments) {
    $output = & $exe @arguments 2>&1 | Out-String
    $code = $LASTEXITCODE
    Add-Content -LiteralPath $log -Value "$exe $($arguments -join ' ')`n$output" -Encoding UTF8
    if ($code -ne 0) { Fail "Command failed ($code): $exe $($arguments -join ' ')`n$output" }
    return $output
}
function Adb([string[]]$arguments) { return Run $adb $arguments }
function TargetAdb([string[]]$arguments) { return Adb (@('-s', $script:serial) + $arguments) }
function Capture-SettingsScreenshot {
    $remote = '/data/local/tmp/settings-clean-boot.png'
    $capture = & $adb -s $script:serial shell screencap -p $remote 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { Write-Log "Settings screenshot unavailable: $capture"; return }
    $pull = & $adb -s $script:serial pull $remote (Join-Path $evidence 'settings-clean-boot.png') 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { Write-Log "Settings screenshot pull failed: $pull" }
}
function Devices {
    $output = & $adb devices 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { Fail "adb devices failed: $output" }
    return $output
}
function Get-AuditSerials {
    $result = @()
    foreach ($line in ((Devices) -split "`r?`n")) {
        if ($line -match '^(emulator-\d+)\s+(device|offline)') {
            $candidateSerial = $Matches[1]
            $nameOutput = & $adb -s $candidateSerial emu avd name 2>&1 | Out-String
            if ($nameOutput -match "(?m)^$([regex]::Escape($avdName))\s*$") { $result += $candidateSerial }
        }
    }
    return $result
}
function Stop-AuditAvd {
    foreach ($target in @(Get-AuditSerials)) {
        Write-Log "Stopping $avdName on $target"
        & $adb -s $target emu kill 2>&1 | Out-Null
    }
    $deadline = (Get-Date).AddSeconds(45)
    while ((@(Get-AuditSerials).Count -gt 0) -and ((Get-Date) -lt $deadline)) { Start-Sleep -Seconds 2 }
    if (@(Get-AuditSerials).Count -gt 0) { Fail "Existing $avdName did not stop" }
}
function Wait-Boot {
    $deadline = (Get-Date).AddSeconds($BootTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        foreach ($candidate in @(Get-AuditSerials)) {
            $state = & $adb -s $candidate get-state 2>$null | Out-String
            if ($state.Trim() -ne 'device') { continue }
            $boot = & $adb -s $candidate shell getprop sys.boot_completed 2>$null | Out-String
            if ($boot.Trim() -eq '1') { $script:serial = $candidate; return $true }
        }
        Start-Sleep -Seconds 3
    }
    return $false
}
function Check-Settings {
    $bootAnrs = & $adb -s $script:serial logcat -b events -d -t 1500 2>&1 | Select-String 'am_anr.*com\.android\.(systemui|settings)' | Out-String
    if ($bootAnrs) {
        Set-Content -LiteralPath (Join-Path $evidence 'blocker-diagnostics.log') -Value $bootAnrs -Encoding UTF8
        Write-Log "System UI ANR during clean boot: $bootAnrs"
        return $false
    }
    TargetAdb @('logcat', '-c') | Out-Null
    TargetAdb @('shell', 'am', 'start', '-a', 'android.settings.SETTINGS') | Out-Null
    $deadline = (Get-Date).AddSeconds($SettingsTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        $focus = & $adb -s $script:serial shell dumpsys window 2>&1 | Select-String 'mCurrentFocus' | Select-Object -First 1 | Out-String
        $state = TargetAdb @('get-state')
        if ($state.Trim() -ne 'device') { return $false }
        $anrEvents = & $adb -s $script:serial logcat -b events -d -t 1000 2>&1 | Select-String 'am_anr.*com\.android\.(systemui|settings)' | Out-String
        if ($anrEvents) {
            Set-Content -LiteralPath (Join-Path $evidence 'blocker-diagnostics.log') -Value $anrEvents -Encoding UTF8
            Write-Log "Android Settings/System UI ANR: $anrEvents"
            Capture-SettingsScreenshot
            return $false
        }
        if ($focus -match 'mCurrentFocus=.*com\.android\.settings') {
            $errors = TargetAdb @('logcat', '-d', '-t', '500', '-v', 'brief')
            Set-Content -LiteralPath (Join-Path $evidence 'settings-diagnostics.log') -Value $errors -Encoding UTF8
            if ($errors -match '(?i)(ANR in com\.android\.settings|ANR in com\.android\.systemui|Process: com\.android\.systemui)') { return $false }
            Capture-SettingsScreenshot
            return $true
        }
    }
    return $false
}
function Start-AuditAvd([string]$gpuMode) {
    Write-Log "Launching $avdName with -no-snapshot -wipe-data -gpu $gpuMode"
    $args = @("-avd", $avdName, '-no-snapshot', '-wipe-data', '-gpu', $gpuMode)
    $process = Start-Process -FilePath $emulator -ArgumentList $args -PassThru
    if (-not (Wait-Boot)) {
        Write-Log "Boot timed out with GPU $gpuMode (emulator PID $($process.Id))"
        Stop-AuditAvd
        return $false
    }
    Write-Log "Boot PASS: $script:serial, sys.boot_completed=1"
    if (-not (Check-Settings)) {
        Write-Log "Settings/System UI FAIL with GPU $gpuMode"
        Stop-AuditAvd
        return $false
    }
    Write-Log "Settings/System UI PASS with GPU $gpuMode"
    $script:gpuMode = $gpuMode
    return $true
}

$sdkCandidates = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME)
$flutterConfig = & flutter config --list 2>$null | Out-String
if ($flutterConfig -match '(?m)^\s*android-sdk:\s*(.+?)\s*$') { $sdkCandidates += $Matches[1] }
if ($env:LOCALAPPDATA) { $sdkCandidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk') }
$sdk = $sdkCandidates | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'cmdline-tools')) } | Select-Object -First 1
if (-not $sdk) { Fail 'Android SDK with cmdline-tools was not found' }
$sdk = (Resolve-Path -LiteralPath $sdk).Path
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'
$cmdline = Get-ChildItem -LiteralPath (Join-Path $sdk 'cmdline-tools') -Directory -ErrorAction SilentlyContinue |
    Where-Object { (Test-Path (Join-Path $_.FullName 'bin\sdkmanager.bat')) -and (Test-Path (Join-Path $_.FullName 'bin\avdmanager.bat')) } |
    Sort-Object @{ Expression = { if ($_.Name -eq 'latest') { 0 } else { 1 } } }, Name |
    Select-Object -First 1
if (-not $cmdline) { Fail 'sdkmanager.bat and avdmanager.bat were not found in cmdline-tools' }
$sdkmanager = Join-Path $cmdline.FullName 'bin\sdkmanager.bat'
$avdmanager = Join-Path $cmdline.FullName 'bin\avdmanager.bat'
foreach ($package in @('platform-tools', 'emulator')) {
    $toolPath = if ($package -eq 'platform-tools') { $adb } else { $emulator }
    if (-not (Test-Path -LiteralPath $toolPath)) {
        Write-Log "Installing missing SDK package: $package"
        Run $sdkmanager @('--sdk_root=' + $sdk, $package) | Out-Null
    }
    if (-not (Test-Path -LiteralPath $toolPath)) { Fail "Missing SDK tool after install: $toolPath" }
}
Write-Log "SDK: $sdk"
Write-Log "Emulator version: $(Run $emulator @('-version'))"
$acceleration = Run $emulator @('-accel-check')
if ($acceleration -notmatch '(?i)(installed and usable|acceleration.*supported)') { Fail "Acceleration unavailable: $acceleration" }
Write-Log "Acceleration PASS: $acceleration"

Stop-AuditAvd
$knownAvds = Run $avdmanager @('list', 'avd')
if ($knownAvds -match "(?m)^\s*Name:\s*$([regex]::Escape($avdName))\s*$") {
    Run $avdmanager @('delete', 'avd', '-n', $avdName) | Out-Null
}
$avdDir = Join-Path $env:USERPROFILE ".android\avd\$avdName.avd"
$avdIni = Join-Path $env:USERPROFILE ".android\avd\$avdName.ini"
if (Test-Path -LiteralPath $avdDir) { Remove-Item -LiteralPath $avdDir -Recurse -Force }
if (Test-Path -LiteralPath $avdIni) { Remove-Item -LiteralPath $avdIni -Force }
Write-Log "Removed only stale artifacts for $avdName"

$imageDir = Join-Path $sdk 'system-images\android-34\google_apis\x86_64'
if (-not (Test-Path (Join-Path $imageDir 'source.properties'))) {
    Write-Log "Installing $imagePackage"
    $installOutput = & $sdkmanager ('--sdk_root=' + $sdk) $imagePackage 2>&1 | Out-String
    Add-Content -LiteralPath $log -Value $installOutput -Encoding UTF8
    if ($LASTEXITCODE -ne 0 -and $installOutput -match '(?i)licen[cs]e') {
        Write-Log 'Accepting standard Android SDK licenses via sdkmanager --licenses'
        @('y') * 30 | & $sdkmanager ('--sdk_root=' + $sdk) --licenses 2>&1 | Out-Null
        $installOutput = & $sdkmanager ('--sdk_root=' + $sdk) $imagePackage 2>&1 | Out-String
        Add-Content -LiteralPath $log -Value $installOutput -Encoding UTF8
    }
    if ($LASTEXITCODE -ne 0) { Fail "System image install failed: $installOutput" }
}
if (-not (Test-Path (Join-Path $imageDir 'source.properties'))) { Fail "System image missing: $imagePackage" }
Run $avdmanager @('create', 'avd', '-n', $avdName, '-k', $imagePackage, '-d', 'pixel_7', '--force') | Out-Null
if (-not (Test-Path -LiteralPath $avdDir)) { Fail "AVD directory missing: $avdDir" }
$configPath = Join-Path $avdDir 'config.ini'
if (-not (Test-Path -LiteralPath $configPath)) { Fail 'AVD config.ini is missing' }
$config = Get-Content -LiteralPath $configPath
$hostCores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum
$avdCores = if ($hostCores -ge 6) { 4 } else { 2 }
$settings = [ordered]@{'hw.ramSize'='4096'; 'hw.cpu.ncore'="$avdCores"; 'hw.keyboard'='yes'; 'snapshot.present'='false'}
foreach ($key in $settings.Keys) {
    $line = "$key=$($settings[$key])"
    if ($config -match "^$([regex]::Escape($key))=") { $config = $config -replace "^$([regex]::Escape($key))=.*$", $line }
    else { $config += $line }
}
Set-Content -LiteralPath $configPath -Value $config -Encoding ASCII
Write-Log "AVD created: $avdName; image=$imagePackage; profile=pixel_7; host cores=$hostCores; AVD cores=$avdCores"
Write-Log "Config: $(Get-Content -LiteralPath $configPath | Select-String '^(hw.ramSize|hw.cpu.ncore|hw.keyboard|hw.lcd.width|hw.lcd.height|hw.lcd.density|snapshot.present)=')"

if (-not (Start-AuditAvd 'auto')) {
    Write-Log 'Trying the single documented GPU fallback: software'
    if (-not (Start-AuditAvd 'software')) { Fail 'Clean boot or Settings failed with both GPU auto and software' }
}
Remove-Item -LiteralPath (Join-Path $evidence 'blocker.log') -ErrorAction SilentlyContinue

$deviceInfo = @(
    "serial=$script:serial", "gpu=$script:gpuMode", "sdk=$sdk", "avd=$avdName", "image=$imagePackage",
    "android=$(TargetAdb @('shell','getprop','ro.build.version.release'))",
    "api=$(TargetAdb @('shell','getprop','ro.build.version.sdk'))",
    "physical=$(TargetAdb @('shell','wm','size'))",
    "density=$(TargetAdb @('shell','wm','density'))"
) -join "`n"
Set-Content -LiteralPath (Join-Path $evidence 'device-info.txt') -Value $deviceInfo -Encoding UTF8
Write-Log $deviceInfo
$flutterDevices = Run 'flutter' @('devices')
Set-Content -LiteralPath (Join-Path $evidence 'flutter-devices.txt') -Value $flutterDevices -Encoding UTF8
if ($flutterDevices -notmatch [regex]::Escape($script:serial)) { Fail "Flutter does not see $script:serial" }
Write-Log 'Flutter device PASS'

Push-Location $repo
try {
    $buildOutput = & flutter build apk --debug --no-pub 2>&1 | Out-String
    Set-Content -LiteralPath (Join-Path $evidence 'app-build.log') -Value $buildOutput -Encoding UTF8
    if ($LASTEXITCODE -ne 0) { Fail "Flutter debug APK build failed; see app-build.log`n$($buildOutput | Select-Object -Last 1)" }
    $apk = Join-Path $repo 'build\app\outputs\flutter-apk\app-debug.apk'
    if (-not (Test-Path -LiteralPath $apk)) { Fail "Built APK missing: $apk" }
    TargetAdb @('install', '-r', $apk) | Out-Null
    $package = Select-String -LiteralPath (Join-Path $repo 'android\app\build.gradle.kts') -Pattern 'applicationId\s*=\s*"([^"]+)"' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $package) { Fail 'Cannot determine Android applicationId; APK installed but launch was not attempted' }
    $appId = $package.Matches[0].Groups[1].Value
    TargetAdb @('logcat', '-c') | Out-Null
    TargetAdb @('shell', 'monkey', '-p', $appId, '-c', 'android.intent.category.LAUNCHER', '1') | Out-Null
    Start-Sleep -Seconds 25
    $activity = TargetAdb @('shell', 'dumpsys', 'activity', 'activities')
    $process = TargetAdb @('shell', 'pidof', $appId)
    $appLogs = TargetAdb @('logcat', '-d', '-t', '800', '-v', 'brief')
    Set-Content -LiteralPath (Join-Path $evidence 'app-startup.log') -Value "package=$appId`nprocess=$process`n$activity`n$appLogs" -Encoding UTF8
    Write-Log "App startup: package=$appId; process=$($process.Trim())"
} finally { Pop-Location }

Write-Log "Completed. Emulator $script:serial remains running for visual QA."
