"""
Patch untuk backend PythonAnywhere (pytonanywhere.txt) -- hitung langkah per hari.

Cara pasang:
1. Salin helper `_count_steps` + `_add_daily_steps` ke atas route /telemetry.
2. Di `receive_telemetry`, tepat setelah `latest_ref.set(latest_data, merge=True)`
   (langkah 19), tambahkan:

       _add_daily_steps(device_ref, fsr, sample_rate, device_id, elderly_id)

3. Reload web app di PythonAnywhere.

Hasil di Firestore (dibaca halaman Pantau):
    device_telemetry/{deviceId}/daily_steps/{YYYY-MM-DD}  ->  {steps, date, updatedAt}

Tanggal memakai WIB (UTC+7). Sesuaikan FSR_MIN_AMPLITUDE dengan skala ADC FSR
sandal kamu (default 200 untuk ADC 12-bit).
"""
from datetime import datetime, timedelta, timezone

from firebase_admin import firestore

WIB = timezone(timedelta(hours=7))
FSR_MIN_AMPLITUDE = 200      # selisih max-min minimum agar dianggap ada injakan
MIN_STEP_INTERVAL_S = 0.3    # jeda minimum antar langkah satu kaki (detik)


def _num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def _count_steps(fsr, sample_rate):
    """Hitung langkah dari rising-edge jumlah tekanan FSR tiap kaki."""
    min_gap = max(1, int(MIN_STEP_INTERVAL_S * sample_rate))
    total = 0

    for side in ("left", "right"):
        side_data = (fsr or {}).get(side) or {}
        channels = [
            side_data.get(k) or []
            for k in ("rfront", "rback", "lfront", "lback")
        ]
        n = min((len(c) for c in channels), default=0)
        if n < 2:
            continue

        sig = [sum(_num(c[i]) for c in channels) for i in range(n)]
        lo, hi = min(sig), max(sig)
        if hi - lo < FSR_MIN_AMPLITUDE:
            continue

        threshold = lo + 0.5 * (hi - lo)
        last_edge = -min_gap
        for i in range(1, n):
            if sig[i - 1] < threshold <= sig[i] and i - last_edge >= min_gap:
                total += 1
                last_edge = i

    return total


def _add_daily_steps(device_ref, fsr, sample_rate, device_id, elderly_id):
    steps = _count_steps(fsr, sample_rate)
    if steps <= 0:
        return 0

    date_key = datetime.now(WIB).strftime("%Y-%m-%d")
    device_ref.collection("daily_steps").document(date_key).set({
        "deviceId": device_id,
        "elderlyId": elderly_id,
        "date": date_key,
        "steps": firestore.Increment(steps),
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }, merge=True)
    return steps
