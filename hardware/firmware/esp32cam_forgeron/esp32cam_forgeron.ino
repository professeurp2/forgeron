// ---------------------------------------------------------------------------
// Forgeron — caméra de surveillance d'usinage
// Carte : AI-Thinker ESP32-CAM (OV2640, 4 Mo PSRAM)
//
// Rôle : rejoindre le point d'accès WiFi porté par l'ESP32 FluidNC et exposer
// les images de la zone de coupe à l'application.
//
// La caméra est un client de plus sur l'AP de la machine : elle ne parle
// JAMAIS au contrôleur, ne reçoit aucun G-code, et son plantage éventuel n'a
// aucun effet sur l'usinage en cours. C'est volontaire — la surveillance ne
// doit pas pouvoir devenir une cause de panne.
//
// Endpoints (conformes au croquis CameraWebServer d'origine, que le client
// Dart `Esp32CamRepository` attend) :
//   port 80 : GET /            page d'état minimale
//             GET /capture     une image JPEG
//             GET /status      réglages courants (JSON)
//             GET /control?var=<nom>&val=<n>
//   port 81 : GET /stream      flux MJPEG (pour un navigateur ; l'application
//                              Flutter, elle, fait du polling sur /capture)
//
// ── Flash ──────────────────────────────────────────────────────────────────
// Montage utilisé : ESP32-CAM sur platine ESP32-CAM-MB (micro-USB + CH340).
// Pour téléverser : maintenir le bouton « I00 », appuyer « RST », relâcher
// « I00 ». Aucun cavalier à poser.
//
//   arduino-cli compile --fqbn esp32:esp32:esp32cam:PartitionScheme=huge_app .
//   arduino-cli upload -p COM5 --fqbn esp32:esp32:esp32cam:PartitionScheme=huge_app .
//
// Sur ESP32-CAM nue (sans platine), il faut à la place un adaptateur USB-TTL
// 3,3 V — TX sur U0R, RX sur U0T — et strapper IO0 sur GND.
// ---------------------------------------------------------------------------

#include <WiFi.h>
#include <esp_camera.h>
#include <esp_http_server.h>
#include <esp_timer.h>

// ── Réseau ──────────────────────────────────────────────────────────────────
// Doivent correspondre EXACTEMENT au point d'accès de l'ESP32 FluidNC
// (côté FluidNC : $AP/SSID et $AP/Password, stockés en NVS — pas dans
// config.yaml). Vérifiables par « $S » dans la console FluidNC.
static const char *AP_SSID = "FORGERON";
static const char *AP_PASSWORD = "00000001";

// IP statique. FluidNC se donne 192.168.0.1 et distribue en 192.168.0.x ; on
// se fixe en .50 pour ne pas dépendre d'un bail DHCP qui changerait au
// redémarrage — l'application a cette adresse en dur dans ses réglages
// (`kDefaultCameraIp`).
static IPAddress CAM_IP(192, 168, 0, 50);
static IPAddress CAM_GATEWAY(192, 168, 0, 1); // l'ESP32 FluidNC
static IPAddress CAM_SUBNET(255, 255, 255, 0);

// ── Brochage AI-Thinker ─────────────────────────────────────────────────────
// Ne pas modifier : c'est le câblage figé de la carte, pas un choix.
#define PWDN_GPIO_NUM 32
#define RESET_GPIO_NUM -1
#define XCLK_GPIO_NUM 0
#define SIOD_GPIO_NUM 26
#define SIOC_GPIO_NUM 27
#define Y9_GPIO_NUM 35
#define Y8_GPIO_NUM 34
#define Y7_GPIO_NUM 39
#define Y6_GPIO_NUM 36
#define Y5_GPIO_NUM 21
#define Y4_GPIO_NUM 19
#define Y3_GPIO_NUM 18
#define Y2_GPIO_NUM 5
#define VSYNC_GPIO_NUM 25
#define HREF_GPIO_NUM 23
#define PCLK_GPIO_NUM 22

// LED blanche de la carte. ATTENTION : GPIO4 est AUSSI une ligne de données de
// la microSD. Utiliser la LED interdit la carte SD, et réciproquement. Ici on
// n'utilise pas la SD (tout part vers le téléphone), la LED est donc libre.
#define LED_GPIO_NUM 4
#define LED_LEDC_CHANNEL 2

static httpd_handle_t camera_httpd = NULL;
static httpd_handle_t stream_httpd = NULL;

static int led_duty = 0;

// ---------------------------------------------------------------------------
// Identité
// ---------------------------------------------------------------------------

