#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shlobj.h>

#include <cstdio>
#include <exception>
#include <fstream>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

static void LogStartup(const std::wstring& message) {
  PWSTR localAppData = nullptr;
  if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &localAppData))) {
    std::wstring dir = std::wstring(localAppData) + L"\\Forgeron";
    CreateDirectoryW(dir.c_str(), nullptr);
    dir += L"\\logs";
    CreateDirectoryW(dir.c_str(), nullptr);
    std::wstring logFilePath = dir + L"\\startup.log";
    FILE* f = nullptr;
    if (_wfopen_s(&f, logFilePath.c_str(), L"a, ccs=UTF-8") == 0 && f) {
      SYSTEMTIME st;
      GetLocalTime(&st);
      fwprintf(f, L"[%04d-%02d-%02d %02d:%02d:%02d] [Native] %s\n",
               st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond, message.c_str());
      fclose(f);
    }
    CoTaskMemFree(localAppData);
  }
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // 1. Toujours aligner le répertoire de travail sur l'exécutable pour garantir
  // que le chemin relatif L"data" et les dépendances locales sont trouvés.
  wchar_t exePath[MAX_PATH];
  if (GetModuleFileNameW(nullptr, exePath, MAX_PATH) > 0) {
    wchar_t* lastSlash = wcsrchr(exePath, L'\\');
    if (lastSlash) {
      *lastSlash = L'\0';
      SetCurrentDirectoryW(exePath);
    }
  }

  LogStartup(L"Démarrage de wWinMain Forgeron.");

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  HRESULT hr = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(hr)) {
    LogStartup(L"Avertissement : CoInitializeEx a retourné " + std::to_wstring(hr));
  }

  try {
    flutter::DartProject project(L"data");

    std::vector<std::string> command_line_arguments =
        GetCommandLineArguments();

    project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

    FlutterWindow window(project);
    Win32Window::Point origin(10, 10);
    Win32Window::Size size(1280, 720);
    if (!window.Create(L"forgeron", origin, size)) {
      LogStartup(L"Échec critique : window.Create a échoué. Vérifiez l'intégrité du dossier data/ et des DLLs.");
      ::MessageBoxW(
          nullptr,
          L"Impossible de démarrer l'application Forgeron.\n\n"
          L"La fenêtre principale Flutter n'a pas pu être initialisée.\n"
          L"Vérifiez que tous les fichiers du dossier d'installation sont présents et complets.\n\n"
          L"Consultez les journaux dans :\n%LOCALAPPDATA%\\Forgeron\\logs\\startup.log",
          L"Forgeron CNC - Erreur de démarrage",
          MB_ICONERROR | MB_OK);
      return EXIT_FAILURE;
    }
    window.SetQuitOnClose(true);

    LogStartup(L"Fenêtre principale Forgeron créée avec succès. Entrée dans la boucle de messages.");

    ::MSG msg;
    while (::GetMessage(&msg, nullptr, 0, 0)) {
      ::TranslateMessage(&msg);
      ::DispatchMessage(&msg);
    }

    LogStartup(L"Sortie normale de la boucle de messages.");
    ::CoUninitialize();
    return EXIT_SUCCESS;
  } catch (const std::exception& e) {
    std::string what = e.what();
    std::wstring wwhat(what.begin(), what.end());
    LogStartup(L"Exception C++ non gérée : " + wwhat);
    ::MessageBoxW(
        nullptr,
        (L"Une erreur inattendue a provoqué la fermeture de Forgeron :\n\n" + wwhat +
         L"\n\nConsultez %LOCALAPPDATA%\\Forgeron\\logs\\startup.log").c_str(),
        L"Forgeron CNC - Exception fatale",
        MB_ICONERROR | MB_OK);
    ::CoUninitialize();
    return EXIT_FAILURE;
  } catch (...) {
    LogStartup(L"Exception C++ inconnue interceptée.");
    ::MessageBoxW(
        nullptr,
        L"Une erreur critique inconnue est survenue au démarrage.\n\nConsultez %LOCALAPPDATA%\\Forgeron\\logs\\startup.log",
        L"Forgeron CNC - Erreur fatale",
        MB_ICONERROR | MB_OK);
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
}
