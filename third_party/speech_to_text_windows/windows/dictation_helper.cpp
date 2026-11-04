// forgeron_dictation.exe — la dictée SAPI dans son propre processus.
//
// Dans le processus de Forgeron, la dictée SAPI refusait de démarrer
// (SetDictationState → 0x88890008, AUDCLNT_E_UNSUPPORTED_FORMAT) alors que le
// même code, dans un processus à part, démarre et transcrit sur le même poste
// (sonde du 29 octobre 2026, avec l'application ouverte en parallèle). Le
// plugin lance donc ce petit programme et dialogue avec lui par ses flux :
//
//   entrée : START | STOP | QUIT          (une commande par ligne)
//   sortie : READY <locale> <nom>         (moteur prêt)
//            FAIL <hresult>               (démarrage impossible)
//            LISTENING | STOPPED | SOUND
//            HYPO <texte> | RECO <texte>  (texte en UTF-8, sans saut de ligne)
//            ERR <hresult>                (la dictée n'a pas pu s'activer)
//
// Il s'arrête de lui-même quand son entrée se ferme (Forgeron fermé ou planté).

#include <windows.h>
#include <sapi.h>

#include <atomic>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>

namespace {

std::mutex out_mutex;

void Emit(const std::string &line) {
  std::lock_guard<std::mutex> lock(out_mutex);
  fwrite(line.data(), 1, line.size(), stdout);
  fputc('\n', stdout);
  fflush(stdout);
}

std::string Utf8(const wchar_t *w) {
  if (!w) return std::string();
  const int n = WideCharToMultiByte(CP_UTF8, 0, w, -1, nullptr, 0, nullptr, nullptr);
  if (n <= 1) return std::string();
  std::string s(n - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w, -1, &s[0], n, nullptr, nullptr);
  for (auto &c : s) {
    if (c == '\n' || c == '\r') c = ' ';
  }
  return s;
}

std::string Hex(HRESULT hr) {
  char b[16];
  snprintf(b, sizeof(b), "0x%08lx", static_cast<unsigned long>(hr));
  return b;
}

std::atomic<int> command{0};  // 0 rien, 1 START, 2 STOP, 3 QUIT
HANDLE wake = nullptr;

void ReadCommands() {
  char line[64];
  while (fgets(line, sizeof(line), stdin)) {
    if (strncmp(line, "START", 5) == 0) command = 1;
    else if (strncmp(line, "STOP", 4) == 0) command = 2;
    else if (strncmp(line, "QUIT", 4) == 0) command = 3;
    else continue;
    SetEvent(wake);
  }
  command = 3;  // entrée fermée : Forgeron n'est plus là
  SetEvent(wake);
}

}  // namespace

