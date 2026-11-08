#define AppName "Steel Wings CRM"
#define AppVersion "1.0.0"
#define AppExe "steel_wings.exe"

[Setup]
AppId={{A9EA6B13-59C5-4D54-8C67-1932225C5E23}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\Steel Wings CRM
DefaultGroupName=Steel Wings CRM
UninstallDisplayIcon={app}\{#AppExe}
OutputDir=..\dist
OutputBaseFilename=SteelWingsCRM-Setup-x64
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "prerequisites\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Icons]
Name: "{autoprograms}\Steel Wings CRM"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\Steel Wings CRM"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /passive /norestart"; StatusMsg: "Installing the required Microsoft Visual C++ runtime..."; Check: NeedsVCRedist; Flags: waituntilterminated
Filename: "{app}\{#AppExe}"; Description: "Launch Steel Wings CRM"; Flags: postinstall nowait skipifsilent

[Code]
function NeedsVCRedist: Boolean;
var
  Installed: Cardinal;
begin
  Result := not (RegQueryDWordValue(HKLM64,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Installed', Installed) and (Installed = 1));
end;
