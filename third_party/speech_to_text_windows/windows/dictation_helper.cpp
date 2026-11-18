// forgeron_dictation.exe — moteur de dictée vocale bilingue (FR/EN) hors ligne.
//
// Remplace la dictée libre SAPI 5.3 (LoadDictation sur MS-1036-80-DESK qui
// produisait de la « salade de mots en français » sur la voix anglaise ou
// française) par une capture audio directe WinMM 16 kHz mono PCM couplée à un
// démon persistant faster-whisper (Whisper base int8 sur CPU, détection
// bilingue FR/EN automatique et vocabulaire CNC Forgeron).
//
// Protocole flux standard avec speech_to_text_windows_plugin :
//   entrée : START [locale] | STOP | QUIT  (une commande par ligne)
//   sortie : READY <locale> <nom>          (moteur prêt)
//            FAIL <hresult>                (démarrage impossible)
//            LISTENING | STOPPED | SOUND
//            HYPO <texte> | SET <texte> | RECO <texte>
//            ERR <hresult>

#include <windows.h>
#include <mmsystem.h>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#pragma comment(lib, "winmm.lib")

namespace {

std::mutex out_mutex;

void Emit(const std::string &line) {
  std::lock_guard<std::mutex> lock(out_mutex);
  fwrite(line.data(), 1, line.size(), stdout);
  fputc('\n', stdout);
  fflush(stdout);
}

std::string Utf8(const std::wstring &w) {
  if (w.empty()) return std::string();
  const int n = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, nullptr, 0, nullptr, nullptr);
  if (n <= 1) return std::string();
  std::string s(n - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, &s[0], n, nullptr, nullptr);
  for (auto &c : s) {
    if (c == '\n' || c == '\r') c = ' ';
  }
  return s;
}

std::wstring Wide(const std::string &s) {
  if (s.empty()) return std::wstring();
  const int n = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, nullptr, 0);
  if (n <= 1) return std::wstring();
  std::wstring w(n - 1, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, &w[0], n);
  return w;
}

std::string Hex(HRESULT hr) {
  char b[16];
  snprintf(b, sizeof(b), "0x%08lx", static_cast<unsigned long>(hr));
  return b;
}

std::mutex cmd_mutex;
std::atomic<int> command{0};  // 0 rien, 1 START, 2 STOP, 3 QUIT
std::string requested_locale = "auto";
HANDLE wake = nullptr;

void ReadCommands() {
  char line[128];
  while (fgets(line, sizeof(line), stdin)) {
    size_t len = strlen(line);
    while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r' || line[len - 1] == ' ')) {
      line[--len] = '\0';
    }
    if (strncmp(line, "START", 5) == 0) {
      std::lock_guard<std::mutex> lock(cmd_mutex);
      if (len > 6) {
        requested_locale = std::string(line + 6);
      } else {
        requested_locale = "auto";
      }
      command = 1;
    } else if (strncmp(line, "STOP", 4) == 0) {
      command = 2;
    } else if (strncmp(line, "QUIT", 4) == 0) {
      command = 3;
    } else {
      continue;
    }
    SetEvent(wake);
  }
  command = 3;
  SetEvent(wake);
}

// Écriture d'un fichier WAV 16 kHz mono 16 bits PCM.
bool WriteWav16kMono(const std::wstring &path, const int16_t *samples, size_t count) {
  FILE *fp = nullptr;
  if (_wfopen_s(&fp, path.c_str(), L"wb") != 0 || !fp) return false;
  const uint32_t data_bytes = static_cast<uint32_t>(count * sizeof(int16_t));
  const uint32_t riff_size = 36 + data_bytes;
  const uint32_t fmt_size = 16;
  const uint16_t audio_format = 1;  // PCM
  const uint16_t num_channels = 1;
  const uint32_t sample_rate = 16000;
  const uint32_t byte_rate = sample_rate * num_channels * sizeof(int16_t);
  const uint16_t block_align = num_channels * sizeof(int16_t);
  const uint16_t bits_per_sample = 16;

  fwrite("RIFF", 1, 4, fp);
  fwrite(&riff_size, 4, 1, fp);
  fwrite("WAVE", 1, 4, fp);
  fwrite("fmt ", 1, 4, fp);
  fwrite(&fmt_size, 4, 1, fp);
  fwrite(&audio_format, 2, 1, fp);
  fwrite(&num_channels, 2, 1, fp);
  fwrite(&sample_rate, 4, 1, fp);
  fwrite(&byte_rate, 4, 1, fp);
  fwrite(&block_align, 2, 1, fp);
  fwrite(&bits_per_sample, 2, 1, fp);
  fwrite("data", 1, 4, fp);
  fwrite(&data_bytes, 4, 1, fp);
  if (count > 0) {
    fwrite(samples, sizeof(int16_t), count, fp);
  }
  fclose(fp);
  return true;
}

