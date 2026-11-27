package com.feiniao.portable

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "feiniao/portable")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "storeSave" -> {
                        val id = call.argument<String>("id")
                        val secret = call.argument<String>("secret")
                        if (id == null || secret == null) {
                            result.error("ARG_ERROR", "missing arguments", null)
                            return@setMethodCallHandler
                        }
                        try {
                            SecureStore.save(applicationContext, id, secret)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("STORE_ERROR", e.message, null)
                        }
                    }
                    "storeLoad" -> {
                        val id = call.argument<String>("id")
                        if (id == null) {
                            result.error("ARG_ERROR", "missing arguments", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(SecureStore.load(applicationContext, id))
                        } catch (e: Exception) {
                            result.error("STORE_ERROR", e.message, null)
                        }
                    }
                    "storeRemove" -> {
                        val id = call.argument<String>("id")
                        if (id == null) {
                            result.error("ARG_ERROR", "missing arguments", null)
                            return@setMethodCallHandler
                        }
                        try {
                            SecureStore.remove(applicationContext, id)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("STORE_ERROR", e.message, null)
                        }
                    }
                    "storeListIds" -> {
                        try {
                            result.success(SecureStore.listIds(applicationContext))
                        } catch (e: Exception) {
                            result.error("STORE_ERROR", e.message, null)
                        }
                    }
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url == null || !url.startsWith("https://")) {
                            result.error("ARG_ERROR", "仅允许打开 HTTPS 链接", null)
                            return@setMethodCallHandler
                        }
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("OPEN_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

object SecureStore {

    private const val PREFS = "feiniao_secure"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val KEY_ALIAS = "feiniao_portable_key"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(context: Context, id: String, secret: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val encrypted = cipher.iv + cipher.doFinal(secret.toByteArray(Charsets.UTF_8))
        prefs(context).edit().putString(id, Base64.encodeToString(encrypted, Base64.NO_WRAP)).apply()
    }

    fun load(context: Context, id: String): String? {
        val stored = prefs(context).getString(id, null) ?: return null
        val data = Base64.decode(stored, Base64.NO_WRAP)
        if (data.size < 13) {
            return null
        }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, data, 0, 12))
        return String(cipher.doFinal(data, 12, data.size - 12), Charsets.UTF_8)
    }

    fun remove(context: Context, id: String) {
        prefs(context).edit().remove(id).apply()
    }

    fun listIds(context: Context): List<String> = prefs(context).all.keys.toList()

    private fun key(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator =
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return generator.generateKey()
    }
}
