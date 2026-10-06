#include <jni.h>
#include <android/log.h>
#include <Vxc.h>
#include <VxcRequests.h>
#include <VxcResponses.h>
#include <VxcEvents.h>
#include <mutex>
#include <thread>
#include <atomic>

#define LOG_TAG "NimzoVivox"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static JavaVM* g_vm = nullptr;
static jobject g_callback = nullptr;
static jmethodID g_event_method = nullptr;
static std::mutex g_mu;
static VX_HANDLE g_connector = nullptr;
static VX_HANDLE g_account = nullptr;
static VX_HANDLE g_session_group = nullptr;
static VX_HANDLE g_session = nullptr;
static std::atomic<bool> g_initialized{false};
static std::atomic<bool> g_pump{false};
static std::thread g_thread;

static void emit(const char* event, int status, const char* detail) {
  if (!g_vm || !g_callback || !g_event_method) return;
  JNIEnv* env = nullptr;
  bool attached = false;
  if (g_vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
    if (g_vm->AttachCurrentThread(&env, nullptr) != JNI_OK) return;
    attached = true;
  }
  jstring je = env->NewStringUTF(event ? event : "");
  jstring jd = env->NewStringUTF(detail ? detail : "");
  env->CallVoidMethod(g_callback, g_event_method, je, (jint)status, jd);
  env->DeleteLocalRef(je);
  env->DeleteLocalRef(jd);
  if (attached) g_vm->DetachCurrentThread();
}

static void handle_message(vx_message_base_t* msg) {
  if (!msg) return;
  if (msg->type == msg_evt_media_stream_updated) {
    auto* e = reinterpret_cast<vx_evt_media_stream_updated_t*>(msg);
    emit(e->state == session_media_connected ? "audioConnected" : "audioState",
         e->status_code, e->status_string ? e->status_string : "");
  } else if (msg->type == msg_evt_participant_updated) {
    auto* e = reinterpret_cast<vx_evt_participant_updated_t*>(msg);
    emit(e->is_speaking ? "speaking" : "stoppedSpeaking",
         0, e->participant_uri ? e->participant_uri : "");
  } else if (msg->type == msg_evt_account_login_state_change) {
    auto* e = reinterpret_cast<vx_evt_account_login_state_change_t*>(msg);
    emit("loginState", e->status_code, e->status_string ? e->status_string : "");
  }
}

static int wait_for_response(vx_message_type wanted, int timeout_ms, vx_message_base_t** out) {
  const int slice = 100;
  int elapsed = 0;
  while (elapsed < timeout_ms) {
    vx_message_base_t* msg = vx_wait_for_message(slice);
    if (!msg) { elapsed += slice; continue; }
    if (msg->type == wanted) {
      *out = msg;
      return 0;
    }
    handle_message(msg);
    vx_destroy_message(msg);
    elapsed += slice;
  }
  return -1;
}

static void pump_loop() {
  while (g_pump.load()) {
    vx_message_base_t* msg = vx_wait_for_message(500);
    if (!msg) continue;
    handle_message(msg);
    vx_destroy_message(msg);
  }
}

