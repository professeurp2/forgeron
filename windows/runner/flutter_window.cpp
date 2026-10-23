#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include <audioplayers_windows/audioplayers_windows_plugin.h>
#include <file_selector_windows/file_selector_windows.h>
#include <flutter_secure_storage_windows/flutter_secure_storage_windows_plugin.h>
#include <flutter_tts/flutter_tts_plugin.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>
#include <speech_to_text_windows/speech_to_text_windows.h>
#include <webview_windows/webview_windows_plugin.h>

// FORGERON : liste des mêmes plugins que `RegisterPlugins()`
// (generated_plugin_registrant.cc), MOINS desktop_multi_window lui-même.
//
// Chaque fenêtre créée par desktop_multi_window a son propre moteur Flutter,
// donc ses propres plugins à enregistrer — c'est pour ça que le callback
// ci-dessous existe. Mais desktop_multi_window 0.2.1 configure DÉJÀ, dans son
// propre constructeur natif (FlutterWindow::FlutterWindow, avant d'appeler ce
// callback), le canal propre à CETTE fenêtre avec le bon identifiant.
// Le réenregistrer via RegisterPlugins() le casse : sa fonction
// d'enregistrement suppose toujours qu'elle configure la fenêtre PRINCIPALE
// (id 0), échoue silencieusement (« main window already exists » côté
// natif), et en se détruisant efface le gestionnaire que le plugin venait de
// poser correctement — la fenêtre détachée se retrouve alors sans canal vers
// la fenêtre principale (MissingPluginException sur
// mixin.one/flutter_multi_window_channel au moindre retour). D'où cette
// liste, à tenir à jour avec generated_plugin_registrant.cc SAUF
// desktop_multi_window.
void RegisterPluginsForDetachedWindow(flutter::PluginRegistry* registry) {
  AudioplayersWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AudioplayersWindowsPlugin"));
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
  FlutterSecureStorageWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterSecureStorageWindowsPlugin"));
  FlutterTtsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterTtsPlugin"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
  SpeechToTextWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("SpeechToTextWindows"));
  WebviewWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WebviewWindowsPlugin"));
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  // Chaque fenêtre créée par desktop_multi_window a son propre moteur
  // Flutter : les plugins doivent être ré-enregistrés pour chacune, sinon
  // les fenêtres secondaires (graphiques, G-code détaché) n'ont accès à
  // aucun plugin natif — voir README de desktop_multi_window. MAIS PAS
  // desktop_multi_window lui-même : voir RegisterPluginsForDetachedWindow
  // ci-dessus pour pourquoi ce serait pire que de ne rien faire.
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto *flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    auto *registry = flutter_view_controller->engine();
    RegisterPluginsForDetachedWindow(registry);
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
