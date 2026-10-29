#include "speech_to_text_windows_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <sapi.h>

#include <chrono>
#include <optional>
#include <sstream>

namespace speech_to_text_windows {

namespace {

constexpr int kPartialResult = 0;
constexpr int kFinalResult = 2;

std::string ToUtf8(const wchar_t *w) {
  if (!w) return std::string();
  const int size = WideCharToMultiByte(CP_UTF8, 0, w, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) return std::string();
  std::string out(size - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w, -1, &out[0], size, nullptr, nullptr);
  return out;
}

// L'original concaténait le texte reconnu tel quel dans le JSON : une
// apostrophe passait, mais un guillemet ou une barre oblique inverse cassait
// le message entier.
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

std::string ResultText(ISpRecoResult *result) {
  std::string text;
  LPWSTR w = nullptr;
  if (SUCCEEDED(result->GetText(SP_GETWHOLEPHRASE, SP_GETWHOLEPHRASE, TRUE, &w, nullptr)) && w) {
    text = ToUtf8(w);
    CoTaskMemFree(w);
  }
  return text;
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
  wake_ = CreateEventW(nullptr, FALSE, FALSE, nullptr);
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
  quit_ = true;
  if (wake_) SetEvent(wake_);
  if (engine_.joinable()) engine_.join();
  if (window_proc_id_ >= 0) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  }
  if (wake_) CloseHandle(wake_);
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
    if (!engine_.joinable()) {
      engine_ = std::thread([this] { EngineThread(); });
    }
    init_cv_.wait_for(lock, std::chrono::seconds(10), [this] { return init_done_; });
    result->Success(flutter::EncodableValue(init_done_ && init_ok_));
  } else if (name == "listen") {
    bool ok;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      ok = init_done_ && init_ok_;
    }
    if (!ok) {
      result->Error("NOT_INITIALIZED", "Speech recognition not initialized");
      return;
    }
    want_listening_ = true;
    SetEvent(wake_);
    result->Success(flutter::EncodableValue(true));
  } else if (name == "stop" || name == "cancel") {
    want_listening_ = false;
    SetEvent(wake_);
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

void SpeechToTextWindowsPlugin::EngineThread() {
  // Tous les objets SAPI naissent, vivent et meurent sur CE fil.
  const HRESULT co = CoInitializeEx(nullptr, COINIT_MULTITHREADED);

  ISpRecognizer *recognizer = nullptr;
  ISpAudio *audio = nullptr;
  ISpRecoContext *context = nullptr;
  ISpRecoGrammar *grammar = nullptr;
  HANDLE notify = nullptr;

  bool ok = SUCCEEDED(CoCreateInstance(CLSID_SpInprocRecognizer, nullptr,
                                       CLSCTX_INPROC_SERVER, IID_ISpRecognizer,
                                       reinterpret_cast<void **>(&recognizer)));
  ok = ok && SUCCEEDED(CoCreateInstance(CLSID_SpMMAudioIn, nullptr, CLSCTX_INPROC_SERVER,
                                        IID_ISpAudio, reinterpret_cast<void **>(&audio)));
  ok = ok && SUCCEEDED(recognizer->SetInput(audio, TRUE));
  ok = ok && SUCCEEDED(recognizer->CreateRecoContext(&context));
  if (ok) {
    const ULONGLONG interest =
        SPFEI(SPEI_RECOGNITION) | SPFEI(SPEI_HYPOTHESIS) | SPFEI(SPEI_SOUND_START) |
        SPFEI(SPEI_SOUND_END) | SPFEI(SPEI_FALSE_RECOGNITION);
    ok = SUCCEEDED(context->SetInterest(interest, interest)) &&
         SUCCEEDED(context->SetNotifyWin32Event());
    notify = ok ? context->GetNotifyEventHandle() : nullptr;
    ok = ok && notify != nullptr;
  }
  ok = ok && SUCCEEDED(context->CreateGrammar(0, &grammar));
  ok = ok && SUCCEEDED(grammar->LoadDictation(nullptr, SPLO_STATIC));

  // Langue réelle du reconnaisseur (attribut « Language », LCID hexadécimal),
  // au lieu de la liste en dur « en-US / en-GB » de l'original.
  if (ok) {
    ISpObjectToken *token = nullptr;
    if (SUCCEEDED(recognizer->GetRecognizer(&token)) && token) {
      ISpDataKey *attributes = nullptr;
      if (SUCCEEDED(token->OpenKey(L"Attributes", &attributes)) && attributes) {
        LPWSTR lang = nullptr;
        if (SUCCEEDED(attributes->GetStringValue(L"Language", &lang)) && lang) {
          const LCID lcid = static_cast<LCID>(wcstoul(lang, nullptr, 16));
          wchar_t name[LOCALE_NAME_MAX_LENGTH] = {};
          wchar_t display[128] = {};
          if (LCIDToLocaleName(lcid, name, LOCALE_NAME_MAX_LENGTH, 0) > 0) {
            GetLocaleInfoEx(name, LOCALE_SLOCALIZEDLANGUAGENAME, display, 128);
            std::lock_guard<std::mutex> lock(mutex_);
            locale_ = ToUtf8(name);
            locale_name_ = ToUtf8(display);
          }
          CoTaskMemFree(lang);
        }
        attributes->Release();
      }
      token->Release();
    }
  }

  {
    std::lock_guard<std::mutex> lock(mutex_);
    init_done_ = true;
    init_ok_ = ok;
  }
  init_cv_.notify_all();

  bool listening = false;
  std::string transcript;  // phrases finales de la séance d'écoute

  while (ok && !quit_) {
    HANDLE handles[2] = {wake_, notify};
    WaitForMultipleObjects(2, handles, FALSE, 200);

    const bool want = want_listening_.load();
    if (want != listening) {
      if (SUCCEEDED(grammar->SetDictationState(want ? SPRS_ACTIVE : SPRS_INACTIVE))) {
        listening = want;
        if (listening) {
          transcript.clear();
          PostToPlatform("notifyStatus", "listening");
        } else {
          // La transcription complète part comme résultat final AVANT la
          // fin d'écoute : le champ de saisie garde tout ce qui a été dit.
          if (!transcript.empty()) {
            PostToPlatform("textRecognition", ResultJson(transcript, true));
            transcript.clear();
          }
          PostToPlatform("notifyStatus", "notListening");
          PostToPlatform("notifyStatus", "done");
        }
      } else if (want) {
        want_listening_ = false;
        PostToPlatform("notifyError",
                       "{\"errorMsg\":\"error_audio_error\",\"permanent\":true}");
      }
    }

    SPEVENT event;
    ULONG fetched = 0;
    while (SUCCEEDED(context->GetEvents(1, &event, &fetched)) && fetched > 0) {
      if (listening) {
        switch (event.eEventId) {
          case SPEI_RECOGNITION: {
            auto *r = reinterpret_cast<ISpRecoResult *>(event.lParam);
            const std::string text = r ? ResultText(r) : std::string();
            if (!text.empty()) {
              transcript = transcript.empty() ? text : transcript + " " + text;
              PostToPlatform("textRecognition", ResultJson(transcript, false));
            }
            break;
          }
          case SPEI_HYPOTHESIS: {
            auto *r = reinterpret_cast<ISpRecoResult *>(event.lParam);
            const std::string text = r ? ResultText(r) : std::string();
            if (!text.empty()) {
              const std::string shown = transcript.empty() ? text : transcript + " " + text;
              PostToPlatform("textRecognition", ResultJson(shown, false));
            }
            break;
          }
          case SPEI_SOUND_START:
            PostToPlatform("notifyStatus", "soundDetected");
            break;
          default:
            break;
        }
      }
      // Libère ce que l'évènement transporte (résultat de reconnaissance…).
      if (event.elParamType == SPET_LPARAM_IS_OBJECT && event.lParam) {
        reinterpret_cast<IUnknown *>(event.lParam)->Release();
      } else if ((event.elParamType == SPET_LPARAM_IS_POINTER ||
                  event.elParamType == SPET_LPARAM_IS_STRING) &&
                 event.lParam) {
        CoTaskMemFree(reinterpret_cast<void *>(event.lParam));
      }
    }

  }

  if (grammar) {
    grammar->SetDictationState(SPRS_INACTIVE);
    grammar->Release();
  }
  if (context) context->Release();
  if (recognizer) recognizer->Release();
  if (audio) audio->Release();
  if (SUCCEEDED(co)) CoUninitialize();
}

}  // namespace speech_to_text_windows
