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
WizardImageFile=..\installer\assets\wizard_large.bmp
WizardSmallImageFile=..\installer\assets\logo_small.bmp

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Dirs]
; Autorise les utilisateurs standards à écrire dans les dossiers locaux d'inférence et de calcul
Name: "{app}\runtime\ollama"; Permissions: users-modify
Name: "{app}\runtime\ollama\models"; Permissions: users-modify
Name: "{app}\tool\reco3d\storage"; Permissions: users-modify

[Files]
; Images temporaires pour le carrousel de présentation ("pubs" / caractéristiques Forgeron)
Source: "..\installer\assets\slide1.bmp"; Flags: dontcopy
Source: "..\installer\assets\slide2.bmp"; Flags: dontcopy
Source: "..\installer\assets\slide3.bmp"; Flags: dontcopy
Source: "..\installer\assets\slide4.bmp"; Flags: dontcopy
Source: "..\installer\assets\slide5.bmp"; Flags: dontcopy

; Tout le système unifié dans staging (Flutter Release, pipeline, reco3d, Meshroom, Python embarqué, Ollama et modèles IA)
Source: "..\dist\staging\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
function GetTickCount: DWORD;
  external 'GetTickCount@kernel32.dll stdcall';

var
  BillboardImage: TBitmapImage;
  SlideTitleLabel: TNewStaticText;
  SlideDescLabel: TNewStaticText;
  LastSlideTick: DWORD;
  CurrentSlide: Integer;

const
  TotalSlides = 5;

procedure ShowSlide(Index: Integer);
var
  ImgPath: String;
  IsFr: Boolean;
begin
  ImgPath := ExpandConstant('{tmp}\slide' + IntToStr(Index) + '.bmp');
  if FileExists(ImgPath) and Assigned(BillboardImage) then
  begin
    BillboardImage.Bitmap.LoadFromFile(ImgPath);
  end;

  IsFr := (ActiveLanguage = 'french');

  case Index of
    1:
      begin
        if IsFr then
        begin
          SlideTitleLabel.Caption := 'FORGERON - Fraiseuse 5 axes au dixieme du prix';
          SlideDescLabel.Caption := 'Concue et fabriquee a Bamako, Mali. La precision industrielle accessible a tous.';
        end
        else
        begin
          SlideTitleLabel.Caption := 'FORGERON - 5-axis CNC at a tenth of the price';
          SlideDescLabel.Caption := 'Designed and built in Bamako, Mali. Precision manufacturing, made accessible.';
        end;
      end;
    2:
      begin
        if IsFr then
        begin
          SlideTitleLabel.Caption := 'Agent IA Hors-Ligne - Parlez, usinez';
          SlideDescLabel.Caption := 'Comprend le Bambara et le Francais. Pilote l''atelier sans CAO ni connexion Internet.';
        end
        else
        begin
          SlideTitleLabel.Caption := 'Offline AI Agent - Speak it. Cut it.';
          SlideDescLabel.Caption := 'Understands Bambara and French. Runs the workshop without CAD or Internet.';
        end;
      end;
    3:
      begin
        if IsFr then
        begin
          SlideTitleLabel.Caption := 'Jumeau Numerique & Simulation 3D';
          SlideDescLabel.Caption := 'Visualisation temps reel de la piece, du brut et des parcours 5 axes avant usinage.';
        end
        else
        begin
          SlideTitleLabel.Caption := 'Digital Twin & 3D Simulation';
          SlideDescLabel.Caption := 'Real-time 3D toolpath and stock simulation before any machine motion.';
        end;
      end;
    4:
      begin
        if IsFr then
        begin
          SlideTitleLabel.Caption := 'Securite Active ForceGuard & Watchdog';
          SlideDescLabel.Caption := 'Protection anti-collision continue, surveillance des charges et arret d''urgence materiel.';
        end
        else
        begin
          SlideTitleLabel.Caption := 'Active Safety: ForceGuard & Watchdog';
          SlideDescLabel.Caption := 'Continuous collision checking, load monitoring, and hardware emergency stop.';
        end;
      end;
    5:
      begin
        if IsFr then
        begin
          SlideTitleLabel.Caption := 'L''Afrique a de l''ambition, elle a desormais l''outil';
          SlideDescLabel.Caption := 'Composants standardises, architecture ouverte et maintenance locale en atelier.';
        end
        else
        begin
          SlideTitleLabel.Caption := 'Precision manufacturing made in Africa';
          SlideDescLabel.Caption := 'Standard commodity components, open design, and local workshop maintenance.';
        end;
      end;
  end;
end;

procedure InitializeWizard();
var
  i: Integer;
begin
  CurrentSlide := 1;
  LastSlideTick := 0;

  for i := 1 to TotalSlides do
  begin
    ExtractTemporaryFile('slide' + IntToStr(i) + '.bmp');
  end;

  // Ajustement de la page d'installation pour laisser place au carrousel promotionnel
  WizardForm.FilenameLabel.Visible := False;
  WizardForm.StatusLabel.Visible := False;

  WizardForm.ProgressGauge.Left := ScaleX(20);
  WizardForm.ProgressGauge.Width := WizardForm.InstallingPage.Width - ScaleX(40);
  WizardForm.ProgressGauge.Top := WizardForm.InstallingPage.Height - ScaleY(35);
  WizardForm.ProgressGauge.Height := ScaleY(18);

  // Visuel du billboard
  BillboardImage := TBitmapImage.Create(WizardForm);
  BillboardImage.Parent := WizardForm.InstallingPage;
  BillboardImage.Left := ScaleX(20);
  BillboardImage.Top := ScaleY(8);
  BillboardImage.Width := WizardForm.InstallingPage.Width - ScaleX(40);
  BillboardImage.Height := ScaleY(130);
  BillboardImage.Stretch := True;
  BillboardImage.Center := True;

  // Titre en orange Forgeron
  SlideTitleLabel := TNewStaticText.Create(WizardForm);
  SlideTitleLabel.Parent := WizardForm.InstallingPage;
  SlideTitleLabel.Left := ScaleX(20);
  SlideTitleLabel.Top := ScaleY(144);
  SlideTitleLabel.Width := WizardForm.InstallingPage.Width - ScaleX(40);
  SlideTitleLabel.Font.Style := [fsBold];
  SlideTitleLabel.Font.Size := 9;
  SlideTitleLabel.Font.Color := $001A6AFF; // Orange Forgeron (BGR)

  // Description détaillée
  SlideDescLabel := TNewStaticText.Create(WizardForm);
  SlideDescLabel.Parent := WizardForm.InstallingPage;
  SlideDescLabel.Left := ScaleX(20);
  SlideDescLabel.Top := ScaleY(162);
  SlideDescLabel.Width := WizardForm.InstallingPage.Width - ScaleX(40);
  SlideDescLabel.Font.Size := 8;

  ShowSlide(1);
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpInstalling then
  begin
    LastSlideTick := GetTickCount();
    ShowSlide(1);
  end;
end;

procedure CurInstallProgressChanged(CurProgress, MaxProgress: Integer);
var
  NowTick: DWORD;
begin
  NowTick := GetTickCount();
  // Rotation automatique des diapositives toutes les 4 secondes
  if (NowTick - LastSlideTick > 4000) or (NowTick < LastSlideTick) then
  begin
    CurrentSlide := (CurrentSlide mod TotalSlides) + 1;
    ShowSlide(CurrentSlide);
    LastSlideTick := NowTick;
  end;
end;
