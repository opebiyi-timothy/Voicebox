#!/bin/bash
set -e
# Recreates the Android project in ./android
mkdir -p android/.
cat > android/build.gradle.kts <<'END_OF_FILE'
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.20" apply false
}
END_OF_FILE
mkdir -p android/.
cat > android/gradle.properties <<'END_OF_FILE'
org.gradle.jvmargs=-Xmx2048m
android.useAndroidX=true
END_OF_FILE
mkdir -p android/.
cat > android/settings.gradle.kts <<'END_OF_FILE'
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositories { google(); mavenCentral() } }
rootProject.name = "VoiceboxMobile"
include(":app")
END_OF_FILE
mkdir -p android/app
cat > android/app/build.gradle.kts <<'END_OF_FILE'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}
android {
    namespace = "com.example.voiceboxmobile"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.example.voiceboxmobile"
        minSdk = 26; targetSdk = 34; versionCode = 1; versionName = "1.0"
    }
    buildFeatures { compose = true }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.6")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}
END_OF_FILE
mkdir -p android/app/src/main
cat > android/app/src/main/AndroidManifest.xml <<'END_OF_FILE'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <application
        android:label="Voicebox Mobile"
        android:usesCleartextTraffic="false"
        android:theme="@android:style/Theme.Material.Light.NoActionBar">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
END_OF_FILE
mkdir -p android/app/src/main/java/com/example/voiceboxmobile
cat > android/app/src/main/java/com/example/voiceboxmobile/MainActivity.kt <<'END_OF_FILE'
package com.example.voiceboxmobile

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

class MainActivity : ComponentActivity() {
    private val vm: MainViewModel by viewModels()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        vm.refresh()
        setContent { MaterialTheme { App(vm) } }
    }
}

@Composable
fun App(vm: MainViewModel) {
    var tab by remember { mutableIntStateOf(0) }
    val tabs = listOf("Voices", "Presets", "Speak", "History", "Settings")
    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEachIndexed { i, t ->
                    NavigationBarItem(selected = tab == i, onClick = { tab = i }, icon = {}, label = { Text(t) })
                }
            }
        }
    ) { pad ->
        Column(Modifier.padding(pad).padding(16.dp).fillMaxSize()) {
            if (vm.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
                when (tab) {
                    0 -> VoicesTab(vm)
                    1 -> PresetsTab(vm)
                    2 -> SpeakTab(vm)
                    3 -> HistoryTab(vm)
                    else -> SettingsTab(vm)
                }
            }
            Text(vm.status, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
fun VoicesTab(vm: MainViewModel) {
    var name by remember { mutableStateOf("") }
    var lang by remember { mutableStateOf("en") }
    var refText by remember { mutableStateOf("") }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri -> uri?.let { vm.importSample(it) } }
    val restore = rememberLauncherForActivityResult(ActivityResultContracts.GetMultipleContents()) { uris -> if (uris.isNotEmpty()) vm.restoreVoices(uris) }
    val mic = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { if (it) vm.toggleRecord() }

    Text("Voices", style = MaterialTheme.typography.titleLarge)
    LazyColumn(Modifier.heightIn(max = 180.dp)) {
        items(vm.profiles) { p ->
            Text(
                (if (vm.selected?.id == p.id) "● " else "○ ") + "${p.name} (${p.language})",
                Modifier.fillMaxWidth().clickable { vm.selected = p }.padding(8.dp)
            )
        }
    }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(name, { name = it }, label = { Text("New voice name") }, modifier = Modifier.weight(1f))
        OutlinedTextField(lang, { lang = it }, label = { Text("Lang") }, modifier = Modifier.width(80.dp))
    }
    Button(onClick = { vm.createProfile(name, lang) }, enabled = name.isNotBlank()) { Text("Create voice") }
    HorizontalDivider(Modifier.padding(vertical = 8.dp))
    Text("Add sample to: ${vm.selected?.name ?: "(select a voice)"}")
    OutlinedTextField(refText, { refText = it }, label = { Text("What you said (blank = auto-transcribe)") }, modifier = Modifier.fillMaxWidth())
    OutlinedButton(onClick = { pick.launch("audio/*") }) { Text("Choose audio file instead") }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Button(onClick = { if (vm.recording) vm.toggleRecord() else mic.launch(Manifest.permission.RECORD_AUDIO) }) {
            Text(if (vm.recording) "Stop" else "Record")
        }
        Button(onClick = { vm.uploadSample(refText) }, enabled = !vm.recording && !vm.busy) { Text("Upload") }
    }
    HorizontalDivider(Modifier.padding(vertical = 8.dp))
    Text("Backup (keeps your cloned voices safe if the server resets)", style = MaterialTheme.typography.bodySmall)
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedButton(onClick = { vm.backupAll() }, enabled = !vm.busy) { Text("Back up my voices") }
        OutlinedButton(onClick = { restore.launch("*/*") }, enabled = !vm.busy) { Text("Restore from file") }
    }
}

