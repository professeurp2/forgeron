#ifndef FLUTTER_PLUGIN_SPEECH_TO_TEXT_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_SPEECH_TO_TEXT_WINDOWS_PLUGIN_H_

// Copie corrigée de speech_to_text_windows 1.0.1 pour Forgeron (voir
// README-FORGERON.md). La dictée SAPI tourne dans un processus à part
// (forgeron_dictation.exe, voir dictation_helper.cpp) et ses résultats
// repassent par le fil principal de Flutter via la boucle de messages de la
// fenêtre.

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <condition_variable>
#include <deque>
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

  bool StartHelper();
  void ReadHelper();
  void HandleHelperLine(const std::string &line);
  void SendCommand(const char *command);

  // Met un appel Dart en file et réveille le fil principal.
  void PostToPlatform(std::string method, std::string argument);
  void DrainPlatformQueue();

  flutter::PluginRegistrarWindows *registrar_;
  int window_proc_id_ = -1;
  UINT dispatch_message_;

  HANDLE process_ = nullptr;
  HANDLE to_helper_ = nullptr;    // écriture : commandes
  HANDLE from_helper_ = nullptr;  // lecture : évènements
  std::thread reader_;

  std::mutex mutex_;
  std::condition_variable ready_cv_;
  bool ready_done_ = false;
  bool ready_ok_ = false;
  std::string locale_ = "fr-FR";
  std::string locale_name_ = "Français";
  std::string transcript_;  // phrases finales de l'écoute en cours

  std::mutex queue_mutex_;
  std::deque<std::pair<std::string, std::string>> queue_;
};

}  // namespace speech_to_text_windows

#endif  // FLUTTER_PLUGIN_SPEECH_TO_TEXT_WINDOWS_PLUGIN_H_