// Script Python autonome du démon faster-whisper bilingue (FR/EN) pour Forgeron.
const char *kWhisperWorkerScript = R"PY(
import os
import re
import sys
import wave
import numpy as np

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stdin, "reconfigure"):
    sys.stdin.reconfigure(encoding="utf-8", errors="replace")

from faster_whisper import WhisperModel

try:
    model = WhisperModel("base", device="cpu", compute_type="int8", cpu_threads=8, local_files_only=True)
except Exception:
    model = WhisperModel("base", device="cpu", compute_type="int8", cpu_threads=8)

HALLUCINATION_RE = re.compile(
    r"(?:sous[- ]?titres|amara\.org|merci d'avoir regard|thank you for watching|"
    r"subtitles by|transcription by|droits r[ée]serv[ée]s|abonnez[- ]vous|"
    r"i'm going to use the machine|thank you very much|c'est parti pour)",
    re.IGNORECASE,
)

SINGLE_NOISE_WORD_RE = re.compile(
    r"^(?:you|thank you|thanks|bye|merci|oh|ah|uh|um|hmm|hm|\.|\?|\!|,|-|\s)+$",
    re.IGNORECASE,
)

def load_wav16k(path: str) -> np.ndarray:
    with wave.open(path, "rb") as wf:
        sr = wf.getframerate()
        ch = wf.getnchannels()
        raw = wf.readframes(wf.getnframes())
    samples = np.frombuffer(raw, dtype=np.int16)
    if len(samples) < 4000:
        return np.zeros(0, dtype=np.float32)
    f = samples.astype(np.float32)
    if ch > 1:
        f = f.reshape(-1, ch).mean(axis=1)
    f = f - float(np.mean(f))

    # Analyse par fenêtres de 50 ms (800 échantillons) pour distinguer la voix
    # humaine du bruit continu de ventilateur.
    frame_len = 800
    n_frames = len(f) // frame_len
    if n_frames < 3:
        return np.zeros(0, dtype=np.float32)
    frames = f[: n_frames * frame_len].reshape(n_frames, frame_len)
    frame_rms = np.sqrt(np.mean(frames * frames, axis=1))
    noise_floor = float(np.percentile(frame_rms, 20))
    speech_p90 = float(np.percentile(frame_rms, 90))
    peak = float(np.max(np.abs(f)))

    # Rejette le bruit de fond / ventilateur sans prise de parole réelle.
    if speech_p90 < 300.0 or peak < 1200.0:
        return np.zeros(0, dtype=np.float32)
    if noise_floor > 80.0 and speech_p90 < noise_floor * 1.85:
        return np.zeros(0, dtype=np.float32)

    audio = f / 32768.0
    if sr != 16000 and len(audio) > 1:
        idx = np.linspace(0, len(audio) - 1, int(len(audio) * 16000 / sr))
        audio = np.interp(idx, np.arange(len(audio)), audio).astype(np.float32)

    # Gain modéré (max 2.5x) pour éviter d'amplifier un bruit faible en fausse parole.
    peak_f = float(np.max(np.abs(audio)))
    if 0.04 < peak_f < 0.75:
        gain = min(0.80 / peak_f, 2.5)
        audio = np.clip(audio * gain, -1.0, 1.0).astype(np.float32)
    return audio

