param([Parameter(Mandatory=$true)][string]$Apk)
$ErrorActionPreference = 'Stop'
$apkPath = (Resolve-Path -LiteralPath $Apk).Path
$buildTools = 'D:\ai bazi\.tools\android-sdk\build-tools\35.0.0'
$env:JAVA_HOME = 'D:\ai bazi\.tools\java17\jdk-17.0.20.1+1'
& "$buildTools\apksigner.bat" verify --verbose --print-certs $apkPath
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
& "$buildTools\zipalign.exe" -c -P 16 4 $apkPath
if ($LASTEXITCODE -ne 0) { throw 'APK zip alignment verification failed' }
$badging = & "$buildTools\aapt.exe" dump badging $apkPath
if ($LASTEXITCODE -ne 0) { throw 'APK metadata could not be read' }
$badging | Select-String -Pattern "^package:|^sdkVersion:|^targetSdkVersion:|^application-label:|^native-code:|^launchable-activity:"
if (($badging -join "`n") -notmatch "com.tntlikely.beecount.dev.debug") { throw 'Unexpected package ID' }
$manifest = & "$buildTools\aapt.exe" dump xmltree $apkPath AndroidManifest.xml
foreach ($required in @('PaymentNotificationListener','PaymentAccessibilityService','BIND_NOTIFICATION_LISTENER_SERVICE','BIND_ACCESSIBILITY_SERVICE')) {
    if (($manifest -join "`n") -notmatch [regex]::Escape($required)) { throw "Missing payment service declaration: $required" }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
try {
    foreach ($entry in @('classes.dex','lib/arm64-v8a/libflutter.so','assets/flutter_assets/AssetManifest.bin')) {
        if ($null -eq $zip.GetEntry($entry)) { throw "Missing APK payload: $entry" }
    }
} finally { $zip.Dispose() }
Get-FileHash -LiteralPath $apkPath -Algorithm SHA256
Write-Output 'APK signature, alignment, package metadata, ARM64 payload and payment service declarations verified.'
