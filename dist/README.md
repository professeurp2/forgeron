# Forgeron CNC 5-Axes — Distribution Guide & Mobile Configuration

This folder contains the standalone offline installation packages, build commands, and initial setup procedures for the **Forgeron CNC 5-Axes** application (Windows & Android).

---

## 💿 1. Recommended Main Deliverable: Single `.ISO` Disc Image

To deploy the application on another Windows PC without the risk of losing companion files:

| File | Size | Description |
| :--- | :--- | :--- |
| **`Forgeron_CNC_5Axis_v1.0.iso`** | **~14.5 GB** | **Complete standalone single file** (contains the installer, offline AI models archive, C++ runtime dependencies, Python/OCP, and automatic launcher). |

### 🚀 Usage on Target PC:
1. Copy **only** the `Forgeron_CNC_5Axis_v1.0.iso` file onto a USB flash drive or external hard drive.
2. On the target PC, simply **double-click** the `.iso` file. Windows 10/11 will instantly mount it as a virtual DVD drive named **`FORGERON_CNC`**.
3. Launch the setup wizard by double-clicking `Forgeron_CNC_5Axis_Setup_v1.0.exe` or `INSTALLER_FORGERON.cmd`.
4. Once installation is complete, right-click the virtual drive in Windows Explorer > **Eject**.

---

## 📦 2. Alternative Separate Installation Files

For environments requiring files to be handled outside an ISO container:

| File | Size | Description |
| :--- | :--- | :--- |
| **`Forgeron_CNC_5Axis_Setup_v1.0.exe`** | ~3.6 MB | Setup wizard with promotional showcase carousel and prerequisite checks. |
| **`Forgeron_CNC_5Axis_Setup_v1.0-1.bin`** | ~14.5 GB | Compressed data archive containing the offline application and AI models. |

> [!IMPORTANT]
> When using this method, both the `.exe` and `.bin` files must strictly remain in the **same directory**.

---

## 📱 3. Android Mobile Application (.APK) — Installation & Initial Setup

The Forgeron application is also available as an **APK** for workshop Android smartphones and tablets, offering responsive touch control, bilingual voice commands, and multimodal AI vision assistance.

### A. Building & Installing the APK
1. **Compilation (from project root terminal):**
   ```bash
   flutter build apk --release
   ```
   *The generated package is located at: `build/app/outputs/flutter-apk/app-release.apk`.*
2. **Transfer & Installation:**
   - Transfer the `.apk` file to your Android device (via USB cable, WhatsApp, Google Drive, or local share).
   - Tap the file to install and allow *« Install unknown apps »* if prompted by Android security settings.
   - Grant the required permissions on first launch:
     - 📷 **Camera:** For visual inspection of raw stock, tool verification, and machining defect analysis.
     - 🎙️ **Microphone:** For workshop dictation and voice commands (French / Bambara).
     - 📡 **Local Network (Wi-Fi):** To communicate directly with the FluidNC ESP32 CNC controller.

---

### B. Initial Setup: Adding the Gemini API Key

To enable advanced multimodal reasoning, natural language command parsing, and assisted G-code generation, the application interfaces with the Google Gemini API.

#### 🔑 Your Gemini API Key:
> Paste your personal API key into the placeholder below:
```text
GEMINI_API_KEY: YOUR_API_KEY_HERE
```

