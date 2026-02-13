#!/usr/bin/env python3
import dbus
import dbus.mainloop.glib
import dbus.service
import time
import threading
from gi.repository import GLib

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
CHAR_UUID    = "12345678-1234-5678-1234-56789abcdef1"

MAIN_LOOP = None

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
            raise dbus.exceptions.DBusException("org.freedesktop.DBus.Error.InvalidArgs", "No such property")
        return props[prop]

    @dbus.service.method(PROP_IFACE, in_signature="ssv")
    def Set(self, interface, prop, value):
        raise dbus.exceptions.DBusException("org.freedesktop.DBus.Error.NotSupported", "Not supported")

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

class SjrdDataCharacteristic(Characteristic):
    def __init__(self, bus, index, service):
        super().__init__(bus, index, CHAR_UUID, ["read", "notify"], service)

    def start_sending(self):
        def loop():
            i = 0
            while True:
                # Replace this with your real sensor/data
                msg = f"{i}\n"
                self._notify_value(msg)
                i += 1
                time.sleep(1)

        t = threading.Thread(target=loop, daemon=True)
        t.start()

class Advertisement(dbus.service.Object):
    def __init__(self, bus, index, adapter_path):
        self.path = f"/com/example/advertisement{index}"
        self.bus = bus
        self.adapter_path = adapter_path
        self.service_uuids = [SERVICE_UUID]
        self.local_name = "SJRD_PI"
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
    ch = SjrdDataCharacteristic(bus, 0, service)
    service.add_characteristic(ch)
    app.add_service(service)

    # Register GATT app
    service_manager = dbus.Interface(bus.get_object(BLUEZ_SERVICE_NAME, adapter), GATT_MANAGER_IFACE)
    ad_manager = dbus.Interface(bus.get_object(BLUEZ_SERVICE_NAME, adapter), LE_ADVERTISING_MANAGER_IFACE)

    adv = Advertisement(bus, 0, adapter)

    MAIN_LOOP = GLib.MainLoop()

    def on_app_registered():
        print("GATT application registered")
        ch.start_sending()

    def on_app_error(e):
        print("Failed to register application:", e)
        MAIN_LOOP.quit()

    def on_adv_registered():
        print("Advertisement registered: name=SJRD_PI service_uuid=", SERVICE_UUID)

    def on_adv_error(e):
        print("Failed to register advertisement:", e)
        MAIN_LOOP.quit()

    service_manager.RegisterApplication(app.get_path(), {}, reply_handler=lambda: on_app_registered(), error_handler=on_app_error)
    ad_manager.RegisterAdvertisement(adv.get_path(), {}, reply_handler=lambda: on_adv_registered(), error_handler=on_adv_error)

    try:
        MAIN_LOOP.run()
    finally:
        try:
            ad_manager.UnregisterAdvertisement(adv.get_path())
        except:
            pass

if __name__ == "__main__":
    main()