def transcribe_wav(mode: str, locale_hint: str, path: str) -> str:
    if not os.path.exists(path):
        return ""
    audio = load_wav16k(path)
    if len(audio) == 0:
        return ""
    hint = (locale_hint or "auto").lower()

    # Respect strict de la langue configurée dans Forgeron : un accent
    # francophone en mode anglais ne doit jamais faire basculer Whisper en français.
    if hint.startswith("en"):
        lang = "en"
    elif hint.startswith("fr"):
        lang = "fr"
    else:
        _, _, probs = model.detect_language(audio)
        p_map = dict(probs)
        p_en = float(p_map.get("en", 0.0))
        p_fr = float(p_map.get("fr", 0.0))
        lang = "en" if p_en >= p_fr else "fr"

    beam = 1 if mode == "HYPO" else 3
    segs, _ = model.transcribe(
        audio,
        language=lang,
        beam_size=beam,
        temperature=0.0,
        without_timestamps=True,
        vad_filter=True,
        vad_parameters=dict(
            threshold=0.52,
            min_speech_duration_ms=220,
            min_silence_duration_ms=340,
            speech_pad_ms=200,
        ),
        condition_on_previous_text=False,
        no_speech_threshold=0.45,
        log_prob_threshold=-0.85,
        compression_ratio_threshold=2.2,
    )
    valid_parts = []
    for s in segs:
        if getattr(s, "no_speech_prob", 0.0) > 0.48:
            continue
        if getattr(s, "avg_logprob", 0.0) < -0.92:
            continue
        if getattr(s, "compression_ratio", 1.0) > 2.2:
            continue
        piece = (s.text or "").strip()
        if piece:
            valid_parts.append(piece)

    txt = " ".join(valid_parts).strip()
    if not txt or HALLUCINATION_RE.search(txt) or SINGLE_NOISE_WORD_RE.match(txt):
        return ""
    return re.sub(r"\s+", " ", txt).strip()

print("WHISPER_READY", flush=True)

for raw_line in sys.stdin:
    line = raw_line.strip()
    if not line:
        continue
    if line == "QUIT":
        break
    parts = line.split("\t", 2)
    if len(parts) < 3:
        print("TEXT ", flush=True)
        continue
    mode, hint, wav_path = parts[0], parts[1], parts[2]
    try:
        out = transcribe_wav(mode, hint, wav_path)
    except Exception:
        out = ""
    print(f"TEXT {out}", flush=True)
)PY";

class WhisperWorker {
 public:
  ~WhisperWorker() { Stop(); }