*(You can generate or renew a free API key at [Google AI Studio](https://aistudio.google.com/app/apikey)).*

---

#### 🛠️ Step-by-Step In-App Setup:

1. **Open Application Settings:**  
   From the main screen of the Forgeron mobile app, tap the **Settings** gear icon (⚙️) in the top-right corner or navigation menu.

   <!-- Screenshot Placeholder 1: Home screen and settings access -->
   ![Access to Settings](docs/screenshots/android_01_menu_settings.png)

2. **Navigate to "AI Agent":**  
   From the settings menu list, tap **AI Agent** (Agent IA).

   <!-- Screenshot Placeholder 2: AI Agent settings menu -->
   ![AI Agent Settings](docs/screenshots/android_02_ai_settings.png)

3. **Enter the Gemini API Key:**  
   - Scroll down to the **Gemini API Key** section.
   - Paste your API key into the text field.
   - Tap the **Save** (Enregistrer) button.

   <!-- Screenshot Placeholder 3: Entering and saving the API key -->
   ![Entering the Gemini API Key](docs/screenshots/android_03_enter_gemini_key.png)

4. **Validation & Secure Storage:**  
   - A confirmation banner will appear: *« API Key saved »*.
   - The key is securely encrypted inside the device hardware keystore (*Android Keystore*).
   - The AI agent automatically activates the cloud Gemini engine.

   <!-- Screenshot Placeholder 4: API key confirmation -->
   ![Confirmation of API Key](docs/screenshots/android_04_key_confirmed.png)

5. **Test AI Agent Interaction:**  
   - Return to the **AI Assistant** tab.
   - The indicator badge at the top will confirm the active agent status.
   - Send an initial prompt (e.g., *« Hello, can you check the machine status? »*) or snap a photo of raw stock to verify the multimodal pipeline.

   <!-- Screenshot Placeholder 5: Active chat and vision test -->
   ![Testing Mobile AI Assistant](docs/screenshots/android_05_chat_test.png)

---

### C. Connecting to the CNC Machine from the APK
1. Connect your smartphone to the workshop Wi-Fi network (or directly to the machine's ESP32 Wi-Fi Access Point).
2. Go to the **Connection** (Connexion) tab in the app.
3. Tap **Scan Network** or manually enter the CNC controller IP address (e.g., `192.168.4.1` or `192.168.1.150`).
4. Tap **Connect**: real-time kinematics telemetry (X/Y/Z/A/B coordinates, spindle state, alarms) will display immediately.

---

## 🛠️ 4. Build Commands (Windows Installer & ISO)

All Windows build commands should be executed from a PowerShell prompt at the root of the `forgeron` project:

### A. Full End-to-End Build Command (Recommended)
Recompiles the Flutter client in Windows Release mode, packages the standalone Python/OCP runtime, bundles the Ollama server and AI models, runs Inno Setup compression, and automatically generates the single `.iso` image:
```powershell
powershell -ExecutionPolicy Bypass -File tool\build_single_exe.ps1
```

### B. Fast Build Command (Skipping Flutter Compilation)
If Flutter source code has not changed and you only need to rebuild the installer and the `.iso` image:
```powershell
powershell -ExecutionPolicy Bypass -File tool\build_single_exe.ps1 -SkipFlutterBuild
```

### C. Express ISO Re-generation (~25 seconds)
If the installer (`.exe` and `.bin`) is already built in `dist/` and you only want to generate or regenerate the `.iso` disk image:
```powershell
powershell -ExecutionPolicy Bypass -File tool\create_iso.ps1
```

---

## 🔍 5. Troubleshooting & Diagnostics

- **Windows application closes immediately after launch on a clean PC:**  
  All required Microsoft Visual C++ 2015–2022 runtimes (`msvcp140.dll`, `vcruntime140.dll`, etc.) are bundled directly within the package. In case of any startup issue, review the diagnostic log:  
  `%LOCALAPPDATA%\Forgeron\logs\startup.log`
- **Windows 3D simulation unavailable:**  
  Install the free [Microsoft Edge WebView2 Evergreen Runtime](https://go.microsoft.com/fwlink/p/?LinkId=2124703).
- **Mobile AI Agent not responding:**  
  Ensure your smartphone has an active Internet connection (Wi-Fi or cellular data) to reach the Gemini API endpoint, and verify that your Gemini API key has not expired.

---

*Forgeron CNC 5-Axes Project — ENI Unipods Bamako.*
