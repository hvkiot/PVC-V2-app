#!/usr/bin/env python3
import dbus
import dbus.mainloop.glib
import dbus.service
import time
import threading
from gi.repository import GLib
import serial

BLUEZ_SERVICE_NAME = "org.bluez"
DBUS_OM_IFACE = "org.freedesktop.DBus.ObjectManager"
GATT_MANAGER_IFACE = "org.bluez.GattManager1"
LE_ADVERTISING_MANAGER_IFACE = "org.bluez.LEAdvertisingManager1"
GATT_SERVICE_IFACE = "org.bluez.GattService1"
GATT_CHRC_IFACE = "org.bluez.GattCharacteristic1"
LE_ADVERTISEMENT_IFACE = "org.bluez.LEAdvertisement1"
PROP_IFACE = "org.freedesktop.DBus.Properties"

# Your custom UUIDs (keep them fixed forever)
SERVICE_UUID = "12345678-1234-5678-1234-56789abcdef0"
CHAR_UUID = "12345678-1234-5678-1234-56789abcdef1"

MAIN_LOOP = None


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

machine_state = {
    "FUNC": None,
    "WA": None,
    "WB": None,
    "IA": None,
    "IB": None,
    "MODE": None
}

state_lock = threading.Lock()

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
        with state_lock:
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
# BLUEZ HELPERS
# -------------------------------------------------


def find_adapter(bus):
    om = dbus.Interface(bus.get_object(BLUEZ_SERVICE_NAME, "/"), DBUS_OM_IFACE)
    objects = om.GetManagedObjects()
    for path, ifaces in objects.items():
        if LE_ADVERTISING_MANAGER_IFACE in ifaces and GATT_MANAGER_IFACE in ifaces:
            return path
    return None


class Application(dbus.service.Object):
    def __init__(self, bus):
        self.path = "/"
        self.services = []
        dbus.service.Object.__init__(self, bus, self.path)

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def add_service(self, service):
        self.services.append(service)

    @dbus.service.method(DBUS_OM_IFACE, out_signature="a{oa{sa{sv}}}")
    def GetManagedObjects(self):
        response = {}
        for service in self.services:
            response[service.get_path()] = service.get_properties()
            for chrc in service.characteristics:
                response[chrc.get_path()] = chrc.get_properties()
        return response


class Service(dbus.service.Object):
    def __init__(self, bus, index, uuid, primary=True):
        self.path = f"/com/example/service{index}"
        self.bus = bus
        self.uuid = uuid
        self.primary = primary
        self.characteristics = []
        dbus.service.Object.__init__(self, bus, self.path)

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def add_characteristic(self, chrc):
        self.characteristics.append(chrc)

    def get_properties(self):
        return {
            GATT_SERVICE_IFACE: {
                "UUID": self.uuid,
                "Primary": self.primary,
            }
        }


