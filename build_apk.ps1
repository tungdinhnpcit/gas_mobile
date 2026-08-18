# build_apk.ps1
# Tu dong tang patch version + build number trong pubspec.yaml, sau do build APK release.
# Vi du: 1.0.0+4 -> 1.0.1+5 -> 1.0.2+6 ...

$ErrorActionPreference = "Stop"

$pubspecPath = Join-Path $PSScriptRoot "pubspec.yaml"
$content = Get-Content $pubspecPath -Raw -Encoding UTF8

$pattern = '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$'
$match = [regex]::Match($content, $pattern)
if (-not $match.Success) {
    throw "Khong tim thay dong 'version: X.Y.Z+B' trong pubspec.yaml"
}

$major = [int]$match.Groups[1].Value
$minor = [int]$match.Groups[2].Value
$patch = [int]$match.Groups[3].Value
$build = [int]$match.Groups[4].Value

$oldVersion = "$major.$minor.$patch+$build"

$newPatch = $patch + 1
$newBuild = $build + 1
$newVersion = "$major.$minor.$newPatch+$newBuild"

$newContent = [regex]::Replace($content, $pattern, "version: $newVersion")
Set-Content -Path $pubspecPath -Value $newContent -Encoding UTF8 -NoNewline

Write-Host "Version: $oldVersion -> $newVersion" -ForegroundColor Cyan

flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build APK that bai (version pubspec.yaml da duoc tang len $newVersion)." -ForegroundColor Red
    exit $LASTEXITCODE
}

$apkDir = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk"
$srcApk = Join-Path $apkDir "app-release.apk"
$destApk = Join-Path $apkDir "gas_manager_v$newVersion.apk"
Copy-Item -Path $srcApk -Destination $destApk -Force

Write-Host "Build APK thanh cong: v$newVersion" -ForegroundColor Green
Write-Host "File: $destApk" -ForegroundColor Green
