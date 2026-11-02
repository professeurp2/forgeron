# Script PowerShell d'empaquetage complet et unifié de Forgeron CNC 5-Axes
# Génère l'installateur autonome complet (Front Flutter, Back Python/OCP/reco3d/Meshroom, Ollama et modèles IA)
# Résultat : dist\Forgeron_CNC_5Axis_Setup_v1.0.exe (+ fichiers .bin associés)

param (
    [switch]$SkipFlutterBuild = $false
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   FORGERON CNC 5-AXES - CRÉATION DU BUILD UNIFIÉ (.EXE)   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$rootDir = (Resolve-Path "$PSScriptRoot\..").Path
Set-Location $rootDir

$stagingDir = "$rootDir\dist\staging"
$outputDir = "$rootDir\dist"

# 1. Compilation Flutter Windows Release
if (-not $SkipFlutterBuild) {
    Write-Host "`n[1/5] Compilation de l'application Flutter Windows Release..." -ForegroundColor Yellow
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERREUR] Échec de la compilation Flutter." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n[1/5] Compilation Flutter sautée (-SkipFlutterBuild)." -ForegroundColor Gray
}

# 2. Préparation du dossier d'empaquetage Staging
Write-Host "`n[2/5] Préparation de l'arborescence de staging unifiée..." -ForegroundColor Yellow
if (Test-Path $stagingDir) {
    Write-Host "  Nettoyage de l'ancien dossier de staging..." -ForegroundColor Gray
    Remove-Item -Recurse -Force $stagingDir
}
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# Copie des fichiers Flutter Release
Write-Host "  Copie des binaires Flutter..." -ForegroundColor Gray
Copy-Item -Path "$rootDir\build\windows\x64\runner\Release\*" -Destination $stagingDir -Recurse -Force

# Manifeste du bundle Forgeron
$bundleManifest = @{
    version = "1.0.0"
    chat_model = "forgeron-qwen"
    vision_model = "gemma3n:latest"
    bundled_services = @("ollama", "reco3d")
    built_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
} | ConvertTo-Json -Depth 3
Set-Content -Path "$stagingDir\forgeron_bundle.json" -Value $bundleManifest -Encoding UTF8

# Copie du pipeline CAO/CAM Python
Write-Host "  Copie des modules pipeline..." -ForegroundColor Gray
$pipelineStaging = "$stagingDir\pipeline"
New-Item -ItemType Directory -Force -Path $pipelineStaging | Out-Null
Get-ChildItem -Path "$rootDir\pipeline" -Exclude "*.venv*", "__pycache__", "*.pyc" | Copy-Item -Destination $pipelineStaging -Recurse -Force

# Copie de reco3d (avec Meshroom)
Write-Host "  Copie du service reco3d et photogrammétrie Meshroom..." -ForegroundColor Gray
$reco3dStaging = "$stagingDir\tool\reco3d"
New-Item -ItemType Directory -Force -Path $reco3dStaging | Out-Null
Get-ChildItem -Path "$rootDir\tool\reco3d" -Exclude "storage", "__pycache__", "*.pyc", ".pytest*" | Copy-Item -Destination $reco3dStaging -Recurse -Force
New-Item -ItemType Directory -Force -Path "$reco3dStaging\storage" | Out-Null

# 3. Préparation de l'environnement Python portable embarqué (runtime/python)
Write-Host "`n[3/5] Préparation du runtime Python 3.12 portable autonome (OCP, uvicorn, scipy...)..." -ForegroundColor Yellow
$pyRuntimeDir = "$stagingDir\runtime\python"
New-Item -ItemType Directory -Force -Path "$pyRuntimeDir\Lib\site-packages" | Out-Null

$srcPy = "$env:LOCALAPPDATA\Programs\Python\Python312"
if (-not (Test-Path $srcPy)) {
    $srcPy = (Get-Command python.exe).Source | Split-Path -Parent
}
Write-Host "  Source Python : $srcPy" -ForegroundColor Gray
Copy-Item "$srcPy\python*.exe", "$srcPy\*.dll" -Destination $pyRuntimeDir -Force
Copy-Item "$srcPy\DLLs" -Destination $pyRuntimeDir -Recurse -Force
Get-ChildItem "$srcPy\Lib" -Exclude "test", "site-packages" | Copy-Item -Destination "$pyRuntimeDir\Lib" -Recurse -Force

# Copie des packages du venv312 (OCP, OpenCASCADE, uvicorn, fastapi, trimesh, scipy...)
Write-Host "  Copie des paquets Python spécialisés depuis pipeline/.venv312..." -ForegroundColor Gray
Copy-Item "$rootDir\pipeline\.venv312\Lib\site-packages\*" -Destination "$pyRuntimeDir\Lib\site-packages" -Recurse -Force

