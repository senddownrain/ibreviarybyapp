param(
  [Parameter(Mandatory=$true)]
  [ValidatePattern('^emulator-\d+$')][string]$Device,
  [ValidateSet('1.0','1.5','2.0')][string]$FontScale = '1.0',
  [ValidateSet('gesture','threebutton')][string]$Navigation = 'gesture',
  [ValidateSet('native','320')][string]$Viewport = 'native',
  [switch]$FocusOnly,
  [switch]$UseExistingApk
)
$ErrorActionPreference = 'Stop'
$taskProject = Split-Path -Parent $PSScriptRoot
$taskFlutter = Split-Path -Parent (Split-Path -Parent (Get-Command flutter.bat).Source)
$taskSdk = Join-Path $env:LOCALAPPDATA 'Android/Sdk'
$taskAdb = Join-Path $taskSdk 'platform-tools/adb.exe'
$taskDart = Join-Path $taskFlutter 'bin/cache/dart-sdk/bin/dart.exe'
$taskTool = Join-Path $taskFlutter 'bin/cache/flutter_tools.snapshot'
$taskPackages = Join-Path $taskFlutter 'packages/flutter_tools/.dart_tool/package_config.json'
$taskEvidence = Join-Path $taskProject 'audit-evidence/liturgical-selector-redesign'
$taskLabel = "android-$FontScale-$Navigation"
if ($Viewport -eq '320') { $taskLabel += '-320' }
if ($FocusOnly) { $taskLabel += '-focused' }
$taskOutput = Join-Path $taskEvidence "$taskLabel.log"
$taskError = Join-Path $taskEvidence "$taskLabel.stderr.log"
$taskSavedFont = (& $taskAdb -s $Device shell settings get system font_scale).Trim()
$taskSavedNavigation = (& $taskAdb -s $Device shell settings get secure navigation_mode).Trim()
$taskSavedSize = (& $taskAdb -s $Device shell wm size) -join ' '
$taskViewportChanged = $false
$taskSavedGradle = $env:GRADLE_OPTS
$taskOldLocation = Get-Location
try {
  Set-Location -LiteralPath $taskProject
  if ($Viewport -eq '320') {
    $taskDensityOutput = (& $taskAdb -s $Device shell wm density) -join ' '
    $taskDensity = [int]([regex]::Matches($taskDensityOutput, 'density: (\d+)')[-1].Groups[1].Value)
    $taskPixelWidth = [Math]::Round(320 * $taskDensity / 160)
    $taskPixelHeight = [Math]::Round(844 * $taskDensity / 160)
    & $taskAdb -s $Device shell wm size "${taskPixelWidth}x${taskPixelHeight}"
    if ($LASTEXITCODE -ne 0) { throw 'Narrow viewport did not apply' }
    $taskViewportChanged = $true
  }
  & $taskAdb -s $Device shell settings put system font_scale $FontScale
  $taskOverlay = if ($Navigation -eq 'gesture') { 'com.android.internal.systemui.navbar.gestural' } else { 'com.android.internal.systemui.navbar.threebutton' }
  & $taskAdb -s $Device shell cmd overlay enable-exclusive --category $taskOverlay
  $taskExpectedMode = if ($Navigation -eq 'gesture') { '2' } else { '0' }
  & $taskAdb -s $Device shell settings put secure navigation_mode $taskExpectedMode
  $taskActualMode = (& $taskAdb -s $Device shell cmd overlay lookup android android:integer/config_navBarInteractionMode).Trim()
  if ($taskActualMode -ne $taskExpectedMode) { throw 'Navigation overlay did not apply' }
  $env:GRADLE_OPTS = '-Dorg.gradle.jvmargs="-Xmx1536m -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=128m" -Dorg.gradle.workers.max=1 -Dorg.gradle.daemon=false'
  $taskArguments = @("--packages=$taskPackages", $taskTool, 'drive', '-d', $Device, '--no-pub',
    '--driver=test_driver/liturgical_selector_driver.dart', '--target=integration_test/liturgical_selector_redesign_test.dart')
  if ($FocusOnly) { $taskArguments += '--dart-define=SELECTOR_FOCUS_ONLY=true' }
  if ($UseExistingApk) {
    $taskApk = Join-Path $taskProject $(if ($FocusOnly) { 'build/selector-driver/selector-focused.apk' } else { 'build/app/outputs/flutter-apk/app-debug.apk' })
    if (-not (Test-Path -LiteralPath $taskApk)) { throw 'The integration APK has not been built yet' }
    $taskArguments += "--use-application-binary=$taskApk"
  }
  $taskProcess = Start-Process -FilePath $taskDart -ArgumentList $taskArguments -WorkingDirectory $taskProject -WindowStyle Hidden -PassThru -RedirectStandardOutput $taskOutput -RedirectStandardError $taskError
  $taskBackCount = 0
  $taskCaptured = [System.Collections.Generic.HashSet[string]]::new()
  while (-not $taskProcess.HasExited) {
    if (Test-Path -LiteralPath $taskOutput) {
      $taskMarkers = @(Select-String -LiteralPath $taskOutput -Pattern 'SELECTOR_NATIVE_BACK_READY').Count
      while ($taskBackCount -lt $taskMarkers) {
        & $taskAdb -s $Device shell input keyevent 4
        $taskBackCount++
      }
      foreach ($taskShotMarker in (Select-String -LiteralPath $taskOutput -Pattern 'SELECTOR_NATIVE_SCREENSHOT_READY:([a-z0-9.-]+)')) {
        $taskShotName = $taskShotMarker.Matches[0].Groups[1].Value
        if ($taskCaptured.Add($taskShotName)) {
          & $taskAdb -s $Device shell screencap -p /sdcard/liturgical-selector-audit.png
          if ($LASTEXITCODE -ne 0) { throw 'Device screencap failed' }
          & $taskAdb -s $Device pull /sdcard/liturgical-selector-audit.png (Join-Path $taskEvidence "$taskLabel-system-$taskShotName.png") | Out-Null
          if ($LASTEXITCODE -ne 0) { throw 'Device screenshot pull failed' }
        }
      }
    }
    Start-Sleep -Milliseconds 200
  }
  $taskProcess.WaitForExit()
  Get-Content -LiteralPath $taskOutput -Tail 8
  Get-Content -LiteralPath $taskError -Tail 8
  "Physical Android Back events sent: $taskBackCount" | Add-Content -LiteralPath $taskOutput
  "Whole-device screenshots saved: $($taskCaptured.Count)" | Add-Content -LiteralPath $taskOutput
  if ($taskProcess.ExitCode -ne 0) { throw "Native integration failed with exit $($taskProcess.ExitCode)" }
  $taskExpectedBack = if ($FocusOnly) { 0 } else { 2 }
  $taskExpectedShots = if ($FocusOnly) { 8 } else { 20 }
  if ($taskBackCount -ne $taskExpectedBack) { throw 'Native Back checks did not execute as expected' }
  if ($taskCaptured.Count -ne $taskExpectedShots) { throw 'All native states must have whole-device screenshots' }
} finally {
  $env:GRADLE_OPTS = $taskSavedGradle
  if ($taskViewportChanged) {
    $taskOriginalSize = [regex]::Match($taskSavedSize, 'Override size: (\d+x\d+)')
    if ($taskOriginalSize.Success) {
      & $taskAdb -s $Device shell wm size $taskOriginalSize.Groups[1].Value
    } else {
      & $taskAdb -s $Device shell wm size reset
    }
  }
  if ($taskSavedFont -eq 'null') {
    & $taskAdb -s $Device shell settings delete system font_scale
  } else {
    & $taskAdb -s $Device shell settings put system font_scale $taskSavedFont
  }
  $taskOriginalOverlay = switch ($taskSavedNavigation) {
    '2' { 'com.android.internal.systemui.navbar.gestural' }
    '1' { 'com.android.internal.systemui.navbar.twobutton' }
    default { 'com.android.internal.systemui.navbar.threebutton' }
  }
  & $taskAdb -s $Device shell cmd overlay enable-exclusive --category $taskOriginalOverlay
  if ($taskSavedNavigation -eq 'null') {
    & $taskAdb -s $Device shell settings delete secure navigation_mode
  } else {
    & $taskAdb -s $Device shell settings put secure navigation_mode $taskSavedNavigation
  }
  Set-Location -LiteralPath $taskOldLocation.Path
}