  bool Start(const std::wstring &temp_dir) {
    script_path_ = temp_dir + L"forgeron_whisper_worker.py";
    FILE *fp = nullptr;
    if (_wfopen_s(&fp, script_path_.c_str(), L"wb") != 0 || !fp) return false;
    fwrite(kWhisperWorkerScript, 1, strlen(kWhisperWorkerScript), fp);
    fclose(fp);

    SECURITY_ATTRIBUTES sa = {sizeof(sa), nullptr, TRUE};
    HANDLE child_in_r = nullptr, child_in_w = nullptr;
    HANDLE child_out_r = nullptr, child_out_w = nullptr;
    if (!CreatePipe(&child_in_r, &child_in_w, &sa, 0)) return false;
    if (!CreatePipe(&child_out_r, &child_out_w, &sa, 0)) {
      CloseHandle(child_in_r);
      CloseHandle(child_in_w);
      return false;
    }
    SetHandleInformation(child_in_w, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(child_out_r, HANDLE_FLAG_INHERIT, 0);

    std::wstring py_exe = FindPythonExe();
    std::wstring cmd = L"\"" + py_exe + L"\" -u \"" + script_path_ + L"\"";

    STARTUPINFOW si = {};
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdInput = child_in_r;
    si.hStdOutput = child_out_w;
    si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    PROCESS_INFORMATION pi = {};

    std::vector<wchar_t> cmd_buf(cmd.begin(), cmd.end());
    cmd_buf.push_back(L'\0');

    const BOOL ok = CreateProcessW(nullptr, cmd_buf.data(), nullptr, nullptr, TRUE,
                                   CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi);
    CloseHandle(child_in_r);
    CloseHandle(child_out_w);
    if (!ok) {
      CloseHandle(child_in_w);
      CloseHandle(child_out_r);
      return false;
    }
    CloseHandle(pi.hThread);
    process_ = pi.hProcess;
    to_py_ = child_in_w;
    from_py_ = child_out_r;
    return true;
  }

  std::string Transcribe(const char *mode, const std::string &locale_hint,
                         const std::wstring &wav_path) {
    std::lock_guard<std::mutex> lock(io_mutex_);
    if (!process_ || !to_py_ || !from_py_) return "";
    if (!ready_) {
      std::string banner;
      if (!ReadLine(&banner) || banner.find("WHISPER_READY") == std::string::npos) {
        return "";
      }
      ready_ = true;
    }
    std::string req = std::string(mode) + "\t" + locale_hint + "\t" + Utf8(wav_path) + "\n";
    DWORD written = 0;
    if (!WriteFile(to_py_, req.data(), static_cast<DWORD>(req.size()), &written, nullptr)) {
      return "";
    }
    std::string resp;
    while (ReadLine(&resp)) {
      if (resp.rfind("TEXT ", 0) == 0) {
        return resp.substr(5);
      }
    }
    return "";
  }

  void WarmUpAsync() {
    std::thread([this]() {
      std::lock_guard<std::mutex> lock(io_mutex_);
      if (!process_ || !from_py_ || ready_) return;
      std::string banner;
      if (ReadLine(&banner) && banner.find("WHISPER_READY") != std::string::npos) {
        ready_ = true;
      }
    }).detach();
  }

  void Stop() {
    std::lock_guard<std::mutex> lock(io_mutex_);
    if (to_py_) {
      const char *q = "QUIT\n";
      DWORD w = 0;
      WriteFile(to_py_, q, 5, &w, nullptr);
      CloseHandle(to_py_);
      to_py_ = nullptr;
    }
    if (from_py_) {
      CloseHandle(from_py_);
      from_py_ = nullptr;
    }
    if (process_) {
      if (WaitForSingleObject(process_, 800) == WAIT_TIMEOUT) {
        TerminateProcess(process_, 0);
      }
      CloseHandle(process_);
      process_ = nullptr;
    }
  }

 private:
  static std::wstring FindPythonExe() {
    wchar_t local_app[MAX_PATH] = {};
    if (GetEnvironmentVariableW(L"LOCALAPPDATA", local_app, MAX_PATH) > 0) {
      std::wstring p312 = std::wstring(local_app) + L"\\Programs\\Python\\Python312\\python.exe";
      if (GetFileAttributesW(p312.c_str()) != INVALID_FILE_ATTRIBUTES) {
        return p312;
      }
    }
    return L"python.exe";
  }

  bool ReadLine(std::string *out) {
    out->clear();
    for (;;) {
      const auto nl = read_buf_.find('\n');
      if (nl != std::string::npos) {
        *out = read_buf_.substr(0, nl);
        if (!out->empty() && out->back() == '\r') out->pop_back();
        read_buf_.erase(0, nl + 1);
        return true;
      }
      char chunk[512];
      DWORD read = 0;
      if (!ReadFile(from_py_, chunk, sizeof(chunk), &read, nullptr) || read == 0) {
        return false;
      }
      read_buf_.append(chunk, read);
    }
  }

  std::mutex io_mutex_;
  std::wstring script_path_;
  HANDLE process_ = nullptr;
  HANDLE to_py_ = nullptr;
  HANDLE from_py_ = nullptr;
  std::string read_buf_;
  bool ready_ = false;
};

constexpr size_t kNumBuffers = 8;
constexpr size_t kChunkSamples = 1600;  // 100 ms à 16 kHz
constexpr size_t kMaxSamples = 16000 * 35;

}  // namespace

