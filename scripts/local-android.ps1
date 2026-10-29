param([ValidateSet('deps','analyze','build','format','test')][string]$Action = 'analyze')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$toolsRoot = Join-Path (Split-Path $projectRoot -Parent) '.tools'
$env:PUB_CACHE = Join-Path $toolsRoot 'pub-cache'
$env:GRADLE_USER_HOME = Join-Path $toolsRoot 'gradle-cache'
$env:ANDROID_USER_HOME = Join-Path $toolsRoot 'android\android-user'
$env:JAVA_HOME = 'D:\ai bazi\.tools\java17\jdk-17.0.20.1+1'
$env:ANDROID_HOME = 'D:\ai bazi\.tools\android-sdk'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:CI = 'true'
$env:TEMP = Join-Path $toolsRoot 'tmp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$flutter = Join-Path $toolsRoot 'flutter\bin\flutter.bat'
Push-Location $projectRoot
try {
    switch ($Action) {
        deps { & $flutter pub get }
        analyze { & $flutter analyze --no-pub lib/pages/automation/payment_capture_page.dart lib/pages/automation/payment_capture_review.dart lib/widgets/biz/payment_capture_home_card.dart lib/pages/main/home_page.dart lib/pages/settings/automation_page.dart lib/pages/transaction/transaction_editor_page.dart }
        format { & (Join-Path $toolsRoot 'flutter\bin\dart.bat') format lib/pages/automation/payment_capture_page.dart }
        test { & $flutter test --no-pub test/pages/automation/payment_capture_page_test.dart test/pages/automation/payment_capture_home_card_test.dart }
        build { & $flutter build apk --flavor dev --debug --target-platform android-arm64 --verbose }
    }
    if ($LASTEXITCODE -ne 0) { throw "Flutter action failed: $Action (exit $LASTEXITCODE)" }
} finally { Pop-Location }
