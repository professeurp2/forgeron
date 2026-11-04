#include "speech_to_text_windows_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <chrono>
#include <optional>
#include <sstream>

namespace speech_to_text_windows {

namespace {

constexpr int kPartialResult = 0;
constexpr int kFinalResult = 2;

// L'original concaténait le texte reconnu tel quel dans le JSON : un
// guillemet ou une barre oblique inverse cassait le message entier.
std::string JsonEscape(const std::string &s) {
  std::ostringstream o;
  for (const unsigned char c : s) {
    switch (c) {
      case '"': o << "\\\""; break;
      case '\\': o << "\\\\"; break;
      case '\n': o << "\\n"; break;
      case '\r': o << "\\r"; break;
      case '\t': o << "\\t"; break;
      default:
        if (c < 0x20) {
          char buf[8];
          snprintf(buf, sizeof(buf), "\\u%04x", c);
          o << buf;
        } else {
          o << c;
        }
    }
  }
  return o.str();
}

std::string ResultJson(const std::string &text, bool is_final) {
  const std::string t = JsonEscape(text);
  return "{\"recognizedWords\":\"" + t + "\",\"finalResult\":" +
         (is_final ? "true" : "false") + ",\"alternates\":[{\"recognizedWords\":\"" + t +
         "\",\"confidence\":0.85}],\"resultType\":" +
         std::to_string(is_final ? kFinalResult : kPartialResult) + "}";
}

std::string ErrorJson(const std::string &code) {
  return "{\"errorMsg\":\"" + JsonEscape(code) + "\",\"permanent\":true}";
}

std::wstring HelperPath() {
  wchar_t path[MAX_PATH] = {};
  GetModuleFileNameW(nullptr, path, MAX_PATH);
  std::wstring p(path);
  const auto slash = p.find_last_of(L"\\/");
  return (slash == std::wstring::npos ? std::wstring() : p.substr(0, slash + 1)) +
         L"forgeron_dictation.exe";
}

}  // namespace

void SpeechToTextWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<SpeechToTextWindowsPlugin>(registrar);
  plugin->channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "speech_to_text_windows",
      &flutter::StandardMethodCodec::GetInstance());
  plugin->channel_->SetMethodCallHandler(
      [p = plugin.get()](const auto &call, auto result) {
        p->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

SpeechToTextWindowsPlugin::SpeechToTextWindowsPlugin(
    flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {
  dispatch_message_ = RegisterWindowMessageW(L"ForgeronSpeechToTextDispatch");
  // Les messages reçus par la fenêtre principale arrivent sur le fil
  // principal : c'est là, et seulement là, qu'on parle au canal Dart.
  window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
      [this](HWND, UINT message, WPARAM, LPARAM) -> std::optional<LRESULT> {
        if (message == dispatch_message_) {
          DrainPlatformQueue();
          return 0;
        }
        return std::nullopt;
      });
}

SpeechToTextWindowsPlugin::~SpeechToTextWindowsPlugin() {
  if (to_helper_) {
    SendCommand("QUIT");
    CloseHandle(to_helper_);  // le programme s'arrête aussi si son entrée se ferme
    to_helper_ = nullptr;
  }
  if (process_) {
    if (WaitForSingleObject(process_, 2000) == WAIT_TIMEOUT) TerminateProcess(process_, 0);
    CloseHandle(process_);
  }
  if (reader_.joinable()) reader_.join();
  if (from_helper_) CloseHandle(from_helper_);
  if (window_proc_id_ >= 0) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  }
}

bool SpeechToTextWindowsPlugin::StartHelper() {
  SECURITY_ATTRIBUTES sa = {sizeof(sa), nullptr, TRUE};
  HANDLE child_in_read = nullptr, child_in_write = nullptr;
  HANDLE child_out_read = nullptr, child_out_write = nullptr;
  if (!CreatePipe(&child_in_read, &child_in_write, &sa, 0)) return false;
  if (!CreatePipe(&child_out_read, &child_out_write, &sa, 0)) {
    CloseHandle(child_in_read);
    CloseHandle(child_in_write);
    return false;
  }
  // Les extrémités gardées par Forgeron ne doivent pas être héritées.
  SetHandleInformation(child_in_write, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(child_out_read, HANDLE_FLAG_INHERIT, 0);

  STARTUPINFOW si = {};
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESTDHANDLES;
  si.hStdInput = child_in_read;
  si.hStdOutput = child_out_write;
  si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
  PROCESS_INFORMATION pi = {};
  std::wstring path = HelperPath();
  std::wstring cmd = L"\"" + path + L"\"";
  const BOOL ok = CreateProcessW(path.c_str(), &cmd[0], nullptr, nullptr, TRUE,
                                 CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi);
  CloseHandle(child_in_read);
  CloseHandle(child_out_write);
  if (!ok) {
    CloseHandle(child_in_write);
    CloseHandle(child_out_read);
    return false;
  }
  CloseHandle(pi.hThread);
  process_ = pi.hProcess;
  to_helper_ = child_in_write;
  from_helper_ = child_out_read;
  reader_ = std::thread([this] { ReadHelper(); });
  return true;
}

void SpeechToTextWindowsPlugin::ReadHelper() {
  std::string pending;
  char buf[1024];
  DWORD read = 0;
  while (ReadFile(from_helper_, buf, sizeof(buf), &read, nullptr) && read > 0) {
    pending.append(buf, read);
    size_t nl;
    while ((nl = pending.find('\n')) != std::string::npos) {
      std::string line = pending.substr(0, nl);
      if (!line.empty() && line.back() == '\r') line.pop_back();
      pending.erase(0, nl + 1);
      HandleHelperLine(line);
    }
  }
  // Programme terminé : l'initialisation éventuelle en attente échoue.
  std::lock_guard<std::mutex> lock(mutex_);
  if (!ready_done_) {
    ready_done_ = true;
    ready_ok_ = false;
    ready_cv_.notify_all();
  }
}

void SpeechToTextWindowsPlugin::HandleHelperLine(const std::string &line) {
  auto starts = [&](const char *p) { return line.rfind(p, 0) == 0; };
  if (starts("READY ")) {
    std::lock_guard<std::mutex> lock(mutex_);
    const std::string rest = line.substr(6);
    const auto sp = rest.find(' ');
    locale_ = rest.substr(0, sp);
    if (sp != std::string::npos) locale_name_ = rest.substr(sp + 1);
    ready_done_ = true;
    ready_ok_ = true;
    ready_cv_.notify_all();
  } else if (starts("FAIL")) {
    std::lock_guard<std::mutex> lock(mutex_);
    ready_done_ = true;
    ready_ok_ = false;
    ready_cv_.notify_all();
  } else if (starts("LISTENING")) {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      transcript_.clear();
    }
    PostToPlatform("notifyStatus", "listening");
  } else if (starts("STOPPED")) {
    std::string final_text;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      final_text.swap(transcript_);
    }
    // La transcription complète part AVANT la fin d'écoute : le champ de
    // saisie garde tout ce qui a été dit.
    if (!final_text.empty()) PostToPlatform("textRecognition", ResultJson(final_text, true));
    PostToPlatform("notifyStatus", "notListening");
    PostToPlatform("notifyStatus", "done");
  } else if (starts("SOUND")) {
    PostToPlatform("notifyStatus", "soundDetected");
  } else if (starts("RECO ") || starts("HYPO ")) {
    const bool final_phrase = starts("RECO ");
    const std::string text = line.substr(5);
    if (text.empty()) return;
    std::string shown;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if (final_phrase) {
        transcript_ = transcript_.empty() ? text : transcript_ + " " + text;
        shown = transcript_;
      } else {
        shown = transcript_.empty() ? text : transcript_ + " " + text;
      }
    }
    PostToPlatform("textRecognition", ResultJson(shown, false));
  } else if (starts("ERR ")) {
    PostToPlatform("notifyError", ErrorJson("error_audio_error"));
    PostToPlatform("notifyStatus", "notListening");
  }
}

