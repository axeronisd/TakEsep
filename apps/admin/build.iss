[Setup] 
AppId=TakEsepAdmin 
AppName=TakEsep Admin 
AppVersion=1.0.0 
AppPublisher=TakEsep 
DefaultDirName={autopf}\TakEsep Admin 
DefaultGroupName=TakEsep Admin 
OutputDir=build\windows\x64\runner\Release 
OutputBaseFilename=TakEsepAdmin_Setup 
SetupIconFile=windows\runner\resources\app_icon.ico 
Compression=lzma 
SolidCompression=yes 
WizardStyle=modern 
UninstallDisplayIcon={app}\TakEsepAdmin.exe 
 
[Tasks] 
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}" 
 
[Files] 
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs 
 
[Icons] 
Name: "{group}\TakEsep Admin"; Filename: "{app}\TakEsepAdmin.exe" 
Name: "{autodesktop}\TakEsep Admin"; Filename: "{app}\TakEsepAdmin.exe"; Tasks: desktopicon 
 
[Run] 
Filename: "{app}\TakEsepAdmin.exe"; Description: "{cm:LaunchProgram,TakEsep Admin}"; Flags: nowait postinstall skipifsilent 