// Cette carte répond en HTTP sur le port 80, exactement comme l'ESP32 qui
// exécute le G-code. Le scanner réseau de Forgeron doit pouvoir écarter la
// caméra SANS AMBIGUÏTÉ : confondre les deux reviendrait à envoyer un
// programme d'usinage à un appareil qui n'a pas de moteurs — au mieux rien ne
// se passe, au pire l'opérateur croit sa machine connectée alors qu'elle ne
// l'est pas.
//
// L'en-tête part sur TOUTES les réponses, y compris les erreurs : c'est le
// seul marqueur sur lequel on peut compter quel que soit l'endpoint sondé.
#define FORGERON_DEVICE_HEADER "X-Forgeron-Device"
#define FORGERON_DEVICE_VALUE "camera"

static void set_common_headers(httpd_req_t *req) {
  httpd_resp_set_hdr(req, FORGERON_DEVICE_HEADER, FORGERON_DEVICE_VALUE);
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
}

// ---------------------------------------------------------------------------
// LED d'appoint
// ---------------------------------------------------------------------------

// L'API LEDC a changé entre les cores ESP32 Arduino 2.x et 3.x : la 3.x
// raisonne par broche et a supprimé ledcSetup/ledcAttachPin. Sans ces gardes,
// le croquis ne compile que sur l'une des deux — et le message d'erreur ne dit
// pas du tout que le problème vient de la version du core.
static void led_setup() {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcAttach(LED_GPIO_NUM, 5000, 8);
  ledcWrite(LED_GPIO_NUM, 0);
#else
  ledcSetup(LED_LEDC_CHANNEL, 5000, 8);
  ledcAttachPin(LED_GPIO_NUM, LED_LEDC_CHANNEL);
  ledcWrite(LED_LEDC_CHANNEL, 0);
#endif
}

static void led_set(int duty) {
  led_duty = constrain(duty, 0, 255);
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWrite(LED_GPIO_NUM, led_duty);
#else
  ledcWrite(LED_LEDC_CHANNEL, led_duty);
#endif
}

// ---------------------------------------------------------------------------
// Caméra
// ---------------------------------------------------------------------------

static bool camera_setup() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.grab_mode = CAMERA_GRAB_LATEST; // toujours l'image la plus récente
  config.fb_location = CAMERA_FB_IN_PSRAM;

  // La carte AI-Thinker embarque 4 Mo de PSRAM : deux tampons permettent de
  // préparer l'image suivante pendant l'envoi de la précédente. Sans PSRAM il
  // faut se rabattre sur un seul tampon en DRAM et une résolution modeste.
  if (psramFound()) {
    config.frame_size = FRAMESIZE_VGA; // 640x480
    config.jpeg_quality = 12;          // 10..63, plus bas = meilleure qualité
    config.fb_count = 2;
  } else {
    config.frame_size = FRAMESIZE_QVGA;
    config.jpeg_quality = 15;
    config.fb_count = 1;
    config.fb_location = CAMERA_FB_IN_DRAM;
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("[cam] echec init : 0x%x\n", err);
    return false;
  }

  sensor_t *s = esp_camera_sensor_get();
  // L'OV2640 sort une image inversée sur cette carte ; on la remet à l'endroit
  // ici plutôt que côté application, pour que n'importe quel navigateur voie
  // aussi la bonne orientation.
  s->set_vflip(s, 1);
  s->set_hmirror(s, 0);
  s->set_brightness(s, 1); // les copeaux et l'huile assombrissent la scène
  s->set_saturation(s, 0);
  return true;
}

// ---------------------------------------------------------------------------
// Handlers HTTP
// ---------------------------------------------------------------------------

static esp_err_t capture_handler(httpd_req_t *req) {
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    httpd_resp_send_500(req);
    return ESP_FAIL;
  }

  httpd_resp_set_type(req, "image/jpeg");
  httpd_resp_set_hdr(req, "Content-Disposition", "inline; filename=capture.jpg");
  // L'application ajoute déjà un paramètre anti-cache, mais un navigateur ou
  // un proxy intermédiaire pourrait resservir une vieille image : sur un poste
  // de surveillance c'est le pire des défauts possibles.
  httpd_resp_set_hdr(req, "Cache-Control", "no-store");
  set_common_headers(req);

  esp_err_t res = httpd_resp_send(req, (const char *)fb->buf, fb->len);
  esp_camera_fb_return(fb);
  return res;
}

