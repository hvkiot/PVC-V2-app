#!/usr/bin/python3

import serial
import time

# -------------------------------------------------
# CONFIGURATION
# -------------------------------------------------
PAM_PORT = "/dev/ttyUSB0"
DWIN_PORT = "/dev/serial0"

PAM_BAUD = 57600
DWIN_BAUD = 115200

PAM_CMD_DELAY = 0.06
MAIN_LOOP_DELAY = 0.03
MODE_CHECK_INTERVAL = 3.0

# -------------------------------------------------
# SERIAL OBJECTS
# -------------------------------------------------
pam = None
dwin = None

pam_connected_once = False
last_mode_check = 0

# -------------------------------------------------
# SERIAL INIT / RECONNECT
# -------------------------------------------------


def open_pam():
    global pam, pam_connected_once
    while True:
        try:
            pam = serial.Serial(PAM_PORT, PAM_BAUD,
                                timeout=0.15, write_timeout=0.15)
            time.sleep(0.5)
            pam_connected_once = False
            print("✅ PAM connected")
            return
        except Exception:
            print("⏳ Waiting for PAM...")
            time.sleep(1)


def open_dwin():
    global dwin
    while True:
        try:
            dwin = serial.Serial(DWIN_PORT, DWIN_BAUD, timeout=0.2)
            print("✅ DWIN connected")
            return
        except Exception:
            print("⏳ Waiting for DWIN...")
            time.sleep(1)


def reopen_pam():
    global pam
    try:
        pam.close()
    except Exception:
        pass
    open_pam()


print("--- Initializing hardware ---")
open_pam()
open_dwin()

# -------------------------------------------------
# PAM HELPERS
# -------------------------------------------------


def pam_cmd(cmd):
    global pam
    try:
        pam.reset_input_buffer()
        pam.write((cmd + "\r\n").encode())
        time.sleep(PAM_CMD_DELAY)
        return pam.read(pam.in_waiting or 1).decode(errors="ignore")
    except Exception as e:
        print("❌ PAM ERROR:", e)
        reopen_pam()
        return ""


def extract_number(resp):
    for t in resp.replace(">", "").split():
        try:
            return float(t)
        except ValueError:
            pass
    return None


def extract_mode(resp):
    if "V" in resp:
        return "V"
    if "C" in resp:
        return "C"
    return None


def extract_pam_mode(resp):
    if "STD" in resp:
        return "STD"
    if "EXP" in resp:
        return "EXP"
    return None

# -------------------------------------------------
# PAM MODE ENFORCEMENT
# -------------------------------------------------


def ensure_std_mode():
    global pam_connected_once
    resp = pam_cmd("MODE")
    mode = extract_pam_mode(resp)

    if mode == "EXP":
        pam_cmd("MODE STD")
        time.sleep(0.1)
        pam_cmd("MODE")

    if not pam_connected_once:
        print("✔ PAM MODE verified as STD")
        pam_connected_once = True


# -------------------------------------------------
# DWIN FUNCTIONS
# -------------------------------------------------
cache = {}


def send_to_dwin(vpin, value):
    try:
        iv = int(round(value * 10))
        iv = max(-32768, min(32767, iv))

        if cache.get(vpin) == iv:
            return

        cache[vpin] = iv

        packet = (
            bytes([0x5A, 0xA5, 0x05, 0x82]) +
            vpin.to_bytes(2, "big") +
            iv.to_bytes(2, "big", signed=True)
        )
        dwin.write(packet)
    except Exception as e:
        print("❌ DWIN ERR:", e)


def send_mode_to_dwin(mode):
    try:
        mode_val = 0 if mode == "V" else 1
        packet = bytes([0x5A, 0xA5, 0x05, 0x82, 0x50, 0x00]) + \
            mode_val.to_bytes(2, "big")
        dwin.write(packet)
    except Exception:
        pass


