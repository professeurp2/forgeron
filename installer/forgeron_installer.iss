; Script Inno Setup pour Forgeron CNC 5-Axes
; Génère un installateur autonome complet unifié (tout le système : Front Flutter, Back Python/OCP/reco3d/Meshroom, Serveur IA Ollama et Modèles)

#define MyAppName "Forgeron CNC 5-Axes"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "ENI - Unipods"
#define MyAppURL "https://github.com/forgeron-cnc"
#define MyAppExeName "forgeron.exe"

[Setup]
AppId={{D9A814F2-3C42-4A72-B1E2-9F1F0E4B77A1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\Forgeron
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\dist
OutputBaseFilename=Forgeron_CNC_5Axis_Setup_v1.0
DiskSpanning=yes
DiskSliceSize=max
Compression=lzma2/fast
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=..\windows\runner\resources\app_icon.ico

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Tout le système unifié dans staging (Flutter Release, pipeline, reco3d, Meshroom, Python embarqué, Ollama et modèles IA)
Source: "..\dist\staging\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