extern "C" JNIEXPORT jboolean JNICALL
Java_io_nimzo_vivox_NimzoVivox_nativeInit(JNIEnv* env, jclass, jobject callback, jstring server) {
  std::lock_guard<std::mutex> lock(g_mu);
  if (g_initialized.load()) return JNI_TRUE;
  if (!g_vm) env->GetJavaVM(&g_vm);

  jclass cls = env->GetObjectClass(callback);
  g_callback = env->NewGlobalRef(callback);
  g_event_method = env->GetMethodID(cls, "onVivoxEvent", "(Ljava/lang/String;ILjava/lang/String;)V");
  if (!g_event_method) return JNI_FALSE;

  vx_sdk_config_t cfg;
  int rc = vx_get_default_config3(&cfg, sizeof(cfg));
  if (rc != VxErrorSuccess) { emit("error", rc, vx_get_error_string(rc)); return JNI_FALSE; }
  rc = vx_initialize3(&cfg, sizeof(cfg));
  if (rc != VxErrorSuccess) { emit("error", rc, vx_get_error_string(rc)); return JNI_FALSE; }

  const char* acctServer = env->GetStringUTFChars(server, nullptr);
  vx_req_connector_create_t* req = nullptr;
  rc = vx_req_connector_create_create(&req);
  if (rc == VxErrorSuccess) {
    req->connector_handle = vx_strdup("nimzo_connector");
    req->acct_mgmt_server = vx_strdup(acctServer);
    req->log_level = 1;
    int request_count = 0;
    rc = vx_issue_request3(&req->base, &request_count);
  }
  env->ReleaseStringUTFChars(server, acctServer);
  if (rc != VxErrorSuccess) { emit("error", rc, vx_get_error_string(rc)); return JNI_FALSE; }

  vx_message_base_t* msg = nullptr;
  if (wait_for_response(msg_resp_connector_create, 15000, &msg) != 0) {
    emit("error", -2, "Vivox connector_create timeout");
    return JNI_FALSE;
  }
  auto* resp = reinterpret_cast<vx_resp_connector_create_t*>(msg);
  if (resp->base.status_code != 0) {
    emit("error", resp->base.status_code, resp->base.status_string ? resp->base.status_string : "");
    vx_destroy_message(msg);
    return JNI_FALSE;
  }
  g_connector = resp->connector_handle;
  vx_destroy_message(msg);
  g_initialized = true;
  emit("initialized", 0, "connector_ready");
  return JNI_TRUE;
}

extern "C" JNIEXPORT jint JNICALL
Java_io_nimzo_vivox_NimzoVivox_nativeLoginAndJoin(JNIEnv* env, jclass,
                                                   jstring loginToken,
                                                   jstring channelToken,
                                                   jstring channelUri) {
  std::lock_guard<std::mutex> lock(g_mu);
  if (!g_initialized.load() || !g_connector) return -100;
  const char* lt = env->GetStringUTFChars(loginToken, nullptr);
  const char* ct = env->GetStringUTFChars(channelToken, nullptr);
  const char* cu = env->GetStringUTFChars(channelUri, nullptr);

  vx_req_account_authtoken_login_t* login = nullptr;
  int rc = vx_req_account_authtoken_login_create(&login);
  if (rc == VxErrorSuccess) {
    login->connector_handle = g_connector;
    login->authtoken = vx_strdup(lt);
    login->account_handle = vx_strdup("nimzo_account");
    login->enable_text = text_mode_disabled;
    login->enable_buddies_and_presence = 0;
    login->enable_presence_persistence = 0;
    int login_request_count = 0;
    rc = vx_issue_request3(&login->base, &login_request_count);
  }
  if (rc != VxErrorSuccess) {
    env->ReleaseStringUTFChars(loginToken, lt);
    env->ReleaseStringUTFChars(channelToken, ct);
    env->ReleaseStringUTFChars(channelUri, cu);
    return rc;
  }

  vx_message_base_t* msg = nullptr;
  if (wait_for_response(msg_resp_account_authtoken_login, 20000, &msg) != 0) {
    env->ReleaseStringUTFChars(loginToken, lt);
    env->ReleaseStringUTFChars(channelToken, ct);
    env->ReleaseStringUTFChars(channelUri, cu);
    return -101;
  }
  auto* lr = reinterpret_cast<vx_resp_account_authtoken_login_t*>(msg);
  if (lr->base.status_code != 0) {
    int status = lr->base.status_code;
    emit("error", status, lr->base.status_string ? lr->base.status_string : "");
    vx_destroy_message(msg);
    env->ReleaseStringUTFChars(loginToken, lt);
    env->ReleaseStringUTFChars(channelToken, ct);
    env->ReleaseStringUTFChars(channelUri, cu);
    return status;
  }
  g_account = lr->account_handle;
  vx_destroy_message(msg);

  vx_req_sessiongroup_add_session_t* join = nullptr;
  rc = vx_req_sessiongroup_add_session_create(&join);
  if (rc == VxErrorSuccess) {
    join->sessiongroup_handle = vx_strdup("nimzo_room_group");
    join->session_handle = vx_strdup("nimzo_room_session");
    join->uri = vx_strdup(cu);
    join->connect_audio = 1;
    join->connect_text = 0;
    join->access_token = vx_strdup(ct);
    join->account_handle = g_account;
    int join_request_count = 0;
    rc = vx_issue_request3(&join->base, &join_request_count);
  }
  env->ReleaseStringUTFChars(loginToken, lt);
  env->ReleaseStringUTFChars(channelToken, ct);
  env->ReleaseStringUTFChars(channelUri, cu);
  if (rc != VxErrorSuccess) return rc;

  vx_message_base_t* join_msg = nullptr;
  if (wait_for_response(msg_resp_sessiongroup_add_session, 15000, &join_msg) != 0) {
    emit("error", -102, "Vivox session join response timeout");
    return -102;
  }
  auto* join_resp = reinterpret_cast<vx_resp_sessiongroup_add_session_t*>(join_msg);
  if (join_resp->base.status_code != 0) {
    const int status = join_resp->base.status_code;
    emit("error", status, join_resp->base.status_string ? join_resp->base.status_string : "");
    vx_destroy_message(join_msg);
    return status;
  }
  g_session_group = join_resp->sessiongroup_handle;
  g_session = join_resp->session_handle;
  vx_destroy_message(join_msg);

  if (!g_pump.exchange(true)) g_thread = std::thread(pump_loop);
  emit("joined", 0, "join_requested");
  return 0;
}