def switch_page(page_id):
    frame = bytes([
        0x5A, 0xA5, 0x07, 0x82,
        0x00, 0x84, 0x5A, 0x01,
        (page_id >> 8) & 0xFF,
        page_id & 0xFF
    ])
    dwin.write(frame)
    dwin.flush()
    time.sleep(0.05)
    dwin.reset_input_buffer()
    print(f"📄 Switched to page {page_id}")

# -------------------------------------------------
# VP5100 POLLING
# -------------------------------------------------


def read_vp_5100_polling(timeout=2.0):
    start = time.time()
    buffer = b""
    cmd = bytes([0x5A, 0xA5, 0x03, 0x83, 0x51, 0x00])

    dwin.reset_input_buffer()

    while time.time() - start < timeout:
        dwin.write(cmd)
        t0 = time.time()
        while time.time() - t0 < 0.15:
            if dwin.in_waiting:
                buffer += dwin.read(dwin.in_waiting)
                if len(buffer) >= 8:
                    return (buffer[-2] << 8) | buffer[-1]
            time.sleep(0.01)
    return None

# -------------------------------------------------
# SCALING
# -------------------------------------------------


def scale_value(raw, mode, function):
    raw = float(raw)
    if mode == "V":
        return raw / 1000.0
    if mode == "C":
        if function == 196:
            return (raw * 0.0016) + 4.0
        return min(20.0, max(4.0, (raw * 0.0008) + 12.0))
    return None


# -------------------------------------------------
# MAIN LOOP
# -------------------------------------------------
print("\n--- SYSTEM RUNNING (PAGE-28 ENABLED) ---")

mismatch_page_active = False
vp5100_applied = False

try:
    while True:
        now = time.time()

        if now - last_mode_check > MODE_CHECK_INTERVAL:
            ensure_std_mode()
            last_mode_check = now

        func = extract_number(pam_cmd("FUNCTION"))
        if func is None:
            time.sleep(0.1)
            continue

        func = int(func)

        # ================= FUNCTION 196 =================
        if func == 196:
            mode_a = extract_mode(pam_cmd("AINA"))
            mode_b = extract_mode(pam_cmd("AINB"))

            # 🔥 MODE MISMATCH HANDLING
            if mode_a and mode_b and mode_a != mode_b:
                if not mismatch_page_active:
                    switch_page(28)
                    mismatch_page_active = True
                    vp5100_applied = False

                if not vp5100_applied:
                    sel = read_vp_5100_polling()
                    if sel == 0:
                        pam_cmd("AINA V")
                        pam_cmd("AINB V")
                        vp5100_applied = True
                    elif sel == 1:
                        pam_cmd("AINA C")
                        pam_cmd("AINB C")
                        vp5100_applied = True
                time.sleep(0.1)
                continue
            else:
                mismatch_page_active = False

            if mode_a:
                send_mode_to_dwin(mode_a)

            wa = extract_number(pam_cmd("WA"))
            wb = extract_number(pam_cmd("WB"))

            if wa is not None:
                send_to_dwin(0x5500, scale_value(wa, mode_a, 196))
            if wb is not None:
                send_to_dwin(0x5600, scale_value(wb, mode_b, 196))

        # ================= FUNCTION 195 =================
        elif func == 195:
            mode_a = extract_mode(pam_cmd("AINA"))
            if mode_a:
                send_mode_to_dwin(mode_a)

            w = extract_number(pam_cmd("W"))
            if w is not None:
                send_to_dwin(0x5500, scale_value(w, mode_a, 195))

            send_to_dwin(0x5600, 0.0)

        # ================= COMMON =================
        ia = extract_number(pam_cmd("IA"))
        ib = extract_number(pam_cmd("IB"))

        if ia is not None:
            send_to_dwin(0x5700, ia / 10.0)
        if ib is not None:
            send_to_dwin(0x5800, ib / 10.0)

        send_to_dwin(0x5900, 24.0)
        time.sleep(MAIN_LOOP_DELAY)

except KeyboardInterrupt:
    print("\n--- SYSTEM STOPPED ---")
