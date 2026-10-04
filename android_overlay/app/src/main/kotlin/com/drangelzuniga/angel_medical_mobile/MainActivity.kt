package com.drangelzuniga.angel_medical_mobile

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val signingExecutor = Executors.newSingleThreadExecutor()
    override fun onDestroy() {
        signingExecutor.shutdown()
        super.onDestroy()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "angel_medical/signature").setMethodCallHandler { call, result ->
            if (call.method != "sign" && call.method != "verify") { result.notImplemented(); return@setMethodCallHandler }
            signingExecutor.execute {
                try {
                    val data = call.argument<ByteArray>("data") ?: throw IllegalArgumentException()
                    val answer = if (call.method == "sign") LocalSigner.sign(data,
                        call.argument<ByteArray>("certificate") ?: throw IllegalArgumentException(),
                        call.argument<ByteArray>("key") ?: throw IllegalArgumentException(),
                        (call.argument<String>("password") ?: "").toCharArray())
                    else LocalSigner.verify(data, call.argument<ByteArray>("cms") ?: throw IllegalArgumentException())
                    runOnUiThread { result.success(answer) }
                } catch (e: LocalSigner.Failure) {
                    runOnUiThread { result.error(e.code, "La operación no se completó. Código de diagnóstico: ${e.code}", null) }
                } catch (_: Exception) {
                    // Do not expose provider exceptions, file data, passwords or private keys in logs.
                    runOnUiThread { result.error("SIGNATURE_FAILED", "No se pudo firmar o verificar. Revisa contraseña, correspondencia de archivos, vigencia y formato DER PKCS#8 cifrado.", null) }
                }
            }
        }
    }
}
