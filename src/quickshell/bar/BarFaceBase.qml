import QtQuick
import "../"

Item {
    id: root

    property var module: null
    property var widget: module

    property string orientation: (activeTarget && activeTarget.orientation !== undefined) ? activeTarget.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property var activeTarget: widget || module
    readonly property bool isCompact: activeTarget ? activeTarget.isCompact : false
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null
    readonly property bool isPreview: activeTarget ? Boolean(activeTarget.isPreview) : false

    readonly property string pillColorStyle: {
        if (barWindow && barWindow.pillColorStyle !== undefined) return barWindow.pillColorStyle;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.pillColorStyle !== undefined) {
            return Config.rawSettings.bar.pillColorStyle;
        }
        return "solid";
    }
    readonly property bool isTintedPill: pillColorStyle === "tinted"

    function getPillAccentColor(accentColor, isActive, inactiveBase) {
        let baseSurface = inactiveBase !== undefined 
            ? inactiveBase
            : ThemeBackend.surface0;
        if (!isActive) return baseSurface;

        let activeAccent = accentColor;
        if (isTintedPill) {
            return Qt.alpha(activeAccent, 0.1);
        }
        return activeAccent;
    }

    function getPillTextColor(accentColor, isActive, inactiveText) {
        if (!isActive) {
            return inactiveText !== undefined
                ? inactiveText
                : ThemeBackend.text;
        }
        if (isTintedPill) {
            return accentColor;
        }
        return ThemeBackend.base;
    }

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.cs(val);
        if (activeTarget && typeof activeTarget.s === "function") return activeTarget.s(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }
}
