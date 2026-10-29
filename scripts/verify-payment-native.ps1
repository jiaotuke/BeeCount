$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$toolsRoot = Join-Path (Split-Path $projectRoot -Parent) '.tools'
$outputDir = Join-Path $toolsRoot 'payment-tests'
$java = 'D:\ai bazi\.tools\java17\jdk-17.0.20.1+1\bin\java.exe'
$libs = 'D:\ai bazi\.tools\gradle\gradle-8.9\lib'
$androidJar = 'D:\ai bazi\.tools\android-sdk\platforms\android-35\android.jar'
$sourceDir = Join-Path $projectRoot 'android\app\src\main\kotlin\com\tntlikely\beecount'
$testFile = Join-Path $projectRoot 'android\app\src\test\kotlin\com\tntlikely\beecount\PaymentTextParserTest.kt'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
& $java -cp "$libs\*" org.jetbrains.kotlin.cli.jvm.K2JVMCompiler -no-stdlib -no-reflect -classpath "$libs\kotlin-stdlib-1.9.23.jar" -d "$outputDir\parser.jar" "$sourceDir\PaymentTextParser.kt" "$sourceDir\PaymentOcrPolicy.kt" "$sourceDir\WechatRedPacketParser.kt" $testFile
if ($LASTEXITCODE -ne 0) { throw 'Parser compilation failed' }
& $java -cp "$outputDir\parser.jar;$libs\kotlin-stdlib-1.9.23.jar" com.tntlikely.beecount.PaymentTextParserTestKt
if ($LASTEXITCODE -ne 0) { throw 'Parser tests failed' }
& $java -cp "$libs\*" org.jetbrains.kotlin.cli.jvm.K2JVMCompiler -no-stdlib -no-reflect -classpath "$libs\kotlin-stdlib-1.9.23.jar;$androidJar" -d "$outputDir\android-core.jar" "$sourceDir\PaymentTextParser.kt" "$sourceDir\PaymentOcrPolicy.kt" "$sourceDir\WechatRedPacketParser.kt" "$sourceDir\PaymentCaptureStore.kt" "$sourceDir\PaymentNotificationListener.kt"
if ($LASTEXITCODE -ne 0) { throw 'Android service compilation failed' }
Write-Output 'Native parser/OCR scope tests and Android inbox/notification core compilation passed. Run the full Android build to compile the ML Kit screenshot service.'
