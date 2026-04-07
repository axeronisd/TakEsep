@echo off
echo ===================================================
echo 🚀 Начинаем добавление поддержки Windows и сборку
echo ===================================================

echo.
echo [1/2] Интеграция Windows в AkJol Customer (Клиент)...
cd "c:\Project TakEsep\TakEsep\apps\customer"
call flutter create --platforms=windows .
call flutter clean
call flutter build windows --release

echo.
echo [2/2] Интеграция Windows в AkJol Driver (Курьер)...
cd "c:\Project TakEsep\TakEsep\apps\courier"
call flutter create --platforms=windows .
call flutter clean
call flutter build windows --release

echo.
echo ===================================================
echo ✅ ГОТОВО! Теперь и Клиентское, и Курьерское 
echo приложения скомпилированы в формате .exe.
echo Ищите файлы тут:
echo - apps/customer/build/windows/x64/runner/Release/
echo - apps/courier/build/windows/x64/runner/Release/
echo ===================================================
pause
