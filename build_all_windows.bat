@echo off
echo ===================================================
echo 🚀 Начинаем процесс сборки всех приложений для Windows
echo ===================================================

echo.
echo [1/4] Настройка логотипа для Курьеров (AkJol Driver)...
cd "c:\Project TakEsep\TakEsep\apps\courier"
mkdir assets 2>NUL
copy "C:\Users\axero\.gemini\antigravity\brain\b8440484-d802-459a-8945-f0ec3db861fb\akjol_driver_logo_1_1775237487549.png" "assets\icon.png"
call flutter pub get
call flutter pub run flutter_launcher_icons

echo.
echo [2/4] Сборка TakEsep (Склад / Админка)...
cd "c:\Project TakEsep\TakEsep\apps\warehouse"
call flutter clean
call flutter build windows --release

echo.
echo [3/4] Сборка AkJol (Клиентское приложение)...
cd "c:\Project TakEsep\TakEsep\apps\customer"
call flutter clean
call flutter build windows --release

echo.
echo [4/4] Сборка AkJol Driver (Приложение для курьеров)...
cd "c:\Project TakEsep\TakEsep\apps\courier"
call flutter clean
call flutter build windows --release

echo.
echo ===================================================
echo ✅ ГОТОВО! Все приложения собраны для Windows.
echo Ищите файлы .exe в соответствующих папках:
echo - apps/warehouse/build/windows/x64/runner/Release/
echo - apps/customer/build/windows/x64/runner/Release/
echo - apps/courier/build/windows/x64/runner/Release/
echo ===================================================
pause