@Composable
fun SpeakTab(vm: MainViewModel) {
    var text by remember { mutableStateOf("") }
    LaunchedEffect(Unit) { if (vm.effectPresets.isEmpty()) vm.loadEffects() }
    Text("Speak as: ${vm.selected?.name ?: "(pick a voice in Voices)"}", style = MaterialTheme.typography.titleMedium)
    OutlinedTextField(text, { text = it }, label = { Text("Text") }, modifier = Modifier.fillMaxWidth().height(160.dp))
    if (vm.effectPresets.isNotEmpty()) {
        Text("Effect", style = MaterialTheme.typography.bodySmall)
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            item { FilterChip(vm.effectIndex == -1, { vm.effectIndex = -1 }, { Text("None") }) }
            itemsIndexed(vm.effectPresets) { i, e -> FilterChip(vm.effectIndex == i, { vm.effectIndex = i }, { Text(e.first) }) }
        }
    }
    Button(onClick = { vm.speak(text) }, enabled = text.isNotBlank() && vm.selected != null && !vm.busy) { Text("Generate & play") }
    if (vm.lastAudio != null) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = { vm.saveAudio() }) { Text("Save") }
            OutlinedButton(onClick = { vm.shareAudio() }) { Text("Share") }
        }
    }
}

@Composable
fun HistoryTab(vm: MainViewModel) {
    LaunchedEffect(Unit) { vm.loadHistory() }
    Text("History", style = MaterialTheme.typography.titleLarge)
    Text("Tap an item to play it.", style = MaterialTheme.typography.bodySmall)
    LazyColumn(Modifier.heightIn(max = 400.dp)) {
        items(vm.history) { h ->
            Column(Modifier.fillMaxWidth().clickable { vm.playHistory(h.id) }.padding(8.dp)) {
                Text(h.text.take(90))
                Text(h.who, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
    if (vm.lastAudio != null) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = { vm.saveAudio() }) { Text("Save") }
            OutlinedButton(onClick = { vm.shareAudio() }) { Text("Share") }
        }
    }
}

@Composable
fun SettingsTab(vm: MainViewModel) {
    Text("Server", style = MaterialTheme.typography.titleLarge)
    OutlinedTextField(vm.serverUrl, { vm.serverUrl = it }, label = { Text("https://voice.example.com") }, modifier = Modifier.fillMaxWidth())
    OutlinedTextField(vm.apiKey, { vm.apiKey = it }, label = { Text("API key") }, modifier = Modifier.fillMaxWidth())
    Button(onClick = { vm.saveSettings() }) { Text("Save & connect") }
}

@Composable
fun PresetsTab(vm: MainViewModel) {
    LaunchedEffect(Unit) { if (vm.presets.isEmpty()) vm.loadPresets() }
    Text("Built-in voices", style = MaterialTheme.typography.titleLarge)
    Text("Tap a voice, then open the Speak tab. The first use downloads the voice model (a few minutes).", style = MaterialTheme.typography.bodySmall)
    LazyColumn(Modifier.heightIn(max = 460.dp)) {
        items(vm.presets) { (id, label) ->
            Text(
                (if (vm.selected?.name == label) "● " else "○ ") + label,
                Modifier.fillMaxWidth().clickable { vm.usePreset(id, label) }.padding(12.dp)
            )
        }
    }
}
END_OF_FILE
mkdir -p android/app/src/main/java/com/example/voiceboxmobile
cat > android/app/src/main/java/com/example/voiceboxmobile/MainViewModel.kt <<'END_OF_FILE'
package com.example.voiceboxmobile

import android.app.Application
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import org.json.JSONArray
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import android.media.MediaPlayer
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.launch
import java.io.File

class MainViewModel(app: Application) : AndroidViewModel(app) {
    private val prefs = app.getSharedPreferences("settings", 0)
    var serverUrl by mutableStateOf(prefs.getString("url", "") ?: "")
    var apiKey by mutableStateOf(prefs.getString("key", "") ?: "")
    var profiles by mutableStateOf<List<Profile>>(emptyList())
    var selected by mutableStateOf<Profile?>(null)
    var status by mutableStateOf("")
    var busy by mutableStateOf(false)
    var recording by mutableStateOf(false)

    private var recorder: WavRecorder? = null
    private var sampleFile = File(app.cacheDir, "sample.wav")
    var presets by mutableStateOf<List<Pair<String, String>>>(emptyList())
    var lastAudio by mutableStateOf<ByteArray?>(null)
    private var player: MediaPlayer? = null
    var history by mutableStateOf<List<HistoryItem>>(emptyList())
    var effectPresets by mutableStateOf<List<Pair<String, JSONArray>>>(emptyList())
    var effectIndex by mutableStateOf(-1)

    private fun api() = VoiceboxApi(serverUrl, apiKey)

    fun saveSettings() {
        prefs.edit().putString("url", serverUrl).putString("key", apiKey).apply()
        status = "Saved"; refresh()
    }

    private fun run(block: suspend () -> Unit) = viewModelScope.launch {
        busy = true
        try { block() } catch (e: Exception) { status = "Error: ${e.message}" }
        busy = false
    }

    fun refresh() { if (serverUrl.isNotBlank()) run { profiles = api().listProfiles() } }

    fun createProfile(name: String, language: String) = run {
        selected = api().createProfile(name, language); profiles = api().listProfiles()
        status = "Created ${selected?.name}"
    }

    fun loadPresets() { if (serverUrl.isNotBlank()) run { presets = api().listPresets("kokoro") } }

    fun usePreset(id: String, label: String) = run {
        val existing = profiles.firstOrNull { it.presetEngine == "kokoro" && it.name == label }
        selected = existing ?: api().createPreset(label, "en", "kokoro", id).also { profiles = api().listProfiles() }
        status = "Selected $label. Now open the Speak tab."
    }

    fun toggleRecord() {
        if (recording) { recorder?.stop(); recording = false; status = "Recorded ${sampleFile.length() / 1024} KB" }
        else { sampleFile = File(getApplication<Application>().cacheDir, "sample.wav"); recorder = WavRecorder(sampleFile).also { it.start() }; recording = true; status = "Recording…" }
    }

    fun importSample(uri: Uri) = run {
        val app = getApplication<Application>()
        var name = "sample.wav"
        app.contentResolver.query(uri, null, null, null, null)?.use { c ->
            val i = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (i >= 0 && c.moveToFirst()) name = c.getString(i) ?: name
        }
        val ext = name.substringAfterLast('.', "wav").lowercase().ifBlank { "wav" }
        val f = File(app.cacheDir, "sample.$ext")
        withContext(Dispatchers.IO) {
            app.contentResolver.openInputStream(uri)!!.use { inp -> f.outputStream().use { inp.copyTo(it) } }
        }
        sampleFile = f
        status = "Picked $name (${f.length() / 1024} KB)"
    }

    private fun saveToDownloads(
        bytes: ByteArray,
        name: String = "voicebox_${System.currentTimeMillis()}.wav",
        mime: String = "audio/wav"
    ): Uri? {
        val app = getApplication<Application>()
        return try {
            if (Build.VERSION.SDK_INT >= 29) {
                val v = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, name)
                    put(MediaStore.Downloads.MIME_TYPE, mime)
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                }
                val uri = app.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, v)!!
                app.contentResolver.openOutputStream(uri)!!.use { it.write(bytes) }
                status = "Saved to Downloads: $name"
                uri
            } else {
                val dir = app.getExternalFilesDir(Environment.DIRECTORY_MUSIC)!!
                File(dir, name).writeBytes(bytes)
                status = "Saved to ${dir.path}"
                null
            }
        } catch (e: Exception) { status = "Save failed: ${e.message}"; null }
    }

    fun backupAll() = run {
        val custom = profiles.filter { it.presetEngine == null }
        if (custom.isEmpty()) error("No cloned voices to back up")
        for (p in custom) {
            val zip = api().exportProfile(p.id)
            saveToDownloads(zip, "voice_${p.name.replace(Regex("[^A-Za-z0-9_-]"), "_")}.zip", "application/zip")
        }
        status = "Backed up ${custom.size} voice(s) to Downloads"
    }

    fun restoreVoices(uris: List<Uri>) = run {
        val app = getApplication<Application>()
        for (u in uris) {
            val bytes = withContext(Dispatchers.IO) { app.contentResolver.openInputStream(u)!!.use { it.readBytes() } }
            api().importProfile(bytes)
        }
        profiles = api().listProfiles()
        status = "Restored ${uris.size} voice(s)"
    }

    fun saveAudio() { lastAudio?.let { saveToDownloads(it) } }

    fun shareAudio() {
        val b = lastAudio ?: return
        val uri = saveToDownloads(b)
        if (uri == null) { status = "Sharing needs Android 10 or newer"; return }
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "audio/wav"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        getApplication<Application>().startActivity(
            Intent.createChooser(send, "Share audio").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    private fun play(bytes: ByteArray) {
        val f = File(getApplication<Application>().cacheDir, "out.wav").also { it.writeBytes(bytes) }
        player?.release()
        player = MediaPlayer().apply { setDataSource(f.path); prepare(); start() }
    }

    fun loadHistory() { if (serverUrl.isNotBlank()) run { history = api().listHistory() } }

    fun playHistory(id: String) = run {
        status = "Loading…"
        val bytes = api().audio(id)
        lastAudio = bytes; play(bytes); status = "Playing"
    }

    fun loadEffects() { if (serverUrl.isNotBlank()) run { effectPresets = api().listEffectPresets() } }

    fun uploadSample(referenceText: String) = run {
        val p = selected ?: error("Select a voice first")
        if (!sampleFile.exists()) error("Record a sample first")
        var text = referenceText.trim()
        if (text.isEmpty()) { status = "Transcribing…"; text = api().transcribe(sampleFile) }
        api().addSample(p.id, sampleFile, text); status = "Sample uploaded: \"${text.take(60)}\""
    }

    fun speak(text: String) = run {
        val p = selected ?: error("Select a voice first")
        status = "Generating…"
        val chain = effectPresets.getOrNull(effectIndex)?.second
        val bytes = api().generate(p.id, text, p.language, p.presetEngine, chain) { status = it }
        lastAudio = bytes
        play(bytes)
        status = "Playing"
    }

    override fun onCleared() { player?.release() }
}
END_OF_FILE
mkdir -p android/app/src/main/java/com/example/voiceboxmobile
cat > android/app/src/main/java/com/example/voiceboxmobile/VoiceboxApi.kt <<'END_OF_FILE'
package com.example.voiceboxmobile

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import android.webkit.MimeTypeMap
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

data class HistoryItem(val id: String, val who: String, val text: String)

data class Profile(val id: String, val name: String, val language: String, val presetEngine: String? = null)

/**
 * ALL server endpoint assumptions live in this file. Compare against
 * https://<your-server>/docs (OpenAPI) and adjust paths/fields below.
 */
class VoiceboxApi(baseUrl: String, apiKey: String) {
    private val base = baseUrl.trimEnd('/')
    private val json = "application/json".toMediaType()
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(300, TimeUnit.SECONDS)
        .writeTimeout(120, TimeUnit.SECONDS)
        .addInterceptor { it.proceed(it.request().newBuilder().header("X-API-Key", apiKey).build()) }
        .build()

    private suspend fun <T> exec(req: Request, parse: (Response) -> T): T = withContext(Dispatchers.IO) {
        client.newCall(req).execute().use {
            if (!it.isSuccessful) error("HTTP ${it.code}: ${it.body?.string()?.take(200)}")
            parse(it)
        }
    }

    private fun mediaTypeFor(f: File) =
        (MimeTypeMap.getSingleton().getMimeTypeFromExtension(f.extension.lowercase()) ?: "application/octet-stream").toMediaType()

    private fun parseProfile(o: JSONObject) =
        Profile(
            o.optString("id"), o.optString("name"), o.optString("language", "en"),
            if (o.isNull("preset_engine")) null else o.optString("preset_engine").ifBlank { null }
        )

    // GET /profiles -> [ {id,name,language}, ... ]
    suspend fun listProfiles(): List<Profile> = exec(Request.Builder().url("$base/profiles").build()) {
        val txt = it.body!!.string()
        val arr = if (txt.trim().startsWith("[")) JSONArray(txt) else JSONObject(txt).optJSONArray("profiles") ?: JSONArray()
        (0 until arr.length()).map { i -> parseProfile(arr.getJSONObject(i)) }
    }

    // POST /profiles {name, language} -> profile
    suspend fun createProfile(name: String, language: String): Profile {
        val body = JSONObject().put("name", name).put("language", language).toString().toRequestBody(json)
        return exec(Request.Builder().url("$base/profiles").post(body).build()) {
            parseProfile(JSONObject(it.body!!.string()))
        }
    }


    private fun pretty(id: String): String {
        val parts = id.split("_")
        if (parts.size < 2) return id
        val g = when (parts[0]) { "af" -> "US female"; "am" -> "US male"; "bf" -> "UK female"; "bm" -> "UK male"; else -> parts[0] }
        return parts.drop(1).joinToString(" ").replaceFirstChar { it.uppercase() } + " ($g)"
    }

    private val fallbackPresets = listOf(
        "af_heart", "af_bella", "af_nicole", "af_sarah", "af_sky",
        "am_adam", "am_michael", "bf_emma", "bf_isabella", "bm_george", "bm_lewis"
    ).map { it to pretty(it) }

    // GET /profiles/presets/{engine}: response shape unknown, so parse flexibly; fall back to a built-in list
    suspend fun listPresets(engine: String): List<Pair<String, String>> {
        val parsed = runCatching {
            exec(Request.Builder().url("$base/profiles/presets/$engine").build()) {
                val any = org.json.JSONTokener(it.body!!.string()).nextValue()
                val arr: JSONArray? = when (any) {
                    is JSONArray -> any
                    is JSONObject -> any.optJSONArray("voices") ?: any.optJSONArray("presets")
                        ?: any.keys().asSequence().mapNotNull { k -> any.optJSONArray(k) }.firstOrNull()
                    else -> null
                }
                (0 until (arr?.length() ?: 0)).mapNotNull { i ->
                    when (val e = arr!!.get(i)) {
                        is String -> e to pretty(e)
                        is JSONObject -> {
                            val id = e.optString("voice_id").ifBlank { e.optString("id") }.ifBlank { e.optString("name") }
                            if (id.isBlank()) null else id to e.optString("name").ifBlank { pretty(id) }
                        }
                        else -> null
                    }
                }
            }
        }.getOrNull().orEmpty()
        return parsed.ifEmpty { fallbackPresets }
    }

    // POST /profiles with voice_type "preset"
    suspend fun createPreset(name: String, language: String, engine: String, voiceId: String): Profile {
        val body = JSONObject().put("name", name).put("language", language)
            .put("voice_type", "preset").put("preset_engine", engine)
            .put("preset_voice_id", voiceId).put("default_engine", engine)
            .toString().toRequestBody(json)
        return exec(Request.Builder().url("$base/profiles").post(body).build()) {
            parseProfile(JSONObject(it.body!!.string()))
        }
    }


    // GET /history -> {items:[{id,profile_name,text,status}], total}
    suspend fun listHistory(): List<HistoryItem> = exec(Request.Builder().url("$base/history?limit=50").build()) { r ->
        val arr = JSONObject(r.body!!.string()).optJSONArray("items") ?: JSONArray()
        (0 until arr.length()).map { arr.getJSONObject(it) }
            .filter { o -> o.optString("status") == "completed" }
            .map { o -> HistoryItem(o.optString("id"), o.optString("profile_name"), o.optString("text")) }
    }

    // GET /audio/{id}
    suspend fun audio(id: String): ByteArray = exec(Request.Builder().url("$base/audio/$id").build()) { it.body!!.bytes() }

    // GET /effects/presets -> [{name, effects_chain}]
    suspend fun listEffectPresets(): List<Pair<String, JSONArray>> = exec(Request.Builder().url("$base/effects/presets").build()) { r ->
        val arr = JSONArray(r.body!!.string())
        (0 until arr.length()).map { arr.getJSONObject(it) }
            .map { o -> o.optString("name") to (o.optJSONArray("effects_chain") ?: JSONArray()) }
    }

    // GET /profiles/{id}/export -> ZIP
    suspend fun exportProfile(id: String): ByteArray =
        exec(Request.Builder().url("$base/profiles/$id/export").build()) { it.body!!.bytes() }

    // POST /profiles/import multipart: file (ZIP)
    suspend fun importProfile(zip: ByteArray) {
        val body = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("file", "voice.zip", zip.toRequestBody("application/zip".toMediaType()))
            .build()
        exec(Request.Builder().url("$base/profiles/import").post(body).build()) { }
    }

    // POST /profiles/{id}/samples multipart: file (wav), reference_text
    suspend fun addSample(profileId: String, wav: File, referenceText: String) {
        val body = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("file", wav.name, wav.asRequestBody(mediaTypeFor(wav)))
            .addFormDataPart("reference_text", referenceText)
            .build()
        exec(Request.Builder().url("$base/profiles/$profileId/samples").post(body).build()) { }
    }

    // POST /transcribe multipart: file -> {text, duration}
    suspend fun transcribe(wav: File): String {
        val body = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("file", wav.name, wav.asRequestBody(mediaTypeFor(wav)))
            .build()
        return exec(Request.Builder().url("$base/transcribe").post(body).build()) {
            JSONObject(it.body!!.string()).getString("text")
        }
    }

    // POST /generate -> {id,status:"generating"}; poll GET /history/{id}; then GET /audio/{id}
    suspend fun generate(profileId: String, text: String, language: String, engine: String? = null, effects: JSONArray? = null, onStatus: (String) -> Unit = {}): ByteArray {
        val body = JSONObject().put("profile_id", profileId).put("text", text).put("language", language)
            .apply { if (engine != null) put("engine", engine); if (effects != null) put("effects_chain", effects) }
            .toString().toRequestBody(json)
        val id = exec(Request.Builder().url("$base/generate").post(body).build()) {
            JSONObject(it.body!!.string()).getString("id")
        }
        val deadline = System.currentTimeMillis() + 20 * 60_000L
        var failures = 0
        while (System.currentTimeMillis() < deadline) {
            val r = runCatching {
                exec(Request.Builder().url("$base/history/$id").build()) {
                    val o = JSONObject(it.body!!.string())
                    o.optString("status") to o.optString("error")
                }
            }.getOrNull()
            if (r == null) { if (++failures > 8) error("Lost contact with server") }
            else {
                failures = 0
                when (r.first) {
                    "completed" -> return exec(Request.Builder().url("$base/audio/$id").build()) { it.body!!.bytes() }
                    "failed" -> error("Generation failed: ${r.second}")
                }
                onStatus("Generating… (${r.first}; first run downloads the model and can take minutes)")
            }
            delay(1500)
        }
        error("Timed out waiting for audio")
    }
}
END_OF_FILE
mkdir -p android/app/src/main/java/com/example/voiceboxmobile
cat > android/app/src/main/java/com/example/voiceboxmobile/WavRecorder.kt <<'END_OF_FILE'
package com.example.voiceboxmobile

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Records 16 kHz mono PCM16 into a WAV file. Needs RECORD_AUDIO granted. */
class WavRecorder(private val out: File) {
    private val rate = 16000
    private var rec: AudioRecord? = null
    private var thread: Thread? = null
    @Volatile private var running = false

    @SuppressLint("MissingPermission")
    fun start() {
        val size = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT) * 2
        val r = AudioRecord(MediaRecorder.AudioSource.MIC, rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, size)
        rec = r; running = true; r.startRecording()
        thread = Thread {
            RandomAccessFile(out, "rw").use { f ->
                f.setLength(0); f.write(ByteArray(44))
                val buf = ByteArray(size); var total = 0
                while (running) {
                    val n = r.read(buf, 0, buf.size)
                    if (n > 0) { f.write(buf, 0, n); total += n }
                }
                f.seek(0); f.write(header(total))
            }
        }.also { it.start() }
    }

    fun stop() { running = false; thread?.join(); rec?.stop(); rec?.release(); rec = null }

    private fun header(len: Int): ByteArray = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN).apply {
        put("RIFF".toByteArray()); putInt(36 + len); put("WAVE".toByteArray())
        put("fmt ".toByteArray()); putInt(16); putShort(1); putShort(1)
        putInt(rate); putInt(rate * 2); putShort(2); putShort(16)
        put("data".toByteArray()); putInt(len)
    }.array()
}
END_OF_FILE
