@echo off
echo [Setup] > build.iss
echo AppId=TakEsepAdmin >> build.iss
echo AppName=TakEsep Admin >> build.iss
echo AppVersion=1.0.0 >> build.iss
echo AppPublisher=TakEsep >> build.iss
echo DefaultDirName={autopf}\TakEsep Admin >> build.iss
echo DefaultGroupName=TakEsep Admin >> build.iss
echo OutputDir=build\windows\x64\runner\Release >> build.iss
echo OutputBaseFilename=TakEsepAdmin_Setup >> build.iss
echo SetupIconFile=windows\runner\resources\app_icon.ico >> build.iss
echo Compression=lzma >> build.iss
echo SolidCompression=yes >> build.iss
echo WizardStyle=modern >> build.iss
echo UninstallDisplayIcon={app}\TakEsepAdmin.exe >> build.iss
echo. >> build.iss
echo [Tasks] >> build.iss
echo Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}" >> build.iss
echo. >> build.iss
echo [Files] >> build.iss
echo Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs >> build.iss
echo. >> build.iss
echo [Icons] >> build.iss
echo Name: "{group}\TakEsep Admin"; Filename: "{app}\TakEsepAdmin.exe" >> build.iss
echo Name: "{autodesktop}\TakEsep Admin"; Filename: "{app}\TakEsepAdmin.exe"; Tasks: desktopicon >> build.iss
echo. >> build.iss
echo [Run] >> build.iss
echo Filename: "{app}\TakEsepAdmin.exe"; Description: "{cm:LaunchProgram,TakEsep Admin}"; Flags: nowait postinstall skipifsilent >> build.iss

"C:\Users\axero\AppData\Local\Programs\Inno Setup 6\ISCC.exe" build.iss