static esp_err_t status_handler(httpd_req_t *req) {
  sensor_t *s = esp_camera_sensor_get();
  char json[256];
  snprintf(json, sizeof(json),
           "{\"framesize\":%u,\"quality\":%u,\"led_intensity\":%d,"
           "\"rssi\":%d,\"psram\":%s,\"uptime_s\":%lu}",
           s->status.framesize, s->status.quality, led_duty, WiFi.RSSI(),
           psramFound() ? "true" : "false", (unsigned long)(millis() / 1000));

  httpd_resp_set_type(req, "application/json");
  set_common_headers(req);
  return httpd_resp_send(req, json, strlen(json));
}

static esp_err_t control_handler(httpd_req_t *req) {
  char query[128];
  if (httpd_req_get_url_query_str(req, query, sizeof(query)) != ESP_OK) {
    httpd_resp_send_404(req);
    return ESP_FAIL;
  }

  char variable[32];
  char value[32];
  if (httpd_query_key_value(query, "var", variable, sizeof(variable)) != ESP_OK ||
      httpd_query_key_value(query, "val", value, sizeof(value)) != ESP_OK) {
    httpd_resp_send_404(req);
    return ESP_FAIL;
  }

  int val = atoi(value);
  sensor_t *s = esp_camera_sensor_get();
  int res = 0;

  if (!strcmp(variable, "framesize")) {
    res = s->set_framesize(s, (framesize_t)val);
  } else if (!strcmp(variable, "quality")) {
    res = s->set_quality(s, val);
  } else if (!strcmp(variable, "led_intensity")) {
    led_set(val);
  } else if (!strcmp(variable, "vflip")) {
    res = s->set_vflip(s, val);
  } else if (!strcmp(variable, "hmirror")) {
    res = s->set_hmirror(s, val);
  } else if (!strcmp(variable, "brightness")) {
    res = s->set_brightness(s, val);
  } else {
    res = -1;
  }

  if (res < 0) {
    httpd_resp_send_500(req);
    return ESP_FAIL;
  }

  set_common_headers(req);
  return httpd_resp_send(req, NULL, 0);
}

static esp_err_t index_handler(httpd_req_t *req) {
  char page[320];
  snprintf(page, sizeof(page),
           "<!doctype html><meta charset=utf-8><title>Forgeron CAM</title>"
           // Second marqueur, dans le corps : si un jour un proxy mange
           // l'en-tete, le scanner peut encore reconnaitre la camera.
           "<meta name=forgeron-device content=camera>"
           "<body style='font-family:sans-serif;background:#111;color:#eee'>"
           "<h3>Forgeron &mdash; camera d'usinage</h3>"
           "<p>IP %s &middot; RSSI %d dBm</p>"
           "<p><a style='color:#6cf' href='/capture'>/capture</a> &middot; "
           "<a style='color:#6cf' href='http://%s:81/stream'>/stream</a></p>",
           WiFi.localIP().toString().c_str(), WiFi.RSSI(),
           WiFi.localIP().toString().c_str());

  httpd_resp_set_type(req, "text/html");
  set_common_headers(req);
  return httpd_resp_send(req, page, strlen(page));
}

// ── Flux MJPEG (port 81) ────────────────────────────────────────────────────

#define PART_BOUNDARY "123456789000000000000987654321"
static const char *STREAM_CONTENT_TYPE =
    "multipart/x-mixed-replace;boundary=" PART_BOUNDARY;
static const char *STREAM_BOUNDARY = "\r\n--" PART_BOUNDARY "\r\n";
static const char *STREAM_PART =
    "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

static esp_err_t stream_handler(httpd_req_t *req) {
  esp_err_t res = httpd_resp_set_type(req, STREAM_CONTENT_TYPE);
  if (res != ESP_OK) return res;
  set_common_headers(req);

  char part_buf[64];
  while (true) {
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) {
      res = ESP_FAIL;
      break;
    }

    size_t hlen = snprintf(part_buf, sizeof(part_buf), STREAM_PART, fb->len);
    res = httpd_resp_send_chunk(req, part_buf, hlen);
    if (res == ESP_OK)
      res = httpd_resp_send_chunk(req, (const char *)fb->buf, fb->len);
    if (res == ESP_OK)
      res = httpd_resp_send_chunk(req, STREAM_BOUNDARY, strlen(STREAM_BOUNDARY));

    esp_camera_fb_return(fb);

    // Client parti (onglet fermé) : on sort, sinon la tâche tourne dans le
    // vide en continuant à saturer l'AP de la machine.
    if (res != ESP_OK) break;
  }
  return res;
}

