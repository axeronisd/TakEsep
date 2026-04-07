$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Project TakEsep\TakEsep"
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ReleaseDir = Join-Path $DesktopPath "TakEsep_Releases"
$InnoSetup = "C:\Users\axero\AppData\Local\Programs\Inno Setup 6\ISCC.exe"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🚀 Запуск сборки релизов TakEsep & AkJol" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Создаем папку на рабочем столе
if (Test-Path $ReleaseDir) { Remove-Item $ReleaseDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
Write-Host "📁 Папка для релизов: $ReleaseDir`n" -ForegroundColor DarkGray

# ═══════════════════════════════════════
# 1. TakEsep Warehouse — APK
# ═══════════════════════════════════════
Write-Host "📦 1/5 Сборка TakEsep (APK)..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\apps\warehouse"
flutter build apk --release
if ($?) {
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$ReleaseDir\TakEsep.apk" -Force
    Write-Host "✅ TakEsep APK собран!`n" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка при сборке TakEsep APK!`n" -ForegroundColor Red
}

# ═══════════════════════════════════════
# 2. TakEsep Warehouse — Windows + Installer
# ═══════════════════════════════════════
Write-Host "🖥️  2/5 Сборка TakEsep (Windows)..." -ForegroundColor Yellow
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
                Copy-Item $InstallerFile "$ReleaseDir\TakEsep_Setup.exe" -Force
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
}

# ═══════════════════════════════════════
# 3. AkJol Courier — APK
# ═══════════════════════════════════════
Write-Host "📦 3/5 Сборка AkJol Courier (APK)..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\apps\courier"
flutter build apk --release
if ($?) {
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$ReleaseDir\AkJol_Courier.apk" -Force
    Write-Host "✅ Курьер собран!`n" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка при сборке Курьера!`n" -ForegroundColor Red
}

# ═══════════════════════════════════════
# 4. AkJol Customer — APK
# ═══════════════════════════════════════
Write-Host "📦 4/5 Сборка AkJol Customer (APK)..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\apps\customer"
flutter build apk --release
if ($?) {
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$ReleaseDir\AkJol_Customer.apk" -Force
    Write-Host "✅ Клиент собран!`n" -ForegroundColor Green
} else {
    Write-Host "❌ Ошибка при сборке Клиента!`n" -ForegroundColor Red
}

# ═══════════════════════════════════════
# 5. TakEsep Admin — Web (деплой в docs/)
# ═══════════════════════════════════════
Write-Host "`n🌐 5/5 Сборка TakEsep Admin (Web)..." -ForegroundColor Yellow
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
Write-Host "📁 Файлы для GitHub Release v2.0:" -ForegroundColor Yellow
Write-Host "   $ReleaseDir\TakEsep.apk" -ForegroundColor White
Write-Host "   $ReleaseDir\TakEsep_Setup.exe" -ForegroundColor White
Write-Host "   $ReleaseDir\AkJol_Courier.apk" -ForegroundColor White
Write-Host "   $ReleaseDir\AkJol_Customer.apk" -ForegroundColor White
Write-Host ""
Write-Host "📤 Шаги публикации:" -ForegroundColor Yellow
Write-Host "   1. git add . && git commit -m 'v2.0' && git push" -ForegroundColor White
Write-Host "   2. GitHub -> Releases -> Create v2.0" -ForegroundColor White
Write-Host "   3. Загрузите 4 файла из TakEsep_Releases" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Cyan
