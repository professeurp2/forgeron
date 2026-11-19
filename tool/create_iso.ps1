# Script PowerShell de génération d'une image disque unique .ISO pour Forgeron CNC 5-Axes
# Regroupe l'exécutable d'installation et l'archive de données (.bin) en UN SEUL fichier .ISO
# Résultat : dist\Forgeron_CNC_5Axis_v1.0.iso (~14.5 Go)
# Utilisation : Double-cliquer sur le .iso sous Windows 10/11 pour le monter comme un lecteur DVD virtuel

param (
    [string]$DistDir = "$PSScriptRoot\..\dist",
    [string]$IsoFileName = "Forgeron_CNC_5Axis_v1.0.iso"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    FORGERON CNC 5-AXES - CRÉATION DU FICHIER UNIQUE .ISO " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$rootDir = (Resolve-Path "$PSScriptRoot\..").Path
$distPath = (Resolve-Path $DistDir).Path
$targetIso = Join-Path $distPath $IsoFileName

$setupExe = Join-Path $distPath "Forgeron_CNC_5Axis_Setup_v1.0.exe"
$setupBin = Join-Path $distPath "Forgeron_CNC_5Axis_Setup_v1.0-1.bin"

if (-not (Test-Path $setupExe) -or -not (Test-Path $setupBin)) {
    Write-Host "[ERREUR] Les fichiers d'installation (.exe et .bin) sont introuvables dans $distPath." -ForegroundColor Red
    Write-Host "Exécutez d'abord tool\build_single_exe.ps1." -ForegroundColor Yellow
    exit 1
}

$staging = Join-Path $distPath ".iso_staging"
if (Test-Path $staging) {
    Remove-Item -Recurse -Force $staging
}
New-Item -ItemType Directory -Force -Path $staging | Out-Null

Write-Host "`n[1/3] Préparation des fichiers du disque virtuel (liens instantanés)..." -ForegroundColor Yellow

# Lien matériel NTFS pour le gros fichier .bin (0 octet dupliqué, instantané)
New-Item -ItemType HardLink -Path (Join-Path $staging "Forgeron_CNC_5Axis_Setup_v1.0-1.bin") -Target $setupBin | Out-Null
New-Item -ItemType HardLink -Path (Join-Path $staging "Forgeron_CNC_5Axis_Setup_v1.0.exe") -Target $setupExe | Out-Null

# Guides d'installation et documentation
if (Test-Path "$rootDir\INSTALL.txt") {
    Copy-Item "$rootDir\INSTALL.txt" -Destination (Join-Path $staging "INSTALL.txt") -Force
}
if (Test-Path "$rootDir\INSTALL.md") {
    Copy-Item "$rootDir\INSTALL.md" -Destination (Join-Path $staging "INSTALL.md") -Force
}

# Icône du disque
$iconSrc = "$rootDir\windows\runner\resources\app_icon.ico"
if (Test-Path $iconSrc) {
    Copy-Item $iconSrc -Destination (Join-Path $staging "app_icon.ico") -Force
}

# Fichier autorun.inf (icône et libellé automatique sous Windows)
$autorun = @"
[AutoRun]
open=Forgeron_CNC_5Axis_Setup_v1.0.exe
icon=app_icon.ico,0
label=Forgeron CNC 5-Axes
action=Installer Forgeron CNC 5-Axes
"@
Set-Content -Path (Join-Path $staging "autorun.inf") -Value $autorun -Encoding ASCII

# Lanceur batch rapide pour un clic direct
$launcherCmd = @"
@echo off
title Installation de Forgeron CNC 5-Axes
echo ==========================================================
echo        Lancement de l'installateur Forgeron CNC 5-Axes
echo ==========================================================
start "" "%~dp0Forgeron_CNC_5Axis_Setup_v1.0.exe"
"@
Set-Content -Path (Join-Path $staging "INSTALLER_FORGERON.cmd") -Value $launcherCmd -Encoding ASCII

Write-Host "  Contenu du disque prêt :" -ForegroundColor Gray
Get-ChildItem $staging | ForEach-Object {
    $sizeMB = [math]::Round($_.Length / 1MB, 2)
    Write-Host "    - $($_.Name) ($sizeMB Mo)" -ForegroundColor Gray
}

# Classe C# pour flux IStream vers FileStream
Add-Type @"
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

public class IsoStreamSaver {
    public static void Save(object comStream, string destPath) {
        IStream stream = (IStream)comStream;
        using (FileStream fs = new FileStream(destPath, FileMode.Create, FileAccess.Write, FileShare.None, 4 * 1024 * 1024)) {
            byte[] buffer = new byte[4 * 1024 * 1024]; // Tampon de 4 Mo
            IntPtr readPtr = Marshal.AllocHGlobal(sizeof(int));
            try {
                while (true) {
                    stream.Read(buffer, buffer.Length, readPtr);
                    int bytesRead = Marshal.ReadInt32(readPtr);
                    if (bytesRead <= 0) break;
                    fs.Write(buffer, 0, bytesRead);
                }
            } finally {
                Marshal.FreeHGlobal(readPtr);
            }
        }
    }
}
"@ -ErrorAction SilentlyContinue

Write-Host "`n[2/3] Génération du système de fichiers UDF haute capacité via IMAPI2..." -ForegroundColor Yellow
$fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$fsi.FreeMediaBlocks = 25000000 # Capacité maximale 50 Go
$fsi.FileSystemsToCreate = 4    # 4 = FsiFileSystemUDF (supporte les fichiers > 4 Go sans limite)
$fsi.VolumeName = "FORGERON_CNC"

$root = $fsi.Root
$root.AddTree($staging, $false)
$isoResult = $fsi.CreateResultImage()

Write-Host "`n[3/3] Écriture de l'image ISO ($targetIso)..." -ForegroundColor Yellow
$sw = [System.Diagnostics.Stopwatch]::StartNew()
[IsoStreamSaver]::Save($isoResult.ImageStream, $targetIso)
$sw.Stop()

# Nettoyage du dossier temporaire
Remove-Item -Recurse -Force $staging -ErrorAction SilentlyContinue

$isoItem = Get-Item $targetIso
$isoSizeGB = [math]::Round($isoItem.Length / 1GB, 2)

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   CRÉATION DU FICHIER UNIQUE .ISO RÉUSSIE AVEC SUCCÈS   " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Fichier généré : $($isoItem.FullName)" -ForegroundColor Cyan
Write-Host "  Taille finale  : $isoSizeGB Go en UN SEUL FICHIER" -ForegroundColor Cyan
Write-Host "  Temps d'écriture : $([math]::Round($sw.Elapsed.TotalSeconds, 1)) secondes" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  UTILISATION SUR TOUT NOUVEAU PC :" -ForegroundColor Yellow
Write-Host "  1. Copier simplement '$IsoFileName' sur une clé USB ou disque dur." -ForegroundColor White
Write-Host "  2. Double-cliquer sur le fichier .ISO (montage automatique sous Windows)." -ForegroundColor White
Write-Host "  3. Lancer 'Forgeron_CNC_5Axis_Setup_v1.0.exe' ou 'INSTALLER_FORGERON.cmd'." -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green