// ---------------------------------------------------------------------------
// Serveurs
// ---------------------------------------------------------------------------

static void start_servers() {
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 80;
  config.ctrl_port = 32768;
  config.max_uri_handlers = 8;

  httpd_uri_t index_uri = {"/", HTTP_GET, index_handler, NULL};
  httpd_uri_t capture_uri = {"/capture", HTTP_GET, capture_handler, NULL};
  httpd_uri_t status_uri = {"/status", HTTP_GET, status_handler, NULL};
  httpd_uri_t control_uri = {"/control", HTTP_GET, control_handler, NULL};

  if (httpd_start(&camera_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(camera_httpd, &index_uri);
    httpd_register_uri_handler(camera_httpd, &capture_uri);
    httpd_register_uri_handler(camera_httpd, &status_uri);
    httpd_register_uri_handler(camera_httpd, &control_uri);
    Serial.println("[http] serveur principal sur :80");
  }

  // Le flux vit sur un serveur ET un port séparés : une requête /capture reste
  // ainsi servie instantanément même si un navigateur monopolise le flux.
  config.server_port = 81;
  config.ctrl_port = 32769;
  httpd_uri_t stream_uri = {"/stream", HTTP_GET, stream_handler, NULL};

  if (httpd_start(&stream_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(stream_httpd, &stream_uri);
    Serial.println("[http] serveur de flux sur :81");
  }
}

// ---------------------------------------------------------------------------
// WiFi
// ---------------------------------------------------------------------------

static bool wifi_connect(uint32_t timeout_ms) {
  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);

  if (!WiFi.config(CAM_IP, CAM_GATEWAY, CAM_SUBNET)) {
    Serial.println("[wifi] configuration IP statique refusee");
  }

  // L'AP est porté par un ESP32 posé dans un bâti métallique plein de moteurs
  // pas-à-pas : on désactive l'économie d'énergie, qui provoque des latences
  // erratiques sur une liaison déjà bruitée.
  WiFi.setSleep(false);
  WiFi.begin(AP_SSID, AP_PASSWORD);

  uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < timeout_ms) {
    delay(250);
    Serial.print('.');
  }
  Serial.println();
  return WiFi.status() == WL_CONNECTED;
}

// ---------------------------------------------------------------------------

void setup() {
  // Si vous devez décommenter la ligne ci-dessous pour que la carte démarre,
  // c'est que l'alimentation 5 V est insuffisante : ne masquez pas le
  // symptôme, câblez la caméra sur son propre rail (entrée +5V_EXT / J16 de la
  // carte Rev 2.0) avec 470 a 1000 uF au plus près de la broche 5V.
  //   #include "soc/rtc_cntl_reg.h"
  //   WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);

  Serial.begin(115200);
  Serial.setDebugOutput(false);
  Serial.println("\n[boot] Forgeron CAM");

  led_setup();

  if (!camera_setup()) {
    Serial.println("[boot] camera absente ou nappe mal enfichee — redemarrage");
    delay(3000);
    ESP.restart();
  }

  // 30 s et non 20 : mesuré sur la machine, l'association à l'AP de FluidNC
  // demande déjà ~15 s. Un budget serré ferait redémarrer la carte en boucle
  // au moindre démarrage plus lent, alors qu'elle était sur le point d'y
  // arriver.
  if (!wifi_connect(30000)) {
    Serial.println("[boot] AP FORGERON introuvable — redemarrage");
    delay(3000);
    ESP.restart();
  }

  Serial.printf("[wifi] connecte, IP %s (RSSI %d dBm)\n",
                WiFi.localIP().toString().c_str(), WiFi.RSSI());

  start_servers();
}

void loop() {
  // La caméra doit se raccrocher seule : la machine et sa caméra sont souvent
  // mises sous tension ensemble, et l'AP de FluidNC met plusieurs secondes de
  // plus à être prêt. Sans cette reprise, la caméra resterait muette jusqu'au
  // prochain passage de l'opérateur.
  static uint8_t failures = 0;

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[wifi] lien perdu, nouvelle tentative");
    if (wifi_connect(15000)) {
      failures = 0;
      Serial.printf("[wifi] reconnecte, IP %s\n",
                    WiFi.localIP().toString().c_str());
    } else if (++failures >= 5) {
      // Cinq échecs de suite : la pile WiFi est probablement dans un état
      // dont on ne sortira pas proprement. Redémarrer est plus sûr que de
      // boucler indéfiniment.
      Serial.println("[wifi] 5 echecs — redemarrage");
      ESP.restart();
    }
  }

  delay(2000);
}
