[Setup] 
AppId=TakEsep 
AppName=TakEsep 
AppVersion=1.0.0 
AppPublisher=TakEsep 
DefaultDirName={autopf}\TakEsep 
DefaultGroupName=TakEsep 
OutputDir=build\windows\x64\runner\Release 
OutputBaseFilename=TakEsep_Setup 
SetupIconFile=windows\runner\resources\app_icon.ico 
Compression=lzma 
SolidCompression=yes 
WizardStyle=modern 
UninstallDisplayIcon={app}\TakEsep.exe 
 
[Tasks] 
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}" 
 
[Files] 
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs 
 
[Icons] 
Name: "{group}\TakEsep"; Filename: "{app}\TakEsep.exe" 
Name: "{autodesktop}\TakEsep"; Filename: "{app}\TakEsep.exe"; Tasks: desktopicon 
 
[Run] 
Filename: "{app}\TakEsep.exe"; Description: "{cm:LaunchProgram,TakEsep}"; Flags: nowait postinstall skipifsilent 
