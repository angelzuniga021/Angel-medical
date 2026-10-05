[Setup]
AppId={{E376AD8E-619F-4BFA-9F41-8B7E1EFDAB87}
AppName=Angel Medical PC
AppVersion=1.0.1
DefaultDirName={localappdata}\Programs\AngelMedical
DefaultGroupName=Angel Medical
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir=..\..\entrega-pc
OutputBaseFilename=Angel-Medical-PC-1.0.1-Instalador
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\angel_medical_pc.exe
[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\Angel Medical"; Filename: "{app}\angel_medical_pc.exe"
Name: "{autodesktop}\Angel Medical"; Filename: "{app}\angel_medical_pc.exe"
[Run]
Filename: "{app}\angel_medical_pc.exe"; Description: "Abrir Angel Medical"; Flags: nowait postinstall skipifsilent
; Production databases live outside {app}; installation and uninstall never
; include, overwrite, or delete the user's AngelMedical data directory.
