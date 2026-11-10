pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../"

Item {
    id: root

    // ─── UPOWER NATIVE BINDINGS ─────────────────────────────────────────────
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: Boolean(root.battery && root.battery.ready && root.battery.isPresent && (root.battery.isLaptopBattery || root.battery.type === UPowerDeviceType.Battery))
    
    // Konversi aman 0.0 - 1.0 atau 0 - 100
    readonly property int batteryPercentage: {
        if (!root.battery || !root.battery.ready) return 100;
        let raw = root.battery.percentage;
        return raw > 1.0 ? Math.floor(raw) : Math.floor(raw * 100);
    }

    readonly property bool isCharging: {
        if (!root.battery || !root.battery.ready) return false;
        let s = root.battery.state;
        return s === UPowerDeviceState.Charging ||
               s === UPowerDeviceState.FullyCharged ||
               s === UPowerDeviceState.PendingCharge;
    }

    // ─── THRESHOLDS & STATE ──────────────────────────────────────────────────
    readonly property var thresholds: [20, 10, 5]
    property int lastNotifiedLevel: 0
    property int lastState: -1
    property bool initialized: false
    property bool notifiedFull: false

    // ─── EVALUASI LEVEL BATERAI ─────────────────────────────────────────────
    function evaluateBattery() {
        if (!root.hasBattery || !root.battery.ready) return;

        let pct = root.batteryPercentage;
        let state = root.battery.state;

        // Saat charging: reset status low battery & cek apakah baterai sudah penuh
        if (root.isCharging) {
            root.resetBatteryState();

            if ((pct >= 100 || state === UPowerDeviceState.FullyCharged) && !root.notifiedFull) {
                root.notifiedFull = true;
                root.sendFullBatteryNotification();
            } else if (pct < 100 && state !== UPowerDeviceState.FullyCharged) {
                root.notifiedFull = false;
            }
            return;
        }

        // Saat discharging: reset flag notifiedFull
        root.notifiedFull = false;

        if (state !== UPowerDeviceState.Discharging) return;

        // Cari threshold tertinggi yang terkena
        let targetLevel = 0;
        for (let i = root.thresholds.length - 1; i >= 0; i--) {
            if (pct <= root.thresholds[i]) {
                targetLevel = root.thresholds[i];
                break;
            }
        }

        if (targetLevel === 0) {
            // Persentase naik di atas threshold normal (misal 25%)
            if (pct > 25) root.lastNotifiedLevel = 0;
            return;
        }

        // Anti-spam & anti fluktuasi: jika sudah dinotif di level ini atau level lebih kritis, jangan notif lagi
        if (root.lastNotifiedLevel !== 0 && targetLevel >= root.lastNotifiedLevel) {
            return;
        }

        root.sendLowBatteryNotification(targetLevel, pct);
        root.lastNotifiedLevel = targetLevel;
    }

    function resetBatteryState() {
        root.lastNotifiedLevel = 0;

        // Bersihkan popup low battery yang masih nyangkut di NotificationManager
        if (typeof NotificationManager !== "undefined" && NotificationManager.activePopupsModel) {
            for (let i = NotificationManager.activePopupsModel.count - 1; i >= 0; i--) {
                let item = NotificationManager.activePopupsModel.get(i);
                if (item && (item.appName === "Battery Monitor" || (item.summary && item.summary.indexOf("Battery") !== -1))) {
                    NotificationManager.removePopup(item.uid);
                }
            }
        }
    }

    // ─── NOTIFIKASI & SOUND DISPATCHER ──────────────────────────────────────
    function sendLowBatteryNotification(level, currentPct) {
        let isCrit = level <= 5;
        let urgency = isCrit ? "critical" : "normal";
        let icon = isCrit ? "battery-empty-symbolic" : (level <= 10 ? "battery-low-symbolic" : "battery-caution-symbolic");

        let appName = I18n.t("sysnotif.battery.app_name");
        let tKey = isCrit ? "sysnotif.battery.critical_title" : "sysnotif.battery.low_title";
        let bKey = isCrit ? "sysnotif.battery.critical_body" : "sysnotif.battery.low_body";
        let title = I18n.t(tKey, { "pct": level });
        let body = I18n.t(bKey, { "pct": currentPct });

        // Bunyikan peringatan suara baterai spesifik
        if (typeof Sounds !== "undefined") {
            let sfxFile = isCrit ? "battery/lowbatcrit.wav" : "battery/lowbat.wav";
            Sounds.playSfx(sfxFile, 1.0);
        }

        // Kirim via notify-send dengan synchronous replacement tag agar TIDAK NUMPUK
        Quickshell.execDetached([
            "notify-send",
            "-a", appName,
            "-u", urgency,
            "-i", icon,
            "-h", "string:x-canonical-private-synchronous:battery",
            "-h", "int:battery-level:" + level,
            title,
            body
        ]);
    }

    function sendFullBatteryNotification() {
        let appName = I18n.t("sysnotif.battery.app_name");
        let title = I18n.t("sysnotif.battery.full_title");
        let body = I18n.t("sysnotif.battery.full_body");

        Quickshell.execDetached([
            "notify-send",
            "-a", appName,
            "-u", "normal",
            "-i", "battery-full-charged",
            "-h", "string:x-canonical-private-synchronous:battery",
            title,
            body
        ]);
    }

    // ─── GENERIC SYSTEM NOTIFICATION HELPER ─────────────────────────────────
    // Bisa digunakan oleh komponen sistem lain jika butuh kirim notif sistem
    function sendNotification(summary, body, icon, urgency) {
        let u = urgency ? urgency : "normal";
        let ic = icon ? icon : "dialog-information";
        let appName = "System";
        if (typeof I18n !== "undefined" && I18n.isReady) {
            let a = I18n.t("sysnotif.battery.app_name");
            if (a !== "sysnotif.battery.app_name") appName = a;
        }

        Quickshell.execDetached([
            "notify-send",
            "-a", appName,
            "-u", u,
            "-i", ic,
            summary,
            body
        ]);
    }

    // Public method yang dipanggil di Shell.qml
    function checkBattery() {
        root.evaluateBattery();
    }

    // ─── REACTIVE LISTENERS ─────────────────────────────────────────────────
    Connections {
        target: root.battery ? root.battery : null

        function onReadyChanged() {
            if (root.battery && root.battery.ready && !root.initialized) {
                root.initialized = true;
                root.lastState = root.battery.state;
                root.evaluateBattery();
            }
        }

        function onPercentageChanged() {
            root.evaluateBattery();
        }

        function onStateChanged() {
            if (!root.battery || !root.battery.ready) return;

            let state = root.battery.state;
            let oldState = root.lastState;
            root.lastState = state;

            if (oldState !== -1 && oldState !== state) {
                let wasCharging = (oldState === UPowerDeviceState.Charging ||
                                   oldState === UPowerDeviceState.FullyCharged ||
                                   oldState === UPowerDeviceState.PendingCharge);
                let isNowCharging = (state === UPowerDeviceState.Charging ||
                                     state === UPowerDeviceState.FullyCharged ||
                                     state === UPowerDeviceState.PendingCharge);

                // Play sound saat dicolok / dicabut charger
                if (!wasCharging && isNowCharging) {
                    if (typeof Sounds !== "undefined") {
                        Sounds.playSfx("battery/charge.wav", 0.9);
                    }
                    root.resetBatteryState();
                } else if (wasCharging && !isNowCharging) {
                    let pct = root.batteryPercentage;
                    let isLow = pct <= root.thresholds[0]; // 20% atau lebih rendah
                    // Prioritas: Jika baterai sudah low saat dicabut, mute sound discharge
                    // agar tidak tabrakan dengan sound low battery yang jauh lebih urgent!
                    if (!isLow && typeof Sounds !== "undefined") {
                        Sounds.playSfx("battery/discharge.wav", 0.9);
                    }
                    root.evaluateBattery();
                }
            }
        }
    }

    Component.onCompleted: {
        if (root.battery && root.battery.ready) {
            root.initialized = true;
            root.lastState = root.battery.state;
            root.evaluateBattery();
        }
    }
}
