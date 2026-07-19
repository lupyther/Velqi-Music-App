[Setup]
AppId=B9F6E402-0CAE-4045-BDE6-14BD6C39C4EA
AppVersion=1.2.2
AppName=Velqi
AppPublisher=@dieegoleo
AppPublisherURL=https://github.com/dieegoleo
AppSupportURL=https://github.com/dieegoleo
AppUpdatesURL=https://github.com/dieegoleo
DefaultDirName={autopf}\Velqi
DisableProgramGroupPage=yes
OutputDir=C:\Users\Admin\Desktop\Velqi-Music-App\windows\packaging\exe
OutputBaseFilename=Velqi-Setup-dieegoleo
Compression=lzma
SolidCompression=yes
SetupIconFile=C:\Users\Admin\Desktop\Velqi-Music-App\windows\runner\resources\app_icon.ico
WizardStyle=modern
PrivilegesRequired=lowest
LicenseFile=C:\Users\Admin\Desktop\Velqi-Music-App\LICENSE
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "C:\Users\Admin\Desktop\Velqi-Music-App\build\windows\x64\runner\Release\velqi.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\Admin\Desktop\Velqi-Music-App\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\Velqi"; Filename: "{app}\velqi.exe"
Name: "{autodesktop}\Velqi"; Filename: "{app}\velqi.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\velqi.exe"; Description: "{cm:LaunchProgram,{#StringChange('Velqi', '&', '&&')}}"; Flags: nowait postinstall skipifsilent