int main() {
  wake = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  const HRESULT co = CoInitializeEx(nullptr, COINIT_MULTITHREADED);

  ISpRecognizer *recognizer = nullptr;
  ISpObjectToken *audio = nullptr;
  ISpRecoContext *context = nullptr;
  ISpRecoGrammar *grammar = nullptr;
  HANDLE notify = nullptr;

  HRESULT hr = CoCreateInstance(CLSID_SpInprocRecognizer, nullptr, CLSCTX_INPROC_SERVER,
                                IID_ISpRecognizer, reinterpret_cast<void **>(&recognizer));
  if (SUCCEEDED(hr)) {
    ISpObjectTokenCategory *category = nullptr;
    LPWSTR id = nullptr;
    hr = CoCreateInstance(CLSID_SpObjectTokenCategory, nullptr, CLSCTX_ALL,
                          IID_ISpObjectTokenCategory, reinterpret_cast<void **>(&category));
    if (SUCCEEDED(hr)) hr = category->SetId(SPCAT_AUDIOIN, FALSE);
    if (SUCCEEDED(hr)) hr = category->GetDefaultTokenId(&id);
    if (SUCCEEDED(hr))
      hr = CoCreateInstance(CLSID_SpObjectToken, nullptr, CLSCTX_ALL, IID_ISpObjectToken,
                            reinterpret_cast<void **>(&audio));
    if (SUCCEEDED(hr)) hr = audio->SetId(nullptr, id, FALSE);
    if (id) CoTaskMemFree(id);
    if (category) category->Release();
  }
  if (SUCCEEDED(hr)) hr = recognizer->SetInput(audio, TRUE);
  if (SUCCEEDED(hr)) hr = recognizer->CreateRecoContext(&context);
  if (SUCCEEDED(hr)) {
    const ULONGLONG interest = SPFEI(SPEI_RECOGNITION) | SPFEI(SPEI_HYPOTHESIS) |
                               SPFEI(SPEI_SOUND_START) | SPFEI(SPEI_SOUND_END);
    hr = context->SetInterest(interest, interest);
  }
  if (SUCCEEDED(hr)) hr = context->SetNotifyWin32Event();
  if (SUCCEEDED(hr)) {
    notify = context->GetNotifyEventHandle();
    if (!notify) hr = E_FAIL;
  }
  if (SUCCEEDED(hr)) hr = context->CreateGrammar(0, &grammar);
  if (SUCCEEDED(hr)) hr = grammar->LoadDictation(nullptr, SPLO_STATIC);

  if (FAILED(hr)) {
    Emit("FAIL " + Hex(hr));
    return 1;
  }

  // Langue réelle du reconnaisseur (attribut « Language », LCID hexadécimal).
  std::string locale = "fr-FR", name = "Français";
  ISpObjectToken *token = nullptr;
  if (SUCCEEDED(recognizer->GetRecognizer(&token)) && token) {
    ISpDataKey *attributes = nullptr;
    if (SUCCEEDED(token->OpenKey(L"Attributes", &attributes)) && attributes) {
      LPWSTR lang = nullptr;
      if (SUCCEEDED(attributes->GetStringValue(L"Language", &lang)) && lang) {
        wchar_t loc[LOCALE_NAME_MAX_LENGTH] = {}, disp[128] = {};
        if (LCIDToLocaleName(static_cast<LCID>(wcstoul(lang, nullptr, 16)), loc,
                             LOCALE_NAME_MAX_LENGTH, 0) > 0) {
          GetLocaleInfoEx(loc, LOCALE_SLOCALIZEDLANGUAGENAME, disp, 128);
          locale = Utf8(loc);
          name = Utf8(disp);
        }
        CoTaskMemFree(lang);
      }
      attributes->Release();
    }
    token->Release();
  }
  Emit("READY " + locale + " " + name);

  std::thread(ReadCommands).detach();

  bool listening = false;
  for (;;) {
    HANDLE handles[2] = {wake, notify};
    WaitForMultipleObjects(2, handles, FALSE, 500);

    const int cmd = command.exchange(0);
    if (cmd == 3) break;
    if (cmd == 1 && !listening) {
      hr = grammar->SetDictationState(SPRS_ACTIVE);
      if (SUCCEEDED(hr)) {
        listening = true;
        Emit("LISTENING");
      } else {
        Emit("ERR " + Hex(hr));
      }
    } else if (cmd == 2 && listening) {
      grammar->SetDictationState(SPRS_INACTIVE);
      listening = false;
      Emit("STOPPED");
    }

    SPEVENT event;
    ULONG fetched = 0;
    while (SUCCEEDED(context->GetEvents(1, &event, &fetched)) && fetched > 0) {
      if (listening) {
        if (event.eEventId == SPEI_RECOGNITION || event.eEventId == SPEI_HYPOTHESIS) {
          LPWSTR text = nullptr;
          auto *result = reinterpret_cast<ISpRecoResult *>(event.lParam);
          if (result &&
              SUCCEEDED(result->GetText(SP_GETWHOLEPHRASE, SP_GETWHOLEPHRASE, TRUE, &text,
                                        nullptr)) &&
              text) {
            Emit(std::string(event.eEventId == SPEI_RECOGNITION ? "RECO " : "HYPO ") +
                 Utf8(text));
            CoTaskMemFree(text);
          }
        } else if (event.eEventId == SPEI_SOUND_START) {
          Emit("SOUND");
        }
      }
      if (event.elParamType == SPET_LPARAM_IS_OBJECT && event.lParam) {
        reinterpret_cast<IUnknown *>(event.lParam)->Release();
      } else if ((event.elParamType == SPET_LPARAM_IS_POINTER ||
                  event.elParamType == SPET_LPARAM_IS_STRING) &&
                 event.lParam) {
        CoTaskMemFree(reinterpret_cast<void *>(event.lParam));
      }
    }
  }

  grammar->SetDictationState(SPRS_INACTIVE);
  grammar->Release();
  context->Release();
  recognizer->Release();
  audio->Release();
  if (SUCCEEDED(co)) CoUninitialize();
  return 0;
}
