================================================================================
           FORGERON CNC 5-AXES — DISTRIBUTION GUIDE & CONFIGURATION
================================================================================
Version : 1.0.0 (Windows & Android Production Release)
Publisher : Forgeron Project — ENI Unipods

--------------------------------------------------------------------------------
1. RECOMMENDED MAIN DELIVERABLE: SINGLE .ISO DISC IMAGE
--------------------------------------------------------------------------------

To deploy Forgeron on a Windows PC without the risk of losing companion files:

  -> dist\Forgeron_CNC_5Axis_v1.0.iso (~14.5 GB)

USAGE ON TARGET PC:
1. Copy ONLY "Forgeron_CNC_5Axis_v1.0.iso" to your USB drive.
2. On the target PC, simply DOUBLE-CLICK the .iso file.
   Windows mounts it automatically as a virtual drive named "FORGERON_CNC".
3. Run "Forgeron_CNC_5Axis_Setup_v1.0.exe" or "INSTALLER_FORGERON.cmd".
4. When installation finishes, right-click the virtual drive > "Eject".

--------------------------------------------------------------------------------
2. ALTERNATIVE SEPARATE INSTALLATION FILES (WINDOWS)
--------------------------------------------------------------------------------

- Forgeron_CNC_5Axis_Setup_v1.0.exe      (~3.6 MB) : Setup installer wizard
- Forgeron_CNC_5Axis_Setup_v1.0-1.bin   (~14.5 GB) : Unified data archive
(Both files must strictly remain in the same directory).

--------------------------------------------------------------------------------
3. ANDROID MOBILE APPLICATION (.APK) — INSTALLATION & SETUP
--------------------------------------------------------------------------------

A. COMPILING & INSTALLING THE APK:
1. To compile the Android APK:
   flutter build apk --release
   (Generated file: build/app/outputs/flutter-apk/app-release.apk)
2. Transfer the .apk file to your workshop Android smartphone or tablet.
3. Allow installation from unknown sources if prompted.
4. Grant required permissions on first launch:
   - Camera     : Visual inspection of raw stock and tools by the AI.
   - Microphone : Voice dictation and workshop commands (French / Bambara).
   - Wi-Fi      : Direct connection to the FluidNC ESP32 CNC controller.

B. INITIAL SETUP: ADDING THE GEMINI API KEY:

To enable multimodal AI assistance (text + vision), configure your personal
Google Gemini API key (free at https://aistudio.google.com):

----------------------------------------------------------------------
GEMINI_API_KEY: YOUR_API_KEY_HERE
----------------------------------------------------------------------

STEP-BY-STEP IN-APP SETUP:
1. Open the Forgeron app on your phone / tablet.
2. Tap the "Settings" gear icon (top right corner).
   [SCREENSHOT 1: Accessing application settings]
3. Select "AI Agent" (Agent IA).
   [SCREENSHOT 2: AI Agent settings menu]
4. Scroll down to the "Gemini API Key" section.
5. Paste your API key into the text field and tap "Save" (Enregistrer).
   [SCREENSHOT 3: Entering the Gemini API key]
6. A banner confirms: "API Key saved".
   The key is stored encrypted in the device hardware keystore (Android Keystore).
   [SCREENSHOT 4: Key confirmation]
7. Go to the "AI Assistant" tab and send a message or capture a photo.
   [SCREENSHOT 5: Active chat and vision testing]

C. CONNECTING TO THE CNC MACHINE FROM THE APK:
1. Connect your smartphone to the workshop Wi-Fi or machine AP.
2. Open the "Connection" tab.
3. Tap "Scan Network" or enter the CNC controller IP (e.g., 192.168.4.1).
4. Tap "Connect" to view real-time telemetry and motion controls.

--------------------------------------------------------------------------------
4. BUILD COMMANDS (WINDOWS INSTALLER & ISO IMAGE)
--------------------------------------------------------------------------------

All commands run from PowerShell at the root of the project:

A. FULL END-TO-END BUILD COMMAND (Recommended):
   Compiles Flutter Release, prepares Python/OCP, bundles Ollama & models,
   runs Inno Setup compression, and produces the single .ISO image:
   
   powershell -ExecutionPolicy Bypass -File tool\build_single_exe.ps1

B. FAST BUILD COMMAND (Without recompiling Flutter):
   Builds the installer and ISO image with pre-compiled Flutter binaries:
   
   powershell -ExecutionPolicy Bypass -File tool\build_single_exe.ps1 -SkipFlutterBuild

C. EXPRESS ISO RE-GENERATION (~25 seconds):
   Rebuilds the ISO image from existing .exe and .bin files in dist/:
   
   powershell -ExecutionPolicy Bypass -File tool\create_iso.ps1

--------------------------------------------------------------------------------
5. DIAGNOSTICS & TROUBLESHOOTING
--------------------------------------------------------------------------------

- Windows app closes immediately: VC++ runtimes (msvcp140.dll...) are bundled.
  Check the diagnostic log at: %LOCALAPPDATA%\Forgeron\logs\startup.log
- Windows 3D simulation: Requires Microsoft Edge WebView2 Evergreen Runtime.
- Mobile AI silent: Verify your phone's Internet connectivity and that your
  Gemini API key is valid.

================================================================================
                        FORGERON PROJECT — ENI UNIPODS
================================================================================
