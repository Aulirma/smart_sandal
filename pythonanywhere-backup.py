
import os
import math
import random
import string
import time
from datetime import datetime, timedelta, timezone

from flask import Flask, request, jsonify

import firebase_admin
from firebase_admin import credentials, auth as admin_auth
from firebase_admin import firestore, messaging


# ---------------------------------------------------------------------------
# Init Firebase Admin SDK
# ---------------------------------------------------------------------------

if not firebase_admin._apps:
    # Cek file key di folder lokal dulu, jika tidak ada fallback ke path PythonAnywhere
    key_path = "firebase_key.json" if os.path.exists("firebase_key.json") else "/home/irmaaulia/firebase_key.json"
    cred = credentials.Certificate(key_path)
    firebase_admin.initialize_app(cred)

app = Flask(__name__)
db = firestore.client()

CRON_SECRET = "ganti-dengan-string-rahasia-kamu"


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _generate_pairing_code() -> str:
    return "".join(
        random.choices(string.digits, k=6)
    )


def _generate_password() -> str:
    return "".join(
        random.choices(
            string.ascii_letters + string.digits,
            k=16,
        )
    )


def verify_token():
    """
    Verifikasi Firebase ID Token dari Flutter.

    Header:
        Authorization: Bearer <ID_TOKEN>
    """
    auth_header = request.headers.get("Authorization", "")

    if not auth_header.startswith("Bearer "):
        print(
            "[verify_token] Tidak ada header Authorization Bearer"
        )
        return None

    token = auth_header.split("Bearer ", 1)[1]

    try:
        decoded = admin_auth.verify_id_token(token)
        uid = decoded["uid"]

        print(
            f"[verify_token] OK, uid={uid}"
        )

        return uid

    except Exception as e:
        print(
            f"[verify_token] GAGAL verifikasi token: {e}"
        )
        return None


def verify_wali_token():
    """
    Verifikasi token sekaligus memastikan user adalah wali.
    """
    uid = verify_token()

    if not uid:
        return None

    user_doc = (
        db.collection("users")
        .document(uid)
        .get()
    )

    if not user_doc.exists:
        print(
            f"[verify_wali_token] users/{uid} tidak ditemukan"
        )
        return None

    user_data = user_doc.to_dict()

    if user_data.get("role") != "wali":
        print(
            f"[verify_wali_token] uid={uid} bukan role wali"
        )
        return None

    return uid


def _find_wali_elderly_profile(wali_uid):
    """
    Mencari satu-satunya profil lansia milik wali.
    """
    query = (
        db.collection("elderly_profiles")
        .where(
            "waliIds",
            "array_contains",
            wali_uid,
        )
        .limit(1)
    )

    docs = list(query.stream())

    if not docs:
        return None

    return docs[0]


# ---------------------------------------------------------------------------
# Telemetry real-time helpers
# ---------------------------------------------------------------------------

# Data real-time masuk ~10x per detik. latest/current selalu ditulis,
# tetapi riwayat (readings / classifications) di-throttle agar kuota
# tulis Firestore tidak habis.
READINGS_MIN_INTERVAL_S = 5

# Penghitung langkah dari IMU (percepatan). Sesuaikan dengan satuan IMU:
# 0.3 cocok untuk satuan g; naikkan (mis. 3.0) bila satuannya m/s^2.
STEP_ACCEL_THRESHOLD = 0.3
MIN_STEP_INTERVAL_S = 0.3

WIB = timezone(timedelta(hours=7))

# State in-memory per proses (hilang saat web app di-reload; tidak masalah
# karena hanya dipakai untuk throttle dan deteksi puncak langkah).
_last_reading_at = {}
_last_activity = {}
_step_state = {}