extern "C" JNIEXPORT jint JNICALL
Java_io_nimzo_vivox_NimzoVivox_nativeSetMic(JNIEnv*, jclass, jboolean enabled) {
  if (!g_connector) return -100;
  vx_req_connector_mute_local_mic_t* req = nullptr;
  int rc = vx_req_connector_mute_local_mic_create(&req);
  if (rc != VxErrorSuccess) return rc;
  req->connector_handle = g_connector;
  req->account_handle = g_account;
  req->mute_level = enabled ? 0 : 1;
  return vx_issue_request3(&req->base, nullptr);
}

extern "C" JNIEXPORT jint JNICALL
Java_io_nimzo_vivox_NimzoVivox_nativeSetSpeaker(JNIEnv*, jclass, jboolean enabled) {
  if (!g_connector) return -100;
  vx_req_connector_mute_local_speaker_t* req = nullptr;
  int rc = vx_req_connector_mute_local_speaker_create(&req);
  if (rc != VxErrorSuccess) return rc;
  req->connector_handle = g_connector;
  req->account_handle = g_account;
  req->mute_level = enabled ? 0 : 1;
  return vx_issue_request3(&req->base, nullptr);
}

extern "C" JNIEXPORT jint JNICALL
Java_io_nimzo_vivox_NimzoVivox_nativeLeave(JNIEnv*, jclass) {
  if (!g_account) return 0;
  if (g_session && g_session_group) {
    vx_req_sessiongroup_remove_session_t* req = nullptr;
    if (vx_req_sessiongroup_remove_session_create(&req) == VxErrorSuccess) {
      req->sessiongroup_handle = g_session_group;
      req->session_handle = g_session;
      vx_issue_request3(&req->base, nullptr);
    }
  }
  vx_req_account_logout_t* logout = nullptr;
  if (vx_req_account_logout_create(&logout) == VxErrorSuccess) {
    logout->account_handle = g_account;
    vx_issue_request3(&logout->base, nullptr);
  }
  g_session = nullptr;
  g_session_group = nullptr;
  g_account = nullptr;
  emit("left", 0, "left");
  return 0;
}

extern "C" JNIEXPORT void JNICALL
Java_io_nimzo_vivox_NimzoVivox_nativeShutdown(JNIEnv* env, jclass) {
  g_pump = false;
  if (g_thread.joinable()) g_thread.join();
  std::lock_guard<std::mutex> lock(g_mu);
  if (g_initialized.exchange(false)) vx_uninitialize();
  if (g_callback) { env->DeleteGlobalRef(g_callback); g_callback = nullptr; }
  g_event_method = nullptr;
  g_connector = nullptr;
  g_account = nullptr;
  g_session = nullptr;
  g_session_group = nullptr;
}
