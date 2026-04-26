$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Project TakEsep\TakEsep"
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ReleaseDir = Join-Path $DesktopPath "TakEsep_Releases_v2.0.0"
$InnoSetup = "C:\Users\axero\AppData\Local\Programs\Inno Setup 6\ISCC.exe"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🚀 Запуск сборки релизов TakEsep v2.0.0" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Создаем папку на рабочем столе
if (Test-Path $ReleaseDir) { Remove-Item $ReleaseDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
New-Item -ItemType Directory -Force -Path "$ReleaseDir\apk" | Out-Null
New-Item -ItemType Directory -Force -Path "$ReleaseDir\aab" | Out-Null
New-Item -ItemType Directory -Force -Path "$ReleaseDir\windows" | Out-Null
Write-Host "📁 Папка для релизов: $ReleaseDir`n" -ForegroundColor DarkGray

# ═══════════════════════════════════════
# 1. TakEsep Warehouse — APK + AAB
# ═══════════════════════════════════════
Write-Host "📦 1/8 Сборка TakEsep APK..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\apps\warehouse"
flutter build apk --release
if ($?) {
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$ReleaseDir\apk\TakEsep.apk" -Force
    Write-Host "✅ TakEsep APK собран!`n" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка при сборке TakEsep APK!`n" -ForegroundColor Red
    exit 1
}

Write-Host "📦 2/8 Сборка TakEsep AAB..." -ForegroundColor Yellow
flutter build appbundle --release
if ($?) {
    Copy-Item "build\app\outputs\bundle\release\app-release.aab" "$ReleaseDir\aab\TakEsep.aab" -Force
    Write-Host "✅ TakEsep AAB собран!`n" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка при сборке TakEsep AAB!`n" -ForegroundColor Red
}

# ═══════════════════════════════════════
# 2. TakEsep Warehouse — Windows + Installer
# ═══════════════════════════════════════
Write-Host "🖥️  3/8 Сборка TakEsep (Windows)..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\apps\warehouse"
flutter build windows --release
if ($?) {
    Write-Host "✅ Windows EXE собран!" -ForegroundColor Green

    # Создаём инсталлятор через Inno Setup
    if (Test-Path $InnoSetup) {
        Write-Host "📦 Создание инсталлятора (Inno Setup)..." -ForegroundColor Yellow
        & $InnoSetup "build.iss"
        if ($?) {
            $InstallerFile = "build\windows\x64\runner\Release\TakEsep_Setup.exe"
            if (Test-Path $InstallerFile) {
                Copy-Item $InstallerFile "$ReleaseDir\windows\TakEsep_Setup.exe" -Force
                Write-Host "✅ Инсталлятор создан!`n" -ForegroundColor Green
            }
        } else {
            Write-Host "❌ Ошибка Inno Setup!`n" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️  Inno Setup не найден, пропускаем создание инсталлятора`n" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "❌ Ошибка при сборке Windows!`n" -ForegroundColor Red
    exit 1
}

# ═══════════════════════════════════════
# 3. AkJol Courier — APK + AAB
# ═══════════════════════════════════════
Write-Host "📦 4/8 Сборка AkJol Courier APK..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\apps\courier"
flutter build apk --release
if ($?) {
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$ReleaseDir\apk\AkJol_Go.apk" -Force
    Write-Host "✅ Курьер APK собран!`n" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка при сборке Курьера APK!`n" -ForegroundColor Red
    exit 1
}

Write-Host "📦 5/8 Сборка AkJol Courier AAB..." -ForegroundColor Yellow
flutter build appbundle --release
if ($?) {
    Copy-Item "build\app\outputs\bundle\release\app-release.aab" "$ReleaseDir\aab\AkJol_Go.aab" -Force
    Write-Host "✅ Курьер AAB собран!`n" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка при сборке Курьера AAB!`n" -ForegroundColor Red
}

# ═══════════════════════════════════════
# 4. AkJol Customer — APK + AAB
# ═══════════════════════════════════════
Write-Host "📦 6/8 Сборка AkJol Customer APK..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\apps\customer"
flutter build apk --release
if ($?) {
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$ReleaseDir\apk\AkJol.apk" -Force
    Write-Host "✅ Клиент APK собран!`n" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка при сборке Клиента APK!`n" -ForegroundColor Red
    exit 1
}

Write-Host "📦 7/8 Сборка AkJol Customer AAB..." -ForegroundColor Yellow
flutter build appbundle --release
if ($?) {
    Copy-Item "build\app\outputs\bundle\release\app-release.aab" "$ReleaseDir\aab\AkJol.aab" -Force
    Write-Host "✅ Клиент AAB собран!`n" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка при сборке Клиента AAB!`n" -ForegroundColor Red
}

# ═══════════════════════════════════════
# 5. TakEsep Admin — Web (деплой в docs/)
# ═══════════════════════════════════════
Write-Host "`n🌐 8/8 Сборка TakEsep Admin (Web)..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\apps\admin"
flutter build web --release --base-href "/TakEsep/app/"
if ($?) {
    $DocsApp = "$ProjectRoot\docs\app"
    if (Test-Path $DocsApp) { Remove-Item $DocsApp -Recurse -Force }
    Copy-Item "build\web" -Destination $DocsApp -Recurse -Force
    Write-Host "✅ Админка задеплоена в docs/app/!" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка при сборке Админки!`n" -ForegroundColor Red
}

# ═══════════════════════════════════════
# Копируем иконки в docs/
# ═══════════════════════════════════════
Set-Location $ProjectRoot
$CustIcon = "$ProjectRoot\apps\customer\assets\images\akjol_logo.png"
if (Test-Path $CustIcon) { Copy-Item $CustIcon "docs\akjol_customer.png" -Force }
$CourierIcon = "$ProjectRoot\apps\courier\assets\icon.png"
if (Test-Path $CourierIcon) { Copy-Item $CourierIcon "docs\akjol_courier.png" -Force }

# Возвращаемся в корень
Set-Location $ProjectRoot

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🎉 ВСЕ ГОТОВО!" -ForegroundColor Green
Write-Host ""
Write-Host "📁 Артефакты релиза v2.0.0:" -ForegroundColor Yellow
Write-Host "   APK:  $ReleaseDir\apk\" -ForegroundColor White
Write-Host "   AAB:  $ReleaseDir\aab\" -ForegroundColor White
Write-Host "   Win:  $ReleaseDir\windows\" -ForegroundColor White
Write-Host ""
Write-Host "📤 Следующие шаги:" -ForegroundColor Yellow
Write-Host "   1. git add . && git commit -m 'v2.0.0' && git tag v2.0.0 && git push --tags" -ForegroundColor White
Write-Host "   2. GitHub Actions автоматически соберёт и опубликует релиз" -ForegroundColor White
Write-Host "   3. Загрузите AAB-файлы в Google Play Console (если не настроен автозагруз)" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Cyan
