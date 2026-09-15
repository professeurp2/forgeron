package com.forgeron.cnc

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Pont natif « réseau cellulaire dédié ».
 *
 * Le téléphone est joint à l'AP WiFi de l'ESP32 (pilotage CNC), un réseau sans
 * accès Internet. Pour que l'IA fonctionne quand même, on demande explicitement
 * à Android le réseau **cellulaire** (4G/5G) et on exécute la requête HTTP de
 * l'IA dessus — le WiFi restant utilisé par défaut pour l'ESP32.
 *
 * Exposé à Flutter via le MethodChannel [CHANNEL], méthode `httpRequest`.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "forgeron/cellular"
        private const val STREAM_CHANNEL = "forgeron/cellular_stream"
        private const val WIFI_CHANNEL = "forgeron/wifi"
    }

    // Callback de la connexion assistée à l'AP WiFi de l'ESP32.
    private var wifiCallback: ConnectivityManager.NetworkCallback? = null

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lock = Object()

    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    @Volatile
    private var cellularNetwork: Network? = null

    // Annulation du flux SSE en cours (onCancel côté Flutter).
    private var streamCancel: AtomicBoolean? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "httpRequest" -> handleHttpRequest(call.arguments, result)
                    "isCellularAvailable" ->
                        // Hors thread principal : awaitCellular() fait wait().
                        executor.execute {
                            val ok = awaitCellular(2_000L) != null
                            replySuccess(result, ok)
                        }
                    else -> result.notImplemented()
                }
            }

        // Flux SSE (streamGenerateContent) sur le réseau cellulaire.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    startSseStream(arguments, events)
                }

                override fun onCancel(arguments: Any?) {
                    streamCancel?.set(true)
                }
            })

        // Connexion assistée à l'AP WiFi de l'ESP32.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connect" -> connectWifi(
                        call.argument("ssid"), call.argument("password"), result)
                    "disconnect" -> {
                        disconnectWifi(); result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Rejoint l'AP WiFi [ssid] via [WifiNetworkSpecifier] (Android 10+). Android
     * affiche un dialogue d'approbation la première fois. À la connexion, on lie
     * le process à ce réseau (le WebSocket/HTTP CNC passe dessus ; l'IA reste sur
     * la 4G via son binding explicite). Le callback rejoint automatiquement l'AP
     * quand il revient (ex. après un reboot de l'ESP32).
     */
    private fun connectWifi(
        ssid: String?, password: String?, result: MethodChannel.Result
    ) {
        if (ssid.isNullOrEmpty()) {
            result.error("bad_args", "SSID manquant", null); return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error(
                "unsupported",
                "Android 10+ requis pour la connexion assistée.", null); return
        }
        val cm = connectivityManager ?: run {
            result.error("no_cm", "ConnectivityManager indisponible", null); return
        }
        disconnectWifi() // nettoie une demande précédente

        val specBuilder = WifiNetworkSpecifier.Builder().setSsid(ssid)
        if (!password.isNullOrEmpty()) specBuilder.setWpa2Passphrase(password)
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            // L'AP de l'ESP32 n'a pas d'accès Internet.
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specBuilder.build())
            .build()

        val replied = AtomicBoolean(false)
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                // Trafic par défaut de l'app → ce WiFi (l'IA reste sur la 4G).
                cm.bindProcessToNetwork(network)
                if (replied.compareAndSet(false, true)) {
                    mainHandler.post { result.success(true) }
                }
            }

            override fun onUnavailable() {
                if (replied.compareAndSet(false, true)) {
                    mainHandler.post {
                        result.error("unavailable",
                            "Connexion refusée ou AP introuvable.", null)
                    }
                }
            }
        }
        wifiCallback = cb
        try {
            cm.requestNetwork(request, cb)
        } catch (e: Exception) {
            wifiCallback = null
            result.error("request_failed", e.message ?: e.toString(), null)
        }
    }

    private fun disconnectWifi() {
        try {
            connectivityManager?.bindProcessToNetwork(null)
        } catch (_: Exception) {
        }
        wifiCallback?.let { cb ->
            try {
                connectivityManager?.unregisterNetworkCallback(cb)
            } catch (_: Exception) {
            }
        }
        wifiCallback = null
    }

    /** Ouvre la requête SSE sur la 4G et pousse chaque payload `data:` au sink. */
    private fun startSseStream(arguments: Any?, events: EventChannel.EventSink) {
        @Suppress("UNCHECKED_CAST")
        val args = arguments as? Map<String, Any?>
        if (args == null) {
            events.error("bad_args", "Arguments manquants", null); return
        }
        val method = (args["method"] as? String ?: "POST").uppercase()
        val urlStr = args["url"] as? String
        val headers = (args["headers"] as? Map<*, *>) ?: emptyMap<String, String>()
        val body = args["body"] as? String
        val timeoutMs = (args["timeoutMs"] as? Int) ?: 120_000
        if (urlStr == null) {
            events.error("bad_args", "URL manquante", null); return
        }
        val cancel = AtomicBoolean(false)
        streamCancel = cancel

        executor.execute {
            try {
                val network = awaitCellular(15_000L)
                if (network == null) {
                    mainHandler.post {
                        events.error("cellular_unavailable",
                            "Aucune donnée mobile disponible (4G/5G).", null)
                    }
                    return@execute
                }
                val conn = network.openConnection(URL(urlStr)) as HttpURLConnection
                conn.requestMethod = method
                conn.connectTimeout = 15_000
                conn.readTimeout = timeoutMs
                conn.doInput = true
                for ((k, v) in headers) conn.setRequestProperty(k.toString(), v.toString())
                if (body != null && method != "GET" && method != "HEAD") {
                    conn.doOutput = true
                    conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                }

                val code = conn.responseCode
                if (code !in 200..299) {
                    val err = conn.errorStream?.bufferedReader(Charsets.UTF_8)
                        ?.use { it.readText() } ?: "HTTP $code"
                    conn.disconnect()
                    mainHandler.post { events.error("http_error", "HTTP $code: $err", null) }
                    return@execute
                }

                conn.inputStream.bufferedReader(Charsets.UTF_8).useLines { seq ->
                    for (raw in seq) {
                        if (cancel.get()) break
                        val line = raw.trim()
                        if (line.startsWith("data:")) {
                            val payload = line.substring(5).trim()
                            if (payload.isNotEmpty() && payload != "[DONE]") {
                                mainHandler.post { events.success(payload) }
                            }
                        }
                    }
                }
                conn.disconnect()
                if (!cancel.get()) mainHandler.post { events.endOfStream() }
            } catch (e: Exception) {
                mainHandler.post {
                    events.error("http_error", e.message ?: e.toString(), null)
                }
            }
        }
    }

    /** Exécute la requête HTTP sur le réseau cellulaire (hors thread principal). */
    private fun handleHttpRequest(arguments: Any?, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = arguments as? Map<String, Any?> ?: run {
            result.error("bad_args", "Arguments manquants", null); return
        }
        val method = (args["method"] as? String ?: "POST").uppercase()
        val urlStr = args["url"] as? String
        val headers = (args["headers"] as? Map<*, *>) ?: emptyMap<String, String>()
        val body = args["body"] as? String
        val timeoutMs = (args["timeoutMs"] as? Int) ?: 60_000

        if (urlStr == null) {
            result.error("bad_args", "URL manquante", null); return
        }

        executor.execute {
            try {
                val network = awaitCellular(minOf(timeoutMs.toLong(), 15_000L))
                    ?: return@execute replyError(
                        result, "cellular_unavailable",
                        "Aucune donnée mobile disponible (4G/5G)."
                    )

                val conn = network.openConnection(URL(urlStr)) as HttpURLConnection
                conn.requestMethod = method
                conn.connectTimeout = 15_000
                conn.readTimeout = timeoutMs
                conn.doInput = true
                for ((k, v) in headers) {
                    conn.setRequestProperty(k.toString(), v.toString())
                }
                if (body != null && method != "GET" && method != "HEAD") {
                    conn.doOutput = true
                    val out: OutputStream = conn.outputStream
                    out.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                }

                val code = conn.responseCode
                val stream = if (code in 200..399) conn.inputStream else conn.errorStream
                val respBody = stream?.bufferedReader(Charsets.UTF_8)
                    ?.use { it.readText() } ?: ""
                conn.disconnect()

                replySuccess(result, mapOf("statusCode" to code, "body" to respBody))
            } catch (e: Exception) {
                replyError(result, "http_error", e.message ?: e.toString())
            }
        }
    }

    /**
     * Demande (une fois) le réseau cellulaire et attend qu'il soit disponible,
     * jusqu'à [timeoutMs]. Appelé depuis un thread de fond → `wait()` est sûr.
     */
    private fun awaitCellular(timeoutMs: Long): Network? {
        ensureCellularRequested()
        synchronized(lock) {
            if (cellularNetwork != null) return cellularNetwork
            try {
                lock.wait(timeoutMs)
            } catch (_: InterruptedException) {
            }
            return cellularNetwork
        }
    }

    /** Enregistre (paresseusement) une demande persistante de réseau cellulaire. */
    private fun ensureCellularRequested() {
        if (networkCallback != null) return
        val cm = connectivityManager ?: return
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                synchronized(lock) {
                    cellularNetwork = network
                    lock.notifyAll()
                }
            }

            override fun onLost(network: Network) {
                synchronized(lock) {
                    if (cellularNetwork == network) cellularNetwork = null
                }
            }
        }
        networkCallback = cb
        try {
            cm.requestNetwork(request, cb)
        } catch (_: SecurityException) {
            networkCallback = null
        }
    }

    private fun replySuccess(result: MethodChannel.Result, payload: Any?) {
        mainHandler.post { result.success(payload) }
    }

    private fun replyError(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post { result.error(code, message, null) }
    }

    override fun onDestroy() {
        networkCallback?.let { cb ->
            try {
                connectivityManager?.unregisterNetworkCallback(cb)
            } catch (_: Exception) {
            }
        }
        networkCallback = null
        disconnectWifi()
        executor.shutdown()
        super.onDestroy()
    }
}
