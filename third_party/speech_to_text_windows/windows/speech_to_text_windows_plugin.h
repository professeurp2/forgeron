#ifndef FLUTTER_PLUGIN_SPEECH_TO_TEXT_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_SPEECH_TO_TEXT_WINDOWS_PLUGIN_H_

// Copie corrigée de speech_to_text_windows 1.0.1 pour Forgeron (voir
// README-FORGERON.md). Le moteur SAPI vit sur son propre fil (COM initialisé
// sur ce fil) et les résultats repassent par le fil principal de Flutter via
// la boucle de messages de la fenêtre : l'original les envoyait directement
// depuis un fil d'arrière-plan, et ils ne remontaient jamais jusqu'à Dart.

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <atomic>
#include <condition_variable>
#include <deque>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

namespace speech_to_text_windows {

class SpeechToTextWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  explicit SpeechToTextWindowsPlugin(flutter::PluginRegistrarWindows *registrar);
  virtual ~SpeechToTextWindowsPlugin();

  SpeechToTextWindowsPlugin(const SpeechToTextWindowsPlugin &) = delete;
  SpeechToTextWindowsPlugin &operator=(const SpeechToTextWindowsPlugin &) = delete;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Fil du moteur : crée, possède et détruit tous les objets SAPI.
  void EngineThread();

  // Met un appel Dart en file et réveille le fil principal.
  void PostToPlatform(std::string method, std::string argument);
  void DrainPlatformQueue();

  flutter::PluginRegistrarWindows *registrar_;
  int window_proc_id_ = -1;
  UINT dispatch_message_;

  std::thread engine_;
  std::mutex mutex_;
  std::condition_variable init_cv_;
  bool init_done_ = false;
  bool init_ok_ = false;
  std::string locale_ = "fr-FR";
  std::string locale_name_ = "Français";

  std::atomic<bool> quit_{false};
  std::atomic<bool> want_listening_{false};
  HANDLE wake_ = nullptr;  // réveille le fil du moteur (écoute, arrêt, sortie)

  std::mutex queue_mutex_;
  std::deque<std::pair<std::string, std::string>> queue_;
};

}  // namespace speech_to_text_windows

#endif  // FLUTTER_PLUGIN_SPEECH_TO_TEXT_WINDOWS_PLUGIN_H_