def _num(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _should_store_history(device_id, now_s):
    last = _last_reading_at.get(device_id, 0)
    if now_s - last >= READINGS_MIN_INTERVAL_S:
        _last_reading_at[device_id] = now_s
        return True
    return False


def _count_steps(device_id, imu, sample_count, now_s):
    """
    Hitung langkah dari puncak magnitudo percepatan kaki kiri & kanan.
    Berjalan per sample sehingga cocok untuk data real-time.
    """
    steps = 0

    for side in ("left", "right"):
        side_imu = (imu or {}).get(side) or {}
        ax = side_imu.get("ax") or []
        ay = side_imu.get("ay") or []
        az = side_imu.get("az") or []

        state = _step_state.setdefault(
            (device_id, side),
            {"baseline": None, "above": False, "last_step": 0.0},
        )

        for i in range(min(sample_count, len(ax), len(ay), len(az))):
            mag = math.sqrt(
                _num(ax[i]) ** 2 + _num(ay[i]) ** 2 + _num(az[i]) ** 2
            )

            if state["baseline"] is None:
                state["baseline"] = mag

            # Baseline = rata-rata bergerak (gravitasi / offset sensor).
            state["baseline"] += 0.02 * (mag - state["baseline"])
            deviation = mag - state["baseline"]

            if deviation > STEP_ACCEL_THRESHOLD:
                if (
                    not state["above"]
                    and now_s - state["last_step"] >= MIN_STEP_INTERVAL_S
                ):
                    steps += 1
                    state["last_step"] = now_s
                state["above"] = True
            elif deviation < STEP_ACCEL_THRESHOLD * 0.5:
                state["above"] = False

    return steps


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

@app.route("/")
def health_check():
    return jsonify({
        "status": "ok",
        "service": "EMERYS backend (Flask/PythonAnywhere)",
    })


# ===========================================================================
# 1. GET PROFIL LANSIA MILIK WALI
# ===========================================================================
#
# Dipanggil ketika ProfilPage dibuka.
#
# Response:
#
# {
#   "exists": true,
#   "elderlyId": "...",
#   "name": "Bila",
#   "age": 70,
#   "healthNote": "Amnesia",
#   "deviceId": null
# }
#
# ===========================================================================

@app.route("/my-elderly-profile", methods=["GET"])
def my_elderly_profile():

    wali_uid = verify_wali_token()

    if not wali_uid:
        return jsonify({
            "detail": "Token tidak valid atau akun bukan wali."
        }), 401

    print(
        f"[my-elderly-profile] "
        f"Mencari profil untuk wali_uid={wali_uid}"
    )

    doc = _find_wali_elderly_profile(wali_uid)

    if not doc:
        print(
            "[my-elderly-profile] "
            "Tidak ditemukan profil lansia."
        )

        return jsonify({
            "exists": False
        })

    data = doc.to_dict()

    print(
        f"[my-elderly-profile] "
        f"Ditemukan: {doc.id} -> {data.get('name')}"
    )

    return jsonify({
        "exists": True,
        "elderlyId": doc.id,
        "name": data.get("name"),
        "age": data.get("age"),
        "healthNote": data.get("healthNote"),
        "deviceId": data.get("deviceId"),
    })


# ===========================================================================
# 2. BUAT PROFIL LANSIA
# ===========================================================================
#
# Dipanggil dari HP WALI ketika:
#
# Profil Lansia
#      ↓
# Tambah Profil Lansia
#      ↓
# Nama + Usia + Catatan
#      ↓
# Simpan
#
# PENTING:
# Endpoint ini HANYA membuat profil.
#
# Tidak membuat:
# - Firebase Auth elderly_device
# - pairing code
#
# deviceId tetap null.
#
# ===========================================================================

@app.route("/create-elderly-profile", methods=["POST"])
def create_elderly_profile():

    print("=" * 60)
    print("[create-elderly-profile] Request masuk")

    wali_uid = verify_wali_token()

    if not wali_uid:
        return jsonify({
            "detail": "Token tidak valid atau akun bukan wali."
        }), 401

    try:
        body = request.get_json(force=True) or {}

        name = (body.get("name") or "").strip()
        age = body.get("age")
        health_note = (
            body.get("healthNote") or ""
        ).strip()

        # ---------------------------------------------------------------
        # Validasi nama
        # ---------------------------------------------------------------

        if not name:
            return jsonify({
                "detail": "Nama lansia wajib diisi."
            }), 400

        # ---------------------------------------------------------------
        # Validasi usia
        # ---------------------------------------------------------------

        if age is None:
            return jsonify({
                "detail": "Usia lansia wajib diisi."
            }), 400

        try:
            age = int(age)
        except (TypeError, ValueError):
            return jsonify({
                "detail": "Usia harus berupa angka."
            }), 400

        if age < 1 or age > 150:
            return jsonify({
                "detail": "Usia tidak valid."
            }), 400

        # ---------------------------------------------------------------
        # Pastikan wali belum memiliki profil lansia
        # ---------------------------------------------------------------

        existing_doc = _find_wali_elderly_profile(wali_uid)

        if existing_doc:
            print(
                f"[create-elderly-profile] "
                f"Wali {wali_uid} sudah memiliki profil."
            )

            return jsonify({
                "detail": (
                    "Kamu sudah memiliki 1 profil lansia. "
                    "Hapus atau ubah profil tersebut terlebih dahulu."
                )
            }), 409

        # ---------------------------------------------------------------
        # Buat profil lansia
        # ---------------------------------------------------------------

        elderly_ref = (
            db.collection("elderly_profiles")
            .document()
        )

        elderly_ref.set({
            "name": name,
            "age": age,
            "healthNote": health_note,
            "waliIds": [wali_uid],

            # BELUM TERHUBUNG
            "deviceId": None,

            "createdAt": firestore.SERVER_TIMESTAMP,
        })

        print(
            f"[create-elderly-profile] "
            f"elderly_profiles/{elderly_ref.id} berhasil dibuat"
        )

        return jsonify({
            "success": True,
            "elderlyId": elderly_ref.id,
            "name": name,
            "age": age,
            "healthNote": health_note,
            "deviceId": None,
        }), 200

    except Exception as e:

        print(
            "[create-elderly-profile] "
            f"EXCEPTION: {type(e).__name__}: {e}"
        )

        return jsonify({
            "detail": f"Gagal membuat profil lansia: {str(e)}"
        }), 500


# ===========================================================================
# 3. GENERATE PAIRING CODE
# ===========================================================================
#
# Dipanggil ketika wali memilih:
#
# Profil Lansia
#      ↓
# Kelola Perangkat
#      ↓
# Generate Kode Setup
#
# Pada tahap INI baru dibuat akun Firebase elderly_device.
#
# ===========================================================================

@app.route("/generate-device-pairing", methods=["POST"])
def generate_device_pairing():

    print("=" * 60)
    print("[generate-device-pairing] Request masuk")

    wali_uid = verify_wali_token()

    if not wali_uid:
        return jsonify({
            "detail": "Token tidak valid atau akun bukan wali."
        }), 401

    try:
        body = request.get_json(force=True) or {}

        device_id = (
            body.get("deviceId") or ""
        ).strip()

        if not device_id:
            return jsonify({
                "detail": "Device ID wajib diisi."
            }), 400

        print(
            f"[generate-device-pairing] "
            f"deviceId yang diminta: {device_id}"
        )

        # ---------------------------------------------------------------
        # Cari profil lansia milik wali
        # ---------------------------------------------------------------

        elderly_doc = _find_wali_elderly_profile(wali_uid)

        if not elderly_doc:
            return jsonify({
                "detail": (
                    "Belum ada profil lansia. "
                    "Buat profil lansia terlebih dahulu."
                )
            }), 404

        elderly_data = elderly_doc.to_dict()
        elderly_id = elderly_doc.id

        # ---------------------------------------------------------------
        # Pastikan deviceId belum digunakan profil lain
        # ---------------------------------------------------------------

        existing_device_query = (
            db.collection("elderly_profiles")
            .where(
                "deviceId",
                "==",
                device_id,
            )
            .limit(1)
        )

        existing_device_docs = list(
            existing_device_query.stream()
        )

        if existing_device_docs:

            existing_device_doc = (
                existing_device_docs[0]
            )

            if existing_device_doc.id != elderly_id:
                return jsonify({
                    "detail": (
                        "Device ID tersebut sudah "
                        "terhubung dengan profil lansia lain."
                    )
                }), 409

        # ---------------------------------------------------------------
        # Jika sudah ada deviceId (lansia pernah login lalu logout),
        # reset: hapus akun Firebase lama + bersihkan deviceId
        # agar wali bisa generate kode baru.
        # ---------------------------------------------------------------

        existing_device_id = elderly_data.get("deviceId")

        if existing_device_id:
            print(
                "[generate-device-pairing] "
                f"deviceId={existing_device_id} sudah terisi. "
                "Melakukan reset: hapus akun lama dan bersihkan deviceId."
            )

            # Cari akun Firebase Auth lama berdasarkan email konvensional
            old_email = (
                f"device-{elderly_id}@emerys-internal.app"
            )

            try:
                old_user = admin_auth.get_user_by_email(old_email)

                # Hapus akun Firebase Auth lama
                admin_auth.delete_user(old_user.uid)

                # Hapus dokumen users/ lama
                db.collection("users").document(
                    old_user.uid
                ).delete()

                print(
                    "[generate-device-pairing] "
                    f"Akun lama {old_user.uid} berhasil dihapus."
                )

            except admin_auth.UserNotFoundError:
                # Akun lama sudah tidak ada, lanjutkan saja
                print(
                    "[generate-device-pairing] "
                    "Akun lama tidak ditemukan, lanjutkan reset."
                )
            except Exception as reset_error:
                print(
                    "[generate-device-pairing] "
                    f"Gagal hapus akun lama: {reset_error}"
                )

            # Bersihkan deviceId di elderly_profiles
            elderly_doc.reference.update({
                "deviceId": None,
            })

            # Hapus semua pairing code lama untuk elderly ini
            old_pairing_docs = list(
                db.collection("pairing_codes")
                .where("elderlyId", "==", elderly_id)
                .stream()
            )

            for old_code_doc in old_pairing_docs:
                old_code_doc.reference.delete()

            print(
                "[generate-device-pairing] "
                "Reset selesai. Lanjut buat akun dan kode baru."
            )

        # ---------------------------------------------------------------
        # Cek apakah masih ada pairing code aktif
        #
        # Ini mencegah wali menekan tombol berkali-kali dan membuat
        # banyak akun/device yang tidak perlu.
        # ---------------------------------------------------------------

        existing_pairing_query = (
            db.collection("pairing_codes")
            .where(
                "elderlyId",
                "==",
                elderly_id,
            )
        )

        existing_pairing_docs = list(
            existing_pairing_query.stream()
        )

        now = datetime.now(timezone.utc)

        for pairing_doc in existing_pairing_docs:

            pairing_data = pairing_doc.to_dict()

            # Kalau pairing code ini milik Device ID lain,
            # jangan digunakan.
            if pairing_data.get("deviceId") != device_id:
                continue

            expires_at = pairing_data.get(
                "expiresAt"
            )

            # Kalau pairing code untuk device yang sama
            # masih aktif, gunakan kembali.
            if expires_at and now < expires_at:

                print(
                    "[generate-device-pairing] "
                    "Masih ada pairing code aktif "
                    f"untuk device {device_id}."
                )

                return jsonify({
                    "success": True,
                    "pairingCode": pairing_doc.id,
                    "elderlyId": elderly_id,
                    "deviceId": device_id,
                    "expiresInMinutes": max(
                        1,
                        int(
                            (
                                expires_at - now
                            ).total_seconds() / 60
                        ),
                    ),
                }), 200

            # Kalau pairing code sudah expired,
            # hapus supaya tidak menumpuk.
            pairing_doc.reference.delete()

        # ---------------------------------------------------------------
        # Buat Firebase Auth account untuk device
        # ---------------------------------------------------------------

        generated_email = (
            f"device-{elderly_id}@emerys-internal.app"
        )

        generated_password = _generate_password()

        print(
            "[generate-device-pairing] "
            f"Membuat Firebase Auth user: {generated_email}"
        )

        new_user = admin_auth.create_user(
            email=generated_email,
            password=generated_password,
        )

        admin_auth.set_custom_user_claims(
            new_user.uid,
            {
                "role": "elderly_device"
            },
        )

        print(
            "[generate-device-pairing] "
            f"Auth user dibuat: {new_user.uid}"
        )

        # ---------------------------------------------------------------
        # Simpan user device
        # ---------------------------------------------------------------

        db.collection("users").document(
            new_user.uid
        ).set({
            "role": "elderly_device",
            "elderlyId": elderly_id,
            # ID hardware sandal
            "deviceId": device_id,
            "createdAt": firestore.SERVER_TIMESTAMP,
        })

        # ---------------------------------------------------------------
        # Buat pairing code sementara
        # ---------------------------------------------------------------

        code = _generate_pairing_code()

        expires_at = (
            now + timedelta(minutes=15)
        )

        db.collection("pairing_codes").document(
            code
        ).set({
            "email": generated_email,
            "password": generated_password,
            "elderlyId": elderly_id,
            # UID Firebase account device
            "deviceUid": new_user.uid,
            # ID hardware sandal
            "deviceId": device_id,
            "expiresAt": expires_at,
        })

        print(
            "[generate-device-pairing] "
            f"pairing_codes/{code} berhasil dibuat"
        )

        # ---------------------------------------------------------------
        # PERHATIAN:
        #
        # deviceId BELUM diisi di elderly_profiles.
        #
        # Karena baru generate kode belum berarti HP lansia
        # sudah benar-benar terhubung.
        #
        # deviceId baru diisi ketika redeem berhasil.
        # ---------------------------------------------------------------

        return jsonify({
            "success": True,
            "pairingCode": code,
            "elderlyId": elderly_id,
            "deviceId": device_id,
            "expiresInMinutes": 15,
        }), 200

    except Exception as e:

        print(
            "[generate-device-pairing] "
            f"EXCEPTION: {type(e).__name__}: {e}"
        )

        return jsonify({
            "detail": (
                f"Gagal membuat kode pairing: {str(e)}"
            )
        }), 500


# ===========================================================================
# 4. REDEEM PAIRING CODE
# ===========================================================================
#
# Dipanggil dari HP LANSIA.
#
# Jika kode valid:
#
# pairing_codes/{code}
#        ↓
# ambil credential
#        ↓
# update elderly_profiles.deviceId
#        ↓
# hapus pairing_codes/{code}
#        ↓
# return email + password
#
# Dengan begitu deviceId baru terisi SETELAH pairing berhasil.
#
# ===========================================================================

@app.route("/redeem-pairing-code", methods=["POST"])
def redeem_pairing_code():

    print("=" * 60)
    print("[redeem-pairing-code] Request masuk")

    try:

        body = request.get_json(force=True) or {}

        code = (
            body.get("code") or ""
        ).strip()

        print(
            f"[redeem-pairing-code] "
            f"Mencoba redeem kode: {code}"
        )

        if not code:
            return jsonify({
                "detail": "Kode wajib diisi."
            }), 400

        if len(code) != 6 or not code.isdigit():
            return jsonify({
                "detail": "Kode harus terdiri dari 6 digit."
            }), 400

        # ---------------------------------------------------------------
        # Ambil pairing code
        # ---------------------------------------------------------------

        doc_ref = (
            db.collection("pairing_codes")
            .document(code)
        )

        doc = doc_ref.get()

        if not doc.exists:

            print(
                "[redeem-pairing-code] "
                f"Kode {code} tidak ditemukan."
            )

            return jsonify({
                "detail": (
                    "Kode tidak ditemukan atau sudah dipakai."
                )
            }), 404

        data = doc.to_dict()

        expires_at = data.get("expiresAt")

        if not expires_at:

            doc_ref.delete()

            return jsonify({
                "detail": "Kode pairing tidak valid."
            }), 400

        # ---------------------------------------------------------------
        # Cek expired
        # ---------------------------------------------------------------

        now = datetime.now(timezone.utc)

        if now > expires_at:

            print(
                f"[redeem-pairing-code] "
                f"Kode {code} sudah kadaluarsa."
            )

            # Ambil device UID sebelum dokumen dihapus.
            device_uid = data.get("deviceUid")

            # Hapus pairing code.
            doc_ref.delete()

            # Jika akun device dibuat tetapi tidak pernah dipakai,
            # hapus juga akun Firebase agar tidak menjadi akun yatim.
            if device_uid:
                try:
                    admin_auth.delete_user(
                        device_uid
                    )

                    db.collection("users").document(
                        device_uid
                    ).delete()

                    print(
                        "[redeem-pairing-code] "
                        f"Akun device {device_uid} "
                        "yang expired ikut dihapus."
                    )

                except Exception as cleanup_error:
                    print(
                        "[redeem-pairing-code] "
                        "Gagal cleanup device: "
                        f"{cleanup_error}"
                    )

            return jsonify({
                "detail": "Kode sudah kadaluarsa."
            }), 410

        # ---------------------------------------------------------------
        # Ambil data pairing
        # ---------------------------------------------------------------

        email = data.get("email")
        password = data.get("password")
        elderly_id = data.get("elderlyId")
        device_uid = data.get("deviceUid")
        device_id = data.get("deviceId")

        if (not email or not password or not elderly_id or not device_uid or not device_id):
            doc_ref.delete()
            return jsonify({
                "detail": "Data pairing tidak lengkap."
            }), 500

        # ---------------------------------------------------------------
        # Pastikan profil lansia masih ada
        # ---------------------------------------------------------------

        elderly_ref = (
            db.collection("elderly_profiles")
            .document(elderly_id)
        )

        elderly_doc = elderly_ref.get()

        if not elderly_doc.exists:

            doc_ref.delete()

            try:
                admin_auth.delete_user(
                    device_uid
                )
            except Exception:
                pass

            db.collection("users").document(
                device_uid
            ).delete()

            return jsonify({
                "detail": "Profil lansia tidak ditemukan."
            }), 404

        # ---------------------------------------------------------------
        # Pastikan belum ada device yang terhubung
        # ---------------------------------------------------------------

        elderly_data = elderly_doc.to_dict()

        if elderly_data.get("deviceId"):
            doc_ref.delete()
            try:
                admin_auth.delete_user(
                    device_uid
                )
            except Exception as cleanup_error:
                print(
                    "[redeem-pairing-code] "
                    "Gagal menghapus akun device: "
                    f"{cleanup_error}"
                )
            db.collection("users").document(
                device_uid
            ).delete()

            return jsonify({
                "detail": "Profil lansia sudah memiliki perangkat."
            }), 409

        # ---------------------------------------------------------------
        # Tandai device sebagai perangkat yang terhubung
        # ---------------------------------------------------------------

        elderly_ref.update({
            "deviceId": device_id,
        })

        print(
            "[redeem-pairing-code] "
            f"elderly_profiles/{elderly_id} "
            f"deviceId -> {device_id}"
        )

        # ---------------------------------------------------------------
        # Hapus pairing code setelah berhasil digunakan
        # ---------------------------------------------------------------

        doc_ref.delete()

        print(
            "[redeem-pairing-code] "
            f"Kode {code} berhasil di-redeem dan dihapus."
        )

        return jsonify({
            "success": True,
            "email": email,
            "password": password,
            "elderlyId": elderly_id,
            "deviceId": device_id,
        }), 200

    except Exception as e:

        print(
            "[redeem-pairing-code] "
            f"EXCEPTION: {type(e).__name__}: {e}"
        )

        return jsonify({
            "detail": (
                f"Gagal memproses kode pairing: {str(e)}"
            )
        }), 500

# ===========================================================================
# 5. TELEMETRY
# ===========================================================================
#
# Dipanggil dari HP LANSIA setelah Flutter menerima data BLE.
#
# Alur:
#
# ESP32
#   ↓ BLE
# Flutter
#   ↓ kirim setiap sample (real-time, sampleCount = 1)
# POST /telemetry
#   ↓
# Firestore
#
# Struktur Firestore:
#
# device_telemetry/{deviceId}
#     ├── latest/current            (diperbarui di setiap request)
#     ├── readings/{windowId}       (di-throttle, lihat READINGS_MIN_INTERVAL_S)
#     ├── classifications/{id}      (saat activity berubah / di-throttle)
#     └── daily_steps/{YYYY-MM-DD}  (jumlah langkah per hari, dari IMU)
#
# Sensor FSR sudah tidak dipakai. Hanya IMU, GPS, battery, dan TinyML.
#
# ===========================================================================

@app.route("/telemetry", methods=["POST"])
def receive_telemetry():

    print("=" * 60)
    print("[telemetry] Request masuk")

    # ---------------------------------------------------------------
    # 1. Verifikasi Firebase ID Token
    # ---------------------------------------------------------------

    device_uid = verify_token()

    if not device_uid:
        return jsonify({
            "detail": "Token tidak valid."
        }), 401

    print(
        f"[telemetry] deviceUid={device_uid}"
    )

    # ---------------------------------------------------------------
    # 2. Ambil data user device
    # ---------------------------------------------------------------

    user_ref = (
        db.collection("users")
        .document(device_uid)
    )

    user_doc = user_ref.get()

    if not user_doc.exists:

        print(
            "[telemetry] "
            f"users/{device_uid} tidak ditemukan."
        )

        return jsonify({
            "detail": "Akun perangkat tidak ditemukan."
        }), 404

    user_data = user_doc.to_dict()

    # ---------------------------------------------------------------
    # 3. Pastikan akun adalah elderly_device
    # ---------------------------------------------------------------

    if user_data.get("role") != "elderly_device":

        print(
            "[telemetry] "
            f"uid={device_uid} bukan elderly_device."
        )

        return jsonify({
            "detail": "Akun ini bukan perangkat lansia."
        }), 403

    # ---------------------------------------------------------------
    # 4. Ambil identity
    #
    # device_uid = Firebase Auth UID
    # device_id  = ID fisik sandal EMERYS
    # elderly_id = ID profil lansia
    # ---------------------------------------------------------------

    elderly_id = user_data.get(
        "elderlyId"
    )

    device_id = user_data.get(
        "deviceId"
    )

    if not elderly_id:

        return jsonify({
            "detail": (
                "Akun perangkat belum memiliki elderlyId."
            )
        }), 400

    if not device_id:

        return jsonify({
            "detail": (
                "Akun perangkat belum memiliki deviceId."
            )
        }), 400

    print(
        "[telemetry] "
        f"elderlyId={elderly_id}, "
        f"deviceId={device_id}"
    )

    # ---------------------------------------------------------------
    # 5. Ambil body JSON
    # ---------------------------------------------------------------

    body = request.get_json(
        force=True
    ) or {}

    body_device_id = (
        body.get("deviceId") or ""
    ).strip()

    window = body.get(
        "window"
    )

    tinyml = body.get(
        "tinyml"
    )

    # ---------------------------------------------------------------
    # 6. Validasi deviceId
    #
    # Jangan sampai device A mengirim telemetry
    # dengan deviceId device B.
    # ---------------------------------------------------------------

    if not body_device_id:

        return jsonify({
            "detail": "deviceId wajib diisi."
        }), 400

    if body_device_id != device_id:

        print(
            "[telemetry] "
            f"Device ID mismatch: "
            f"token={device_id}, "
            f"body={body_device_id}"
        )

        return jsonify({
            "detail": (
                "Device ID tidak sesuai "
                "dengan akun perangkat."
            )
        }), 403

    # ---------------------------------------------------------------
    # 7. Validasi window
    # ---------------------------------------------------------------

    if not isinstance(
        window,
        dict,
    ):

        return jsonify({
            "detail": "Field window wajib berupa object."
        }), 400

    sample_rate = window.get(
        "sampleRate"
    )

    sample_count = window.get(
        "sampleCount"
    )

    sequence_start = window.get(
        "sequenceStart"
    )

    sequence_end = window.get(
        "sequenceEnd"
    )

    start_timestamp = window.get(
        "startTimestamp"
    )

    end_timestamp = window.get(
        "endTimestamp"
    )

    # ---------------------------------------------------------------
    # 8. Validasi metadata window
    # ---------------------------------------------------------------

    if sample_rate is None:

        return jsonify({
            "detail": "window.sampleRate wajib diisi."
        }), 400

    if sample_count is None:

        return jsonify({
            "detail": "window.sampleCount wajib diisi."
        }), 400

    try:

        sample_rate = int(
            sample_rate
        )

        sample_count = int(
            sample_count
        )

    except (
        TypeError,
        ValueError,
    ):

        return jsonify({
            "detail": (
                "sampleRate dan sampleCount "
                "harus berupa angka."
            )
        }), 400

    if sample_rate <= 0:

        return jsonify({
            "detail": "sampleRate harus lebih dari 0."
        }), 400

    if sample_count <= 0:

        return jsonify({
            "detail": "sampleCount harus lebih dari 0."
        }), 400

    # ---------------------------------------------------------------
    # 9. Ambil data sensor
    # ---------------------------------------------------------------

    imu = window.get(
        "imu",
        {}
    )

    gps = window.get(
        "gps"
    )

    battery = window.get(
        "battery"
    )

    # ---------------------------------------------------------------
    # 10. Validasi IMU
    #
    # Untuk window penelitian, setiap channel IMU
    # seharusnya memiliki sampleCount yang sama.
    # ---------------------------------------------------------------

    def _validate_array(
        parent,
        side,
        field,
        expected_count,
    ):

        side_data = parent.get(
            side
        )

        if not isinstance(
            side_data,
            dict,
        ):

            return False

        values = side_data.get(
            field
        )

        if not isinstance(
            values,
            list,
        ):

            return False

        if len(values) != expected_count:

            return False

        return True

    imu_fields = [
        "ax",
        "ay",
        "az",
        "gx",
        "gy",
        "gz",
    ]

    for side in [
        "left",
        "right",
    ]:

        for field in imu_fields:

            if not _validate_array(
                imu,
                side,
                field,
                sample_count,
            ):

                return jsonify({
                    "detail": (
                        f"IMU {side}.{field} "
                        f"harus memiliki "
                        f"{sample_count} sample."
                    )
                }), 400

    # ---------------------------------------------------------------
    # 12. Validasi sequence
    # ---------------------------------------------------------------

    if sequence_start is None:

        return jsonify({
            "detail": (
                "window.sequenceStart "
                "wajib diisi."
            )
        }), 400

    if sequence_end is None:

        return jsonify({
            "detail": (
                "window.sequenceEnd "
                "wajib diisi."
            )
        }), 400

    try:

        sequence_start = int(
            sequence_start
        )

        sequence_end = int(
            sequence_end
        )

    except (
        TypeError,
        ValueError,
    ):

        return jsonify({
            "detail": (
                "sequenceStart dan sequenceEnd "
                "harus berupa angka."
            )
        }), 400

    # ---------------------------------------------------------------
    # 13. Pastikan jumlah sequence masuk akal
    #
    # Contoh:
    #
    # 15200 -> 15249
    #
    # berarti 50 sample.
    #
    # ---------------------------------------------------------------

    expected_sequence_count = (
        sequence_end
        - sequence_start
        + 1
    )

    if expected_sequence_count != sample_count:

        return jsonify({
            "detail": (
                "Rentang sequence tidak sesuai "
                "dengan sampleCount."
            )
        }), 400

    # ---------------------------------------------------------------
    # 14. Pastikan timestamp window tersedia
    # ---------------------------------------------------------------

    if start_timestamp is None:

        return jsonify({
            "detail": (
                "window.startTimestamp "
                "wajib diisi."
            )
        }), 400

    if end_timestamp is None:

        return jsonify({
            "detail": (
                "window.endTimestamp "
                "wajib diisi."
            )
        }), 400

    # ---------------------------------------------------------------
    # 15. Pastikan profil lansia masih ada
    # ---------------------------------------------------------------

    elderly_ref = (
        db.collection("elderly_profiles")
        .document(elderly_id)
    )

    elderly_doc = elderly_ref.get()

    if not elderly_doc.exists:

        print(
            "[telemetry] "
            f"Profil {elderly_id} tidak ditemukan."
        )

        return jsonify({
            "detail": (
                "Profil lansia tidak ditemukan."
            )
        }), 404

    elderly_data = (
        elderly_doc.to_dict()
    )

    # ---------------------------------------------------------------
    # 16. Pastikan deviceId pada profil sama
    # ---------------------------------------------------------------

    profile_device_id = (
        elderly_data.get(
            "deviceId"
        )
    )

    if profile_device_id != device_id:

        print(
            "[telemetry] "
            "Device ID profil tidak sesuai."
        )

        return jsonify({
            "detail": (
                "Perangkat belum terhubung "
                "ke profil lansia."
            )
        }), 403

    # ---------------------------------------------------------------
    # 17. Referensi utama device telemetry
    # ---------------------------------------------------------------

    device_ref = (
        db.collection("device_telemetry")
        .document(device_id)
    )

    # ---------------------------------------------------------------
    # 18. Simpan metadata device
    # ---------------------------------------------------------------

    device_ref.set({
        "elderlyId": elderly_id,
        "deviceUid": device_uid,
        "deviceId": device_id,
        "updatedAt": (
            firestore.SERVER_TIMESTAMP
        ),
    }, merge=True)

    # ---------------------------------------------------------------
    # 19. Simpan latest/current
    #
    # latest/current adalah kondisi terbaru perangkat.
    # Ini yang akan dipakai aplikasi wali untuk monitoring.
    # ---------------------------------------------------------------

    latest_ref = (
        device_ref
        .collection("latest")
        .document("current")
    )

    latest_data = {
        "deviceId": device_id,
        "elderlyId": elderly_id,

        "deviceUid": device_uid,

        "status": "online",

        "lastSeen": (
            firestore.SERVER_TIMESTAMP
        ),

        "updatedAt": (
            firestore.SERVER_TIMESTAMP
        ),

        "sequence": sequence_end,

        "timestamp": end_timestamp,

        "imu": imu,

        "gps": gps,

        "battery": battery,
    }

    # TinyML hanya dimasukkan jika tersedia.
    if isinstance(
        tinyml,
        dict,
    ):

        latest_data["tinyml"] = tinyml

    latest_ref.set(
        latest_data,
        merge=True,
    )

    print(
        "[telemetry] "
        f"latest/current diperbarui "
        f"untuk {device_id}"
    )

    # ---------------------------------------------------------------
    # 20. Simpan riwayat window (di-throttle)
    #
    # readings/{windowId}
    #
    # Karena data dikirim real-time (satu sample per request),
    # riwayat hanya disimpan setiap READINGS_MIN_INTERVAL_S detik.
    # ---------------------------------------------------------------

    now_s = time.time()

    store_history = _should_store_history(
        device_id,
        now_s,
    )

    window_ref = (
        device_ref
        .collection("readings")
        .document()
    )

    window_data = {
        "deviceId": device_id,

        "elderlyId": elderly_id,

        "deviceUid": device_uid,

        "receivedAt": (
            firestore.SERVER_TIMESTAMP
        ),

        "window": {
            "sampleRate": sample_rate,
            "sampleCount": sample_count,

            "startTimestamp": start_timestamp,
            "endTimestamp": end_timestamp,

            "sequenceStart": sequence_start,
            "sequenceEnd": sequence_end,

            "imu": imu,

            "gps": gps,

            "battery": battery,
        },
    }

    if isinstance(
        tinyml,
        dict,
    ):

        window_data["tinyml"] = tinyml

    window_id = None

    if store_history:

        window_ref.set(
            window_data
        )

        window_id = window_ref.id

        print(
            "[telemetry] "
            f"readings/{window_ref.id} "
            "berhasil disimpan."
        )

    # ---------------------------------------------------------------
    # 20b. Hitung langkah harian dari IMU
    #
    # daily_steps/{YYYY-MM-DD}.steps
    # ---------------------------------------------------------------

    try:

        new_steps = _count_steps(
            device_id,
            imu,
            sample_count,
            now_s,
        )

        if new_steps > 0:

            date_key = datetime.now(WIB).strftime("%Y-%m-%d")

            device_ref.collection("daily_steps").document(
                date_key
            ).set({
                "deviceId": device_id,
                "elderlyId": elderly_id,
                "date": date_key,
                "steps": firestore.Increment(new_steps),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }, merge=True)

    except Exception as e:

        print(
            "[telemetry] "
            f"Gagal menghitung langkah: {e}"
        )

    # ---------------------------------------------------------------
    # 21. Simpan TinyML classification
    #
    # Hanya dibuat jika Flutter/ESP32 mengirim hasil TinyML.
    #
    # ---------------------------------------------------------------

    classification_id = None

    activity_now = (
        tinyml.get("activity")
        if isinstance(tinyml, dict)
        else None
    )

    # Simpan klasifikasi hanya saat activity berubah
    # atau saat riwayat di-throttle ikut disimpan.
    store_classification = (
        isinstance(tinyml, dict)
        and (
            store_history
            or _last_activity.get(device_id) != activity_now
        )
    )

    _last_activity[device_id] = activity_now

    if store_classification:

        classification_ref = (
            device_ref
            .collection("classifications")
            .document()
        )

        classification_ref.set({
            "deviceId": device_id,

            "elderlyId": elderly_id,

            "deviceUid": device_uid,

            "activity": tinyml.get(
                "activity"
            ),

            "stability": tinyml.get(
                "stability"
            ),

            "fallRisk": tinyml.get(
                "fallRisk"
            ),

            "confidence": tinyml.get(
                "confidence"
            ),

            "modelVersion": tinyml.get(
                "modelVersion"
            ),

            "sequenceStart": sequence_start,

            "sequenceEnd": sequence_end,

            "timestamp": (
                firestore.SERVER_TIMESTAMP
            ),

        })

        classification_id = (
            classification_ref.id
        )

        print(
            "[telemetry] "
            f"classifications/{classification_id} "
            "berhasil disimpan."
        )

    # ---------------------------------------------------------------
    # 22. Response
    # ---------------------------------------------------------------

    print(
        "[telemetry] "
        f"SUCCESS device={device_id}, "
        f"samples={sample_count}, "
        f"sequence={sequence_start}-{sequence_end}"
    )

    return jsonify({
        "success": True,

        "deviceId": device_id,

        "elderlyId": elderly_id,

        "sampleCount": sample_count,

        "sequenceStart": sequence_start,

        "sequenceEnd": sequence_end,

        "windowId": window_id,

        "classificationId": classification_id,

    }), 200

# ===========================================================================
# 5. FALL EVENT
# ===========================================================================
#
# Tetap menggunakan mekanisme sebelumnya.
#
# ===========================================================================

@app.route("/fall-event", methods=["POST"])
def create_fall_event():

    print("=" * 60)
    print("[fall-event] Request masuk")

    # ---------------------------------------------------------------
    # Verifikasi Firebase ID Token
    # ---------------------------------------------------------------

    device_uid = verify_token()

    if not device_uid:
        return jsonify({
            "detail": "Token tidak valid."
        }), 401

    print(
        f"[fall-event] deviceUid={device_uid}"
    )

    # ---------------------------------------------------------------
    # Ambil data user device
    # ---------------------------------------------------------------

    user_ref = (
        db.collection("users")
        .document(device_uid)
    )

    user_doc = user_ref.get()

    if not user_doc.exists:

        print(
            "[fall-event] "
            f"users/{device_uid} tidak ditemukan."
        )

        return jsonify({
            "detail": "Akun perangkat tidak ditemukan."
        }), 404

    user_data = user_doc.to_dict()

    # ---------------------------------------------------------------
    # Pastikan akun adalah elderly_device
    # ---------------------------------------------------------------

    if user_data.get("role") != "elderly_device":

        print(
            "[fall-event] "
            f"uid={device_uid} bukan elderly_device."
        )

        return jsonify({
            "detail": "Akun ini bukan perangkat lansia."
        }), 403

    # ---------------------------------------------------------------
    # Ambil identity device
    #
    # device_uid = Firebase Auth UID
    # device_id  = ID fisik sandal
    # ---------------------------------------------------------------

    elderly_id = user_data.get(
        "elderlyId"
    )

    device_id = user_data.get(
        "deviceId"
    )

    if not elderly_id:
        return jsonify({
            "detail": (
                "Akun perangkat belum memiliki "
                "elderlyId."
            )
        }), 400

    if not device_id:
        return jsonify({
            "detail": (
                "Akun perangkat belum memiliki "
                "deviceId."
            )
        }), 400

    print(
        "[fall-event] "
        f"elderlyId={elderly_id}, "
        f"deviceId={device_id}"
    )

    # ---------------------------------------------------------------
    # Ambil data request
    # ---------------------------------------------------------------

    body = request.get_json(force=True) or {}

    severity = body.get(
        "severity",
        "medium",
    )

    latitude = body.get(
        "latitude"
    )

    longitude = body.get(
        "longitude"
    )

    # ---------------------------------------------------------------
    # Validasi severity
    # ---------------------------------------------------------------

    allowed_severity = {
        "low",
        "medium",
        "high",
        "manual",
    }

    if severity not in allowed_severity:

        return jsonify({
            "detail": (
                "Severity tidak valid. "
                "Gunakan low, medium, high, "
                "atau manual."
            )
        }), 400

    # ---------------------------------------------------------------
    # Pastikan profil lansia masih ada
    # ---------------------------------------------------------------

    elderly_ref = (
        db.collection("elderly_profiles")
        .document(elderly_id)
    )

    elderly_doc = elderly_ref.get()

    if not elderly_doc.exists:

        print(
            "[fall-event] "
            f"Profil {elderly_id} tidak ditemukan."
        )

        return jsonify({
            "detail": "Profil lansia tidak ditemukan."
        }), 404

    elderly_data = elderly_doc.to_dict()

    elderly_name = elderly_data.get(
        "name",
        "Lansia",
    )

    wali_ids = elderly_data.get(
        "waliIds",
        [],
    )

    # ---------------------------------------------------------------
    # Buat GeoPoint jika koordinat tersedia
    # ---------------------------------------------------------------

    location = None

    if (
        latitude is not None
        and longitude is not None
    ):

        try:

            latitude = float(latitude)
            longitude = float(longitude)

        except (TypeError, ValueError):

            return jsonify({
                "detail": (
                    "Latitude dan longitude "
                    "harus berupa angka."
                )
            }), 400

        # Validasi rentang koordinat

        if not -90 <= latitude <= 90:

            return jsonify({
                "detail": "Latitude tidak valid."
            }), 400

        if not -180 <= longitude <= 180:

            return jsonify({
                "detail": "Longitude tidak valid."
            }), 400

        location = firestore.GeoPoint(
            latitude,
            longitude,
        )

    # ---------------------------------------------------------------
    # Buat fall event
    # ---------------------------------------------------------------

    event_ref = (
        db.collection("fall_events")
        .document()
    )

    event_ref.set({
        "elderlyId": elderly_id,

        # ID FISIK sandal EMERYS
        "deviceId": device_id,

        # Firebase Auth UID disimpan terpisah
        # untuk kebutuhan audit/debugging.
        "deviceUid": device_uid,

        "timestamp": (
            firestore.SERVER_TIMESTAMP
        ),

        "location": location,

        "severity": severity,

        "acknowledged": False,
    })

    print(
        "[fall-event] "
        f"fall_events/{event_ref.id} berhasil dibuat."
    )

    # ---------------------------------------------------------------
    # Buat notifikasi untuk setiap wali
    # ---------------------------------------------------------------

    for wali_id in wali_ids:

        wali_doc = (
            db.collection("users")
            .document(wali_id)
            .get()
        )

        if not wali_doc.exists:
            continue

        wali_data = wali_doc.to_dict()

        fcm_token = wali_data.get(
            "fcmToken"
        )

        # -----------------------------------------------------------
        # Simpan notifikasi ke Firestore
        # -----------------------------------------------------------

        db.collection("notifications").add({
            "waliId": wali_id,

            "type": "fall_alert",

            "relatedEventId": event_ref.id,

            "message": (
                f"Terdeteksi kemungkinan "
                f"{elderly_name} jatuh! "
                "Segera cek."
            ),

            "read": False,

            "createdAt": (
                firestore.SERVER_TIMESTAMP
            ),
        })

        # -----------------------------------------------------------
        # Kirim push notification melalui FCM
        # -----------------------------------------------------------

        if fcm_token:

            try:

                messaging.send(
                    messaging.Message(
                        token=fcm_token,

                        notification=(
                            messaging.Notification(
                                title="⚠️ Peringatan Jatuh",

                                body=(
                                    f"{elderly_name} "
                                    "kemungkinan jatuh. "
                                    "Ketuk untuk cek lokasi."
                                ),
                            )
                        ),

                        data={
                            "type": "fall_alert",
                            "elderlyId": elderly_id,
                            "eventId": event_ref.id,
                            "deviceId": device_id,
                        },

                        android=(
                            messaging.AndroidConfig(
                                priority="high"
                            )
                        ),
                    )
                )

                print(
                    "[fall-event] "
                    f"FCM berhasil dikirim ke wali "
                    f"{wali_id}."
                )

            except Exception as e:

                print(
                    "[fall-event] "
                    f"Gagal kirim FCM ke "
                    f"{wali_id}: {e}"
                )

    # ---------------------------------------------------------------
    # Response
    # ---------------------------------------------------------------

    return jsonify({
        "success": True,
        "eventId": event_ref.id,
        "elderlyId": elderly_id,
        "deviceId": device_id,
    }), 200


# ===========================================================================
# 6. DEVICE OFFLINE CHECK
# ===========================================================================
#
# Tetap menggunakan mekanisme sebelumnya.
#
# ===========================================================================

@app.route("/check-device-offline")
def check_device_offline():

    print("=" * 60)
    print("[check-device-offline] Request masuk")

    # ---------------------------------------------------------------
    # Verifikasi secret untuk cron
    # ---------------------------------------------------------------

    secret = request.args.get(
        "secret",
        "",
    )

    if secret != CRON_SECRET:

        print(
            "[check-device-offline] "
            "Secret tidak valid."
        )

        return jsonify({
            "detail": "Forbidden"
        }), 403

    # ---------------------------------------------------------------
    # Tentukan batas waktu offline
    #
    # Jika lastSeen lebih lama dari 2 jam,
    # perangkat dianggap offline.
    # ---------------------------------------------------------------

    threshold = (
        datetime.now(timezone.utc)
        - timedelta(hours=2)
    )

    print(
        "[check-device-offline] "
        f"Threshold: {threshold}"
    )

    # ---------------------------------------------------------------
    # Ambil semua device telemetry
    #
    # Struktur:
    #
    # device_telemetry/{deviceId}
    # ---------------------------------------------------------------

    device_docs = (
        db.collection("device_telemetry")
        .stream()
    )

    flagged = 0
    checked = 0

    for device_doc in device_docs:

        checked += 1

        device_id = device_doc.id
        device_data = device_doc.to_dict()

        elderly_id = device_data.get(
            "elderlyId"
        )

        # -----------------------------------------------------------
        # Ambil latest/current
        # -----------------------------------------------------------

        latest_ref = (
            db.collection("device_telemetry")
            .document(device_id)
            .collection("latest")
            .document("current")
        )

        latest_doc = latest_ref.get()

        if not latest_doc.exists:

            print(
                "[check-device-offline] "
                f"{device_id} belum memiliki latest/current."
            )

            continue

        latest_data = latest_doc.to_dict()

        last_seen = latest_data.get(
            "lastSeen"
        )

        current_status = latest_data.get(
            "status",
            "unknown",
        )

        # -----------------------------------------------------------
        # Tidak ada lastSeen
        # -----------------------------------------------------------

        if not last_seen:

            print(
                "[check-device-offline] "
                f"{device_id} tidak memiliki lastSeen."
            )

            continue

        # -----------------------------------------------------------
        # Pastikan lastSeen berupa datetime
        # -----------------------------------------------------------

        if not isinstance(
            last_seen,
            datetime,
        ):

            print(
                "[check-device-offline] "
                f"lastSeen {device_id} "
                "bukan datetime."
            )

            continue

        # -----------------------------------------------------------
        # Kalau masih aktif, tidak perlu melakukan apa-apa.
        # -----------------------------------------------------------

        if last_seen >= threshold:

            # Jika sebelumnya inactive tetapi sekarang
            # sudah kembali mengirim data, tandai online.
            if current_status == "inactive":

                latest_ref.update({
                    "status": "online",
                })

                print(
                    "[check-device-offline] "
                    f"{device_id} kembali online."
                )

            continue

        # -----------------------------------------------------------
        # Device sudah lebih dari 2 jam tidak mengirim data.
        # -----------------------------------------------------------

        if current_status == "inactive":

            # Sudah pernah ditandai offline.
            # Jangan membuat notifikasi berulang.
            continue

        # -----------------------------------------------------------
        # Tandai device sebagai inactive
        # -----------------------------------------------------------

        latest_ref.update({
            "status": "inactive",
        })

        flagged += 1

        print(
            "[check-device-offline] "
            f"{device_id} ditandai OFFLINE."
        )

        # -----------------------------------------------------------
        # Pastikan elderlyId tersedia
        # -----------------------------------------------------------

        if not elderly_id:

            print(
                "[check-device-offline] "
                f"{device_id} tidak memiliki elderlyId."
            )

            continue

        # -----------------------------------------------------------
        # Ambil profil lansia
        # -----------------------------------------------------------

        elderly_doc = (
            db.collection("elderly_profiles")
            .document(elderly_id)
            .get()
        )

        if not elderly_doc.exists:

            print(
                "[check-device-offline] "
                f"Profil {elderly_id} tidak ditemukan."
            )

            continue

        elderly_data = (
            elderly_doc.to_dict()
        )

        elderly_name = elderly_data.get(
            "name",
            "Lansia",
        )

        # -----------------------------------------------------------
        # Buat notifikasi untuk setiap wali
        # -----------------------------------------------------------

        for wali_id in elderly_data.get(
            "waliIds",
            [],
        ):

            db.collection("notifications").add({
                "waliId": wali_id,
                "type": "device_offline",
                "elderlyId": elderly_id,
                "deviceId": device_id,
                "message": (
                    f"Sandal {elderly_name} "
                    "tidak mengirim data lebih dari "
                    "2 jam. Cek koneksi atau baterai."
                ),
                "read": False,
                "createdAt": (
                    firestore.SERVER_TIMESTAMP
                ),
            })

            print(
                "[check-device-offline] "
                f"Notifikasi offline dibuat "
                f"untuk wali {wali_id}."
            )

    # ---------------------------------------------------------------
    # Response
    # ---------------------------------------------------------------

    return jsonify({
        "checked": True,
        "checkedDevices": checked,
        "flaggedOffline": flagged,
    }), 200


# ---------------------------------------------------------------------------
# Local development
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    # Jalankan server lokal multi-threaded di port 5000
    app.run(host="0.0.0.0", port=5000, debug=True, threaded=True)

