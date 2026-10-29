package com.tntlikely.beecount

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.util.UUID

/** Native persistent inbox: survives Flutter being stopped, no network or AI upload. */
object PaymentCaptureStore {
    private fun prefs(c: Context) = c.getSharedPreferences("payment_capture", Context.MODE_PRIVATE)
    fun enabled(c: Context, source: String) = prefs(c).getBoolean(source, false)
    @Synchronized fun setEnabled(c: Context, source: String, value: Boolean) {
        require(source == "notification" || source == "page")
        check(prefs(c).edit().putBoolean(source, value).commit())
    }
    private fun hash(s: String) = MessageDigest.getInstance("SHA-256").digest(s.toByteArray()).joinToString("") { "%02x".format(it) }
    @Synchronized fun capture(c: Context, pkg: String, text: String, source: String, eventId: String, time: Long) {
        if (!enabled(c, source)) return
        val parsed = PaymentTextParser.parse(pkg, text, source == "page") ?: return
        val p = prefs(c)
        val items = JSONArray(p.getString("items", "[]"))
        val seen = JSONObject(p.getString("seen", "{}") ?: "{}")
        val identity = hash(if (parsed.orderId != null) "$pkg:order:${parsed.orderId}" else "$pkg:$source:$eventId")
        if (seen.has(identity)) return
        // Never silently discard old pending payments on capacity overflow.
        if (items.length() >= 500) { p.edit().putBoolean("full", true).apply(); return }
        var duplicate = false
        for (i in 0 until items.length()) {
            val item = items.getJSONObject(i)
            if (item.optString("package") == pkg && parsed.amount != null && item.optString("amount") == parsed.amount &&
                kotlin.math.abs(time - item.getLong("time")) < 120000) duplicate = true
        }
        val item = JSONObject().put("id", UUID.randomUUID().toString()).put("package", pkg)
            .put("source", source).put("time", time).put("text", text.take(12000))
            .put("amount", parsed.amount ?: JSONObject.NULL).put("merchant", parsed.merchant ?: JSONObject.NULL)
            .put("possibleDuplicate", duplicate)
        items.put(item)
        seen.put(identity, System.currentTimeMillis())
        val now = System.currentTimeMillis()
        val keys = seen.keys().asSequence().toList()
        keys.filter { now - seen.getLong(it) > 7L * 86400000 }.forEach { seen.remove(it) }
        check(p.edit().putString("items", items.toString()).putString("seen", seen.toString()).commit())
    }
    @Synchronized fun list(c: Context) = JSONArray(prefs(c).getString("items", "[]"))
    @Synchronized fun remove(c: Context, id: String) {
        val remaining = JSONArray()
        val items = list(c)
        for(i in 0 until items.length()) if(items.getJSONObject(i).getString("id") != id) remaining.put(items.getJSONObject(i))
        check(prefs(c).edit().putString("items", remaining.toString()).putBoolean("full", false).commit())
    }
    fun full(c: Context) = prefs(c).getBoolean("full", false)
}