class Characteristic(dbus.service.Object):
    def __init__(self, bus, index, uuid, flags, service):
        self.path = service.path + f"/char{index}"
        self.bus = bus
        self.uuid = uuid
        self.flags = flags
        self.service = service
        self.notifying = False
        self.value = [dbus.Byte(0)]
        dbus.service.Object.__init__(self, bus, self.path)

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def get_properties(self):
        return {
            GATT_CHRC_IFACE: {
                "Service": self.service.get_path(),
                "UUID": self.uuid,
                "Flags": self.flags,
            }
        }

    def _notify_value(self, text: str):
        if not self.notifying:
            return
        data = [dbus.Byte(b) for b in text.encode("utf-8")]
        self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": data}, [])

    @dbus.service.method(PROP_IFACE, in_signature="ss", out_signature="v")
    def Get(self, interface, prop):
        props = self.get_properties().get(interface, {})
        if prop not in props:
            raise dbus.exceptions.DBusException(
                "org.freedesktop.DBus.Error.InvalidArgs", "No such property")
        return props[prop]

    @dbus.service.method(PROP_IFACE, in_signature="ssv")
    def Set(self, interface, prop, value):
        raise dbus.exceptions.DBusException(
            "org.freedesktop.DBus.Error.NotSupported", "Not supported")

    @dbus.service.method(PROP_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return self.get_properties().get(interface, {})

    @dbus.service.signal(PROP_IFACE, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    @dbus.service.method(GATT_CHRC_IFACE, in_signature="a{sv}", out_signature="ay")
    def ReadValue(self, options):
        # return last value (optional)
        return dbus.Array(self.value, signature="y")

    @dbus.service.method(GATT_CHRC_IFACE, in_signature="aya{sv}")
    def WriteValue(self, value, options):
        # not needed here
        pass

    @dbus.service.method(GATT_CHRC_IFACE)
    def StartNotify(self):
        self.notifying = True

    @dbus.service.method(GATT_CHRC_IFACE)
    def StopNotify(self):
        self.notifying = False


class DataCharacteristic(Characteristic):
    def __init__(self, bus, index, service):
        super().__init__(bus, index, CHAR_UUID, ["read", "notify"], service)

    def start_sending(self):
        def loop():
            while True:
                try:
                    packet = (
                        f"FUNC:{machine_state['FUNC']},"
                        f"WA:{machine_state['WA']},"
                        f"WB:{machine_state['WB']},"
                        f"IA:{machine_state['IA']},"
                        f"IB:{machine_state['IB']},"
                        f"MODE:{machine_state['MODE']}\n"
                    )

                    self.value = [dbus.Byte(b) for b in packet.encode("utf-8")]
                    self._notify_value(packet)

                except Exception as e:
                    print("BLE ERROR:", e)

                time.sleep(0.2)

        threading.Thread(target=loop, daemon=True).start()


class Advertisement(dbus.service.Object):
    def __init__(self, bus, index, adapter_path):
        self.path = f"/com/example/advertisement{index}"
        self.bus = bus
        self.adapter_path = adapter_path
        self.service_uuids = [SERVICE_UUID]
        self.local_name = "26020001"
        dbus.service.Object.__init__(self, bus, self.path)

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def get_properties(self):
        return {
            LE_ADVERTISEMENT_IFACE: {
                "Type": "peripheral",
                "ServiceUUIDs": dbus.Array(self.service_uuids, signature="s"),
                "LocalName": self.local_name,
                "IncludeTxPower": True,
            }
        }

    @dbus.service.method(PROP_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        if interface != LE_ADVERTISEMENT_IFACE:
            return {}
        return self.get_properties()[LE_ADVERTISEMENT_IFACE]

    @dbus.service.method(LE_ADVERTISEMENT_IFACE)
    def Release(self):
        pass


def main():
    global MAIN_LOOP
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()

    adapter = find_adapter(bus)
    if not adapter:
        print("No BLE adapter found (needs LEAdvertisingManager1 + GattManager1)")
        return

    # Build GATT app
    app = Application(bus)
    service = Service(bus, 0, SERVICE_UUID, True)
    ch = DataCharacteristic(bus, 0, service)
    service.add_characteristic(ch)
    app.add_service(service)

    # Register GATT app
    service_manager = dbus.Interface(bus.get_object(
        BLUEZ_SERVICE_NAME, adapter), GATT_MANAGER_IFACE)
    ad_manager = dbus.Interface(bus.get_object(
        BLUEZ_SERVICE_NAME, adapter), LE_ADVERTISING_MANAGER_IFACE)

    adv = Advertisement(bus, 0, adapter)

    MAIN_LOOP = GLib.MainLoop()

    def on_app_registered():
        print("GATT application registered")
        ch.start_sending()

    def on_app_error(e):
        print("Failed to register application:", e)
        MAIN_LOOP.quit()

    def on_adv_registered():
        print("Advertisement registered: name=26020001 service_uuid=", SERVICE_UUID)

    def on_adv_error(e):
        print("Failed to register advertisement:", e)
        MAIN_LOOP.quit()

    service_manager.RegisterApplication(app.get_path(
    ), {}, reply_handler=lambda: on_app_registered(), error_handler=on_app_error)
    ad_manager.RegisterAdvertisement(adv.get_path(
    ), {}, reply_handler=lambda: on_adv_registered(), error_handler=on_adv_error)

    try:
        MAIN_LOOP.run()
    finally:
        try:
            ad_manager.UnregisterAdvertisement(adv.get_path())
        except:
            pass


def start_ble():
    main()


# -------------------------------------------------
# MAIN LOOP
# -------------------------------------------------


mismatch_page_active = False
vp5100_applied = False

if __name__ == "__main__":
    print("\n--- SYSTEM RUNNING ---")

    # Start BLE in background
    threading.Thread(target=start_ble, daemon=True).start()

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

                wa = extract_number(pam_cmd("WA"))
                wb = extract_number(pam_cmd("WB"))

                ia = extract_number(pam_cmd("IA"))
                ib = extract_number(pam_cmd("IB"))

                # -------- DWIN OUTPUT ----------
                if mode_a:
                    send_mode_to_dwin(mode_a)

                if wa is not None:
                    send_to_dwin(0x5500, scale_value(wa, mode_a, 196))

                if wb is not None:
                    send_to_dwin(0x5600, scale_value(wb, mode_b, 196))

                if ia is not None:
                    send_to_dwin(0x5700, ia / 10.0)

                if ib is not None:
                    send_to_dwin(0x5800, ib / 10.0)

                send_to_dwin(0x5900, 24.0)

            # ================= FUNCTION 195 =================
            elif func == 195:

                mode_a = extract_mode(pam_cmd("AINA"))

                wa = extract_number(pam_cmd("W"))
                wb = 0

                ia = extract_number(pam_cmd("IA"))
                ib = extract_number(pam_cmd("IB"))

                # -------- DWIN OUTPUT ----------
                if mode_a:
                    send_mode_to_dwin(mode_a)

                if wa is not None:
                    send_to_dwin(0x5500, scale_value(wa, mode_a, 195))

                send_to_dwin(0x5600, 0.0)

                if ia is not None:
                    send_to_dwin(0x5700, ia / 10.0)

                if ib is not None:
                    send_to_dwin(0x5800, ib / 10.0)

                send_to_dwin(0x5900, 24.0)

            # ================= SAVE FOR BLE =================
            with state_lock:
                machine_state["FUNC"] = func
                machine_state["WA"] = scale_value(wa, mode_a, func)
                machine_state["WB"] = scale_value(wb, mode_b, func)
                machine_state["IA"] = ia
                machine_state["IB"] = ib
                machine_state["MODE"] = mode_a

            time.sleep(MAIN_LOOP_DELAY)

    except KeyboardInterrupt:
        print("\n--- SYSTEM STOPPED ---")
