package com.zameel.app

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Per-account installation proof encrypted with a non-exportable Android Keystore key. */
object DeviceTrust160 {
    private const val alias = "zameel_device_trust_160"
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    @Synchronized private fun proof(context: Context, user: String): String {
        require(Regex("^[a-fA-F0-9-]{36}$").matches(user))
        val file = java.io.File(context.noBackupFilesDir, "device160-$user")
        if (file.exists()) {
            try {
                val data = Base64.decode(file.readText(), Base64.NO_WRAP)
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, data.copyOfRange(0, 12)))
                cipher.updateAAD(user.toByteArray(Charsets.UTF_8))
                val value = String(cipher.doFinal(data.copyOfRange(12, data.size)), Charsets.UTF_8)
                require(Regex("^[a-f0-9]{64}$").matches(value))
                return value
            } catch (_: Exception) { file.delete() } // Lost key: require a fresh email verification.
        }
        val value = ByteArray(32).also { SecureRandom().nextBytes(it) }.joinToString("") { "%02x".format(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        cipher.updateAAD(user.toByteArray(Charsets.UTF_8))
        val encrypted = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val temp = java.io.File(file.path + ".tmp")
        temp.writeText(Base64.encodeToString(encrypted, Base64.NO_WRAP))
        check(temp.renameTo(file))
        return value
    }
    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "zameel/device_trust160").setMethodCallHandler { call, result ->
            if (call.method != "proof") result.notImplemented()
            else try { result.success(proof(context, call.argument<String>("userId") ?: "")) }
            catch (_: Exception) { result.error("secure_device_storage_unavailable", "Unable to secure device proof", null) }
        }
    }
}