# Copie du script superviseur des services d'arrière-plan
New-Item -ItemType Directory -Force -Path "$stagingDir\runtime" | Out-Null
Copy-Item "$rootDir\installer\forgeron_services.py" -Destination "$stagingDir\runtime\forgeron_services.py" -Force

# 4. Préparation de l'IA locale (Ollama + modèles forgeron-qwen et gemma3n)
Write-Host "`n[4/5] Embarquement du serveur Ollama et des modèles IA sélectionnés..." -ForegroundColor Yellow
$ollamaStaging = "$stagingDir\runtime\ollama"
New-Item -ItemType Directory -Force -Path "$ollamaStaging\models\manifests" | Out-Null
New-Item -ItemType Directory -Force -Path "$ollamaStaging\models\blobs" | Out-Null

$srcOllama = "$env:LOCALAPPDATA\Programs\Ollama"
if (Test-Path "$srcOllama\ollama.exe") {
    Write-Host "  Copie des binaires Ollama (CUDA + Vulkan)..." -ForegroundColor Gray
    Copy-Item "$srcOllama\ollama.exe" -Destination $ollamaStaging -Force
    # Copie de lib/ollama en excluant rocm_v7_1 pour optimiser la taille
    $libOllamaDest = "$ollamaStaging\lib\ollama"
    New-Item -ItemType Directory -Force -Path $libOllamaDest | Out-Null
    Get-ChildItem "$srcOllama\lib\ollama" -Exclude "rocm_v7_1" | Copy-Item -Destination $libOllamaDest -Recurse -Force
} else {
    Write-Host "  [ATTENTION] Ollama non trouvé dans $srcOllama." -ForegroundColor DarkYellow
}

# Modèles IA sélectionnés : forgeron-qwen et gemma3n
$srcModels = "$env:USERPROFILE\.ollama\models"
$targetModels = @(
    "registry.ollama.ai\library\forgeron-qwen\latest",
    "registry.ollama.ai\library\gemma3n\latest"
)

if (Test-Path $srcModels) {
    Write-Host "  Copie des manifestes et blobs des modèles IA (forgeron-qwen & gemma3n)..." -ForegroundColor Gray
    $neededBlobs = @{}
    foreach ($mRel in $targetModels) {
        $mPath = "$srcModels\manifests\$mRel"
        if (Test-Path $mPath) {
            $destMPath = "$ollamaStaging\models\manifests\$mRel"
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destMPath) | Out-Null
            Copy-Item $mPath -Destination $destMPath -Force

            $json = Get-Content $mPath | ConvertFrom-Json
            if ($json.config.digest) { $neededBlobs[$json.config.digest] = $true }
            foreach ($layer in $json.layers) {
                if ($layer.digest) { $neededBlobs[$layer.digest] = $true }
            }
        }
    }

    $blobCount = $neededBlobs.Count
    Write-Host "  Copie de $blobCount blob(s) de modèle vers staging..." -ForegroundColor Gray
    $copied = 0
    foreach ($digest in $neededBlobs.Keys) {
        $blobFileName = $digest -replace ':', '-'
        $srcBlob = "$srcModels\blobs\$blobFileName"
        $destBlob = "$ollamaStaging\models\blobs\$blobFileName"
        if (Test-Path $srcBlob) {
            Copy-Item $srcBlob -Destination $destBlob -Force
            $copied++
        }
    }
    Write-Host "  $copied / $blobCount blobs copiés avec succès." -ForegroundColor Green
} else {
    Write-Host "  [ATTENTION] Dossier modèles non trouvé dans $srcModels." -ForegroundColor DarkYellow
}

# 5. Compilation Inno Setup (.exe + .bin)
Write-Host "`n[5/5] Génération de l'installateur autonome via Inno Setup Compiler..." -ForegroundColor Yellow
$isccPaths = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    (Get-Command iscc.exe -ErrorAction SilentlyContinue).Path
) | Where-Object { $_ -and (Test-Path $_) }

if (-not $isccPaths) {
    Write-Host "[ERREUR] Inno Setup Compiler (ISCC.exe) introuvable." -ForegroundColor Red
    exit 1
}

$iscc = $isccPaths[0]
Write-Host "  Inno Setup trouvé : $iscc" -ForegroundColor Green
Write-Host "  Lancement de la compilation Inno Setup (peut prendre quelques minutes)..." -ForegroundColor Yellow

& $iscc "$rootDir\installer\forgeron_installer.iss"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERREUR] Échec de la compilation Inno Setup (Code $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   BUILD DU SYSTÈME UNIFIÉ FORGERON RÉUSSI AVEC SUCCÈS   " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

Get-ChildItem -Path $outputDir -Filter "Forgeron_CNC_5Axis_Setup*" | ForEach-Object {
    $sizeMB = [math]::Round($_.Length / 1MB, 2)
    Write-Host "  -> $($_.FullName) ($sizeMB Mo)" -ForegroundColor Cyan
}

Write-Host "==========================================================" -ForegroundColor Green
