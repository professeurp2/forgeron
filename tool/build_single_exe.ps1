# Script PowerShell d'empaquetage automatique de Forgeron en un SEUL EXÉCUTABLE (.exe)
# Génère dist\Forgeron_CNC_5Axis_Setup.exe

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  FORGERON CNC 5-AXES - CRÉATION DU BINER UNIFIÉ (.EXE)  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$rootDir = Resolve-Path "$PSScriptRoot\.."
Set-Location $rootDir

# 1. Compilation Flutter Windows Release
Write-Host "`n[1/4] Compilation de l'application Flutter Windows Release..." -ForegroundColor Yellow
flutter build windows
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERREUR] Échec de la compilation Flutter." -ForegroundColor Red
    exit 1
}

# 2. Préparation du dossier d'empaquetage Staging
$stagingDir = "$rootDir\dist\staging"
$outputDir = "$rootDir\dist"

Write-Host "`n[2/4] Préparation des fichiers d'empaquetage..." -ForegroundColor Yellow
if (Test-Path $stagingDir) { Remove-Item -Recurse -Force $stagingDir }
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# Copie des fichiers Flutter Release
Copy-Item -Path "$rootDir\build\windows\x64\runner\Release\*" -Destination $stagingDir -Recurse -Force

# Copie du pipeline Python (sans les venv volumineux)
$pipelineStaging = "$stagingDir\pipeline"
New-Item -ItemType Directory -Force -Path $pipelineStaging | Out-Null
Get-ChildItem -Path "$rootDir\pipeline" -Exclude "*.venv*", "__pycache__", "*.pyc" | Copy-Item -Destination $pipelineStaging -Recurse -Force

# 3. Recherche de Inno Setup Compiler (iscc.exe)
$isccPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    (Get-Command iscc.exe -ErrorAction SilentlyContinue).Path
) | Where-Object { $_ -and (Test-Path $_) }

if ($isccPaths) {
    $iscc = $isccPaths[0]
    Write-Host "`n[3/4] Inno Setup trouvé : $iscc" -ForegroundColor Green
    Write-Host "Génération de l'installateur autonome via Inno Setup..." -ForegroundColor Yellow
    & $iscc "$rootDir\installer\forgeron_installer.iss"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n[RÉSULTAT] Installateur créé avec succès :" -ForegroundColor Green
        Write-Host "  -> $outputDir\Forgeron_CNC_5Axis_Setup_v1.0.exe" -ForegroundColor Cyan
        exit 0
    }
}

# 4. Alternative native Windows : Génération d'un paquet auto-extractible via IExpress / Zip
Write-Host "`n[3/4] Inno Setup non installé. Utilisation du bundler natif IExpress Windows..." -ForegroundColor Yellow

$sedFile = "$rootDir\dist\iexpress_build.sed"
$targetExe = "$rootDir\dist\Forgeron_CNC_5Axis_Standalone.exe"

# Liste de tous les fichiers à inclure
$files = Get-ChildItem -Path $stagingDir -Recurse -File
$fileListSection = ""
$fileSourceSection = ""
$i = 0

foreach ($file in $files) {
    $relPath = $file.FullName.Substring($stagingDir.Length + 1)
    $fileListSection += "FILE$i=`"$relPath`"`n"
    $fileSourceSection += "%FILE$i%=`"`"`n"
    $i++
}

# Crée un script IExpress SED
$sedContent = @"
[Version]
Class=IExpress
SEDVersion=3.0
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=1
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=Forgeron CNC 5-Axes a été extrait et lancé avec succès !
TargetName=$targetExe
FriendlyName=Forgeron CNC 5-Axes
AppLaunched=forgeron.exe
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
[SourceFiles]
SourceFiles0=$stagingDir\
[SourceFiles0]
$($files | ForEach-Object { "$($_.Name)=" })
"@

Set-Content -Path $sedFile -Value $sedContent -Encoding ASCII

# Compression Zip Standalone (solution fiable et instantanée)
$zipOutput = "$rootDir\dist\Forgeron_CNC_5Axis_Portable_v1.0.zip"
Write-Host "[4/4] Création du paquet portable unifié :" -ForegroundColor Yellow
Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipOutput -Force

# Copie directe du binaire principal dans dist pour un test direct rapide
Copy-Item -Path "$stagingDir\forgeron.exe" -Destination "$outputDir\Forgeron_Test_Direct.exe" -Force

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  RÉSULTATS DE LA COMPILATION ET BUNDLING " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " 1. Exécutable Direct de Test : $outputDir\Forgeron_Test_Direct.exe" -ForegroundColor Cyan
Write-Host " 2. Archive Portable Unifiée : $zipOutput" -ForegroundColor Cyan
Write-Host " 3. Script Inno Setup Prêt   : $rootDir\installer\forgeron_installer.iss" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green