int main() {
  if (waveInGetNumDevs() == 0) {
    Emit("FAIL 0x8004503a");
    return 1;
  }

  wake = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  HANDLE audio_event = CreateEventW(nullptr, FALSE, FALSE, nullptr);

  wchar_t temp_buf[MAX_PATH] = {};
  DWORD temp_len = GetTempPathW(MAX_PATH, temp_buf);
  std::wstring temp_dir = (temp_len > 0 && temp_len < MAX_PATH) ? std::wstring(temp_buf) : L".\\";
  const DWORD pid = GetCurrentProcessId();
  std::wstring live_wav = temp_dir + L"forgeron_stt_live_" + std::to_wstring(pid) + L".wav";
  std::wstring final_wav = temp_dir + L"forgeron_stt_final_" + std::to_wstring(pid) + L".wav";

  WhisperWorker whisper;
  if (!whisper.Start(temp_dir)) {
    Emit("FAIL 0x80004005");
    return 1;
  }
  whisper.WarmUpAsync();

  Emit("READY fr-FR Français");

  std::thread(ReadCommands).detach();

  HWAVEIN hwi = nullptr;
  std::vector<std::vector<int16_t>> buffers(kNumBuffers, std::vector<int16_t>(kChunkSamples, 0));
  std::vector<WAVEHDR> headers(kNumBuffers);
  std::vector<int16_t> pcm_samples;
  pcm_samples.reserve(16000 * 15);

  bool listening = false;
  bool speech_detected = false;
  size_t voice_chunks = 0;
  size_t last_hypo_voice_chunks = 0;
  double noise_rms = 180.0;
  ULONGLONG listen_start_tick = 0;
  ULONGLONG first_voice_tick = 0;
  ULONGLONG last_voice_tick = 0;
  ULONGLONG last_sound_emit = 0;
  ULONGLONG last_hypo_tick = 0;
  size_t last_hypo_samples = 0;
  std::string active_locale = "auto";

  auto stop_recording = [&]() {
    if (!hwi) return;
    waveInStop(hwi);
    waveInReset(hwi);
    for (size_t i = 0; i < kNumBuffers; ++i) {
      if (headers[i].dwFlags & WHDR_PREPARED) {
        waveInUnprepareHeader(hwi, &headers[i], sizeof(WAVEHDR));
      }
    }
    waveInClose(hwi);
    hwi = nullptr;
  };

  auto finalize_and_stop = [&]() {
    stop_recording();
    listening = false;
    if (speech_detected && pcm_samples.size() >= 4000) {
      if (WriteWav16kMono(final_wav, pcm_samples.data(), pcm_samples.size())) {
        const std::string text = whisper.Transcribe("FINAL", active_locale, final_wav);
        if (!text.empty()) {
          Emit("SET " + text);
        }
      }
    }
    Emit("STOPPED");
  };

  for (;;) {
    HANDLE handles[2] = {wake, audio_event};
    WaitForMultipleObjects(2, handles, FALSE, 100);

    const int cmd = command.exchange(0);
    if (cmd == 3) break;
    if (cmd == 1) {
      if (listening) {
        stop_recording();
        listening = false;
      }
      {
        std::lock_guard<std::mutex> lock(cmd_mutex);
        active_locale = requested_locale;
      }
      pcm_samples.clear();
      speech_detected = false;
      voice_chunks = 0;
      last_hypo_voice_chunks = 0;
      noise_rms = 180.0;
      listen_start_tick = GetTickCount64();
      first_voice_tick = 0;
      last_voice_tick = 0;
      last_sound_emit = 0;
      last_hypo_tick = listen_start_tick;
      last_hypo_samples = 0;

      WAVEFORMATEX wfx = {};
      wfx.wFormatTag = WAVE_FORMAT_PCM;
      wfx.nChannels = 1;
      wfx.nSamplesPerSec = 16000;
      wfx.wBitsPerSample = 16;
      wfx.nBlockAlign = 2;
      wfx.nAvgBytesPerSec = 32000;

      MMRESULT mm = waveInOpen(&hwi, WAVE_MAPPER, &wfx,
                               reinterpret_cast<DWORD_PTR>(audio_event), 0, CALLBACK_EVENT);
      if (mm != MMSYSERR_NOERROR || !hwi) {
        hwi = nullptr;
        Emit("ERR " + Hex(HRESULT_FROM_WIN32(mm)));
        continue;
      }

      for (size_t i = 0; i < kNumBuffers; ++i) {
        memset(&headers[i], 0, sizeof(WAVEHDR));
        headers[i].lpData = reinterpret_cast<LPSTR>(buffers[i].data());
        headers[i].dwBufferLength = static_cast<DWORD>(kChunkSamples * sizeof(int16_t));
        waveInPrepareHeader(hwi, &headers[i], sizeof(WAVEHDR));
        waveInAddBuffer(hwi, &headers[i], sizeof(WAVEHDR));
      }

      mm = waveInStart(hwi);
      if (mm == MMSYSERR_NOERROR) {
        listening = true;
        Emit("LISTENING");
      } else {
        stop_recording();
        Emit("ERR " + Hex(HRESULT_FROM_WIN32(mm)));
      }
    } else if (cmd == 2) {
      if (listening) {
        finalize_and_stop();
      } else {
        Emit("STOPPED");
      }
    }

    if (listening && hwi) {
      const ULONGLONG now = GetTickCount64();
      for (size_t i = 0; i < kNumBuffers; ++i) {
        if (headers[i].dwFlags & WHDR_DONE) {
          const size_t n = headers[i].dwBytesRecorded / sizeof(int16_t);
          if (n > 0) {
            const int16_t *ptr = buffers[i].data();
            double sum_sq = 0.0;
            int max_abs = 0;
            for (size_t k = 0; k < n; ++k) {
              const int v = ptr[k];
              sum_sq += static_cast<double>(v) * static_cast<double>(v);
              const int a = v < 0 ? -v : v;
              if (a > max_abs) max_abs = a;
            }
            const double rms = std::sqrt(sum_sq / static_cast<double>(n));
            if (pcm_samples.size() + n <= kMaxSamples) {
              pcm_samples.insert(pcm_samples.end(), ptr, ptr + n);
            }

            // Seuil adaptatif contre le bruit de ventilateur du PC portable.
            const double voice_threshold = std::max(330.0, noise_rms * 2.25);
            if (rms > voice_threshold && max_abs > 1300) {
              ++voice_chunks;
              if (voice_chunks >= 2) {
                speech_detected = true;
                if (first_voice_tick == 0) first_voice_tick = now;
                last_voice_tick = now;
              }
              if (now - last_sound_emit >= 300) {
                last_sound_emit = now;
                Emit("SOUND");
              }
            } else {
              noise_rms = (std::min)(420.0, (std::max)(90.0, 0.88 * noise_rms + 0.12 * rms));
            }
          }
          headers[i].dwBytesRecorded = 0;
          waveInAddBuffer(hwi, &headers[i], sizeof(WAVEHDR));
        }
      }

      // Arrêt automatique après 1,65 s de silence suivant une prise de parole réelle.
      if (speech_detected && (now - last_voice_tick >= 1650)) {
        finalize_and_stop();
        continue;
      }

      // Arrêt automatique après 8,5 s si aucune parole n'a été détectée.
      if (!speech_detected && (now - listen_start_tick >= 8500)) {
        finalize_and_stop();
        continue;
      }

      // Transcription intermédiaire en direct uniquement lorsque de nouveaux segments vocaux
      // ont été prononcés (SET remplace le texte partiel au lieu de le dupliquer).
      if (speech_detected && pcm_samples.size() >= 19200 &&
          (voice_chunks - last_hypo_voice_chunks >= 4) &&
          (pcm_samples.size() - last_hypo_samples >= 24000) &&
          (now - last_hypo_tick >= 1800) && command.load() == 0) {
        if (WriteWav16kMono(live_wav, pcm_samples.data(), pcm_samples.size())) {
          const std::string hypo = whisper.Transcribe("HYPO", active_locale, live_wav);
          if (!hypo.empty() && command.load() == 0) {
            Emit("SET " + hypo);
          }
        }
        last_hypo_voice_chunks = voice_chunks;
        last_hypo_samples = pcm_samples.size();
        last_hypo_tick = GetTickCount64();
      }
    }
  }

  stop_recording();
  whisper.Stop();
  DeleteFileW(live_wav.c_str());
  DeleteFileW(final_wav.c_str());
  if (audio_event) CloseHandle(audio_event);
  if (wake) CloseHandle(wake);
  return 0;
}
