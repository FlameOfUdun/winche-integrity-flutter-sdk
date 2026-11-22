package dev.winche.winche_integrity

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityException
import com.google.android.play.core.integrity.StandardIntegrityManager
import com.google.android.play.core.integrity.StandardIntegrityManager.PrepareIntegrityTokenRequest
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenProvider
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenRequest
import com.google.android.play.core.integrity.model.StandardIntegrityErrorCode
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Google Play Integrity (standard API) for Winche Integrity: a token provider prepared once per Google Cloud project
 * number, then a token for each request hash (SHA-256 of a challenge from the project). A provider Google says is no
 * longer valid is prepared again, once.
 */
class WincheIntegrityPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val manager: StandardIntegrityManager by lazy { IntegrityManagerFactory.createStandard(context) }
    private val providers = mutableMapOf<Long, StandardIntegrityTokenProvider>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "winche_integrity")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        providers.clear()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "playIntegrityToken" -> {
                val project = (call.argument<Any>("cloudProjectNumber") as? Number)?.toLong()
                val hash = call.argument<String>("requestHash")
                if (project == null || hash == null) {
                    result.error("arguments", "cloudProjectNumber and requestHash are needed.", null)
                } else {
                    token(project, hash, result, retried = false)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun token(project: Long, hash: String, result: Result, retried: Boolean) {
        withProvider(project, result) { provider ->
            provider.request(StandardIntegrityTokenRequest.builder().setRequestHash(hash).build())
                .addOnSuccessListener { response -> result.success(response.token()) }
                .addOnFailureListener { e ->
                    if (!retried && e is StandardIntegrityException && e.errorCode == StandardIntegrityErrorCode.INTEGRITY_TOKEN_PROVIDER_INVALID) {
                        providers.remove(project)
                        token(project, hash, result, retried = true)
                    } else {
                        fail(result, e)
                    }
                }
        }
    }

    private fun withProvider(project: Long, result: Result, then: (StandardIntegrityTokenProvider) -> Unit) {
        providers[project]?.let { return then(it) }
        manager.prepareIntegrityToken(PrepareIntegrityTokenRequest.builder().setCloudProjectNumber(project).build())
            .addOnSuccessListener { provider ->
                providers[project] = provider
                then(provider)
            }
            .addOnFailureListener { e -> fail(result, e) }
    }

    /** Google's error as `playIntegrity` with its code (e.g. -2: no Play Store) and whether trying later may work. */
    private fun fail(result: Result, e: Exception) {
        val code = (e as? StandardIntegrityException)?.errorCode
        val retryable = code in setOf(
            StandardIntegrityErrorCode.NETWORK_ERROR, StandardIntegrityErrorCode.TOO_MANY_REQUESTS,
            StandardIntegrityErrorCode.GOOGLE_SERVER_UNAVAILABLE, StandardIntegrityErrorCode.CLIENT_TRANSIENT_ERROR,
            StandardIntegrityErrorCode.INTERNAL_ERROR, StandardIntegrityErrorCode.CANNOT_BIND_TO_SERVICE,
        )
        result.error("playIntegrity", e.message ?: "Play Integrity failed.", mapOf("code" to code, "retryable" to retryable))
    }
}