void SpeechToTextWindowsPlugin::SendCommand(const char *command) {
  if (!to_helper_) return;
  std::string line = std::string(command) + "\n";
  DWORD written = 0;
  WriteFile(to_helper_, line.data(), static_cast<DWORD>(line.size()), &written, nullptr);
}

void SpeechToTextWindowsPlugin::PostToPlatform(std::string method, std::string argument) {
  {
    std::lock_guard<std::mutex> lock(queue_mutex_);
    queue_.emplace_back(std::move(method), std::move(argument));
  }
  HWND view = registrar_->GetView() ? registrar_->GetView()->GetNativeWindow() : nullptr;
  HWND root = view ? GetAncestor(view, GA_ROOT) : nullptr;
  if (root) PostMessageW(root, dispatch_message_, 0, 0);
}

void SpeechToTextWindowsPlugin::DrainPlatformQueue() {
  std::deque<std::pair<std::string, std::string>> pending;
  {
    std::lock_guard<std::mutex> lock(queue_mutex_);
    pending.swap(queue_);
  }
  for (auto &item : pending) {
    if (channel_) {
      channel_->InvokeMethod(item.first,
                             std::make_unique<flutter::EncodableValue>(item.second));
    }
  }
}

void SpeechToTextWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string &name = call.method_name();

  if (name == "hasPermission") {
    result->Success(flutter::EncodableValue(true));
  } else if (name == "initialize") {
    std::unique_lock<std::mutex> lock(mutex_);
    if (!process_) {
      lock.unlock();
      const bool started = StartHelper();
      lock.lock();
      if (!started) {
        ready_done_ = true;
        ready_ok_ = false;
      }
    }
    ready_cv_.wait_for(lock, std::chrono::seconds(10), [this] { return ready_done_; });
    result->Success(flutter::EncodableValue(ready_done_ && ready_ok_));
  } else if (name == "listen") {
    bool ok;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      ok = ready_done_ && ready_ok_;
    }
    if (!ok) {
      result->Error("NOT_INITIALIZED", "Speech recognition not initialized");
      return;
    }
    SendCommand("START");
    result->Success(flutter::EncodableValue(true));
  } else if (name == "stop" || name == "cancel") {
    SendCommand("STOP");
    result->Success();
  } else if (name == "locales") {
    std::lock_guard<std::mutex> lock(mutex_);
    flutter::EncodableList locales;
    locales.push_back(flutter::EncodableValue(locale_ + ":" + locale_name_));
    result->Success(flutter::EncodableValue(locales));
  } else {
    result->NotImplemented();
  }
}

}  // namespace speech_to_text_windows
