import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "widgets"
import "notifications/weather"
import "notifications/battery"

ShellRoot {
    readonly property bool performanceMode: !!(Config.getSetting("general", {}).performance)
    readonly property bool quickactionsEnabled: Config.getSetting("general", {}).quickactions !== false
    readonly property bool dockEnabled: Config.getSetting("dock", {}).enabled !== false

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    LazyLoader {
        id: screenshotLoader
        ScreenshotOverlay {}
    }

    function ensureScreenshotOverlay() {
        if (!screenshotLoader.item) screenshotLoader.active = true;
        return screenshotLoader.item;
    }

    IpcHandler {
        target: "screenshotOverlay"

        function toggle(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.toggleOverlay(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function activate(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.activate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function deactivate(): void {
            if (screenshotLoader.item) screenshotLoader.item.deactivate();
        }
    }

    GlobalShortcut { name: "volumeToggle";        onPressed: PopupController.toggle("volume") }
    GlobalShortcut { name: "networkToggle";       onPressed: PopupController.toggle("network") }
    GlobalShortcut { name: "calendarToggle";      onPressed: PopupController.toggle("calendar") }
    GlobalShortcut { name: "musicToggle";         onPressed: PopupController.toggle("music") }
    GlobalShortcut { name: "systemToggle";        onPressed: PopupController.toggle("system") }
    GlobalShortcut { name: "notificationsToggle"; onPressed: PopupController.toggle("notifications") }
    GlobalShortcut { name: "guideToggle";         onPressed: PopupController.toggle("guide") }
    GlobalShortcut { name: "wallpaperToggle";     onPressed: PopupController.toggle("wallpaper") }
    GlobalShortcut { name: "launcherToggle";      onPressed: LauncherController.toggle() }
    GlobalShortcut { name: "clipboardToggle";     onPressed: ClipboardController.toggle() }

    Main {}
    Bar {}
    Lock {}
    WidgetRedactor {}
    LockRedactor {}

    Launcher {}
    Clipboard {}    

    Polkit {}
    WellbeingLimitOverlay {}
    PopoutManager {}

    Loader {
        active: dockEnabled
        sourceComponent: Dock {}
    }

    Idle {}
    Variants {
        model: performanceMode ? [] : Quickshell.screens
        delegate: WidgetLoader {
            required property var modelData
            screen: modelData
            monitorName: modelData.name
        }
    }
    Loader {
        active: !performanceMode
        sourceComponent: WallpaperEngine {}
    }
    Loader {
        active: !performanceMode && quickactionsEnabled
        sourceComponent: Floating {}
    }

    Component.onCompleted: {
        Qt.application.organization = "serpantinum";
        Qt.application.domain = "serpantinum.org";
        Qt.application.name = "serpantinum";
        FirstLaunch.checkFirstLaunch();
        SysNotif.checkBattery();
        WeatherAlerts.isQuietNow();
        GovAlerts.refresh();
    }
}
