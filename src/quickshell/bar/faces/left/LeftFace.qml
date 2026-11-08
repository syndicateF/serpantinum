import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../reusables"
import "../../../"
import "../../"

BarFaceBase {
    id: root

    readonly property bool showLayout: (barWindow && !isPreview) ? Boolean(barWindow.isStartupReady) : true
    readonly property real barOpacity: ThemeBackend.elementOpacity

    property string menuStyle: {
        if (widget && widget !== root && widget.menuStyle !== undefined) return widget.menuStyle;
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.menuStyle) return Config.rawSettings.bar.menuStyle;
        return "button";
    }

    property var menuItems: {
        if (widget && widget !== root && widget.menuItems !== undefined) return widget.menuItems;
        let dummy = configRevision;
        let bs = (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : {};
        return BarModuleRegistry.menuItemsFromSettings(bs);
    }

    readonly property bool showCaffeine: menuItems.indexOf("caffeine") !== -1
    readonly property bool iconOnly: menuStyle === "icon"

    readonly property var helpButton: {
        let dummy = menuRepeater.count;
        let found = null;
        for (let i = 0; i < menuRepeater.count; i++) {
            let it = menuRepeater.itemAt(i);
            if (!it) continue;
            if (it.itemId === "settings") return it;
            if (!found && it.itemId === "launcher") found = it;
        }
        return found || menuRepeater.itemAt(0);
    }

    property bool nightLightActive: {
        let dummy = configRevision;
        return (typeof Gamma !== "undefined" && typeof Gamma.isAnyEnabled === "function") ? Gamma.isAnyEnabled() : false;
    }

    readonly property string currentScreenName: (barWindow && barWindow.screen && barWindow.screen.name) ? barWindow.screen.name : ""
    readonly property int nightLightValue: {
        let dummy = configRevision;
        if (typeof Gamma === "undefined" || typeof Gamma.getSavedTemperature !== "function") return 50;
        return Math.round(Gamma.getSavedTemperature(currentScreenName));
    }
    readonly property string nightLightValueString: {
        if (!nightLightActive) return "";
        return nightLightValue + "%";
    }

    property bool caffeineActive: {
        let dummy = configRevision;
        let idleObj = (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.idle) ? Config.rawSettings.idle : null;
        if (!idleObj || !idleObj.manualInhibit) return false;
        let endTime = Number(idleObj.caffeineEndTime) || 0;
        return endTime <= 0 || endTime > Date.now();
    }

    property int caffeineRemainingSec: 0

    function updateCaffeineRemaining() {
        let idleObj = (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.idle) ? Config.rawSettings.idle : null;
        if (!idleObj || !idleObj.manualInhibit) {
            caffeineRemainingSec = 0;
            return;
        }
        let endTime = Number(idleObj.caffeineEndTime) || 0;
        if (endTime <= 0) {
            caffeineRemainingSec = -1;
            return;
        }
        let now = Date.now();
        if (endTime <= now) {
            caffeineRemainingSec = 0;
            root.setCaffeine(false);
        } else {
            caffeineRemainingSec = Math.round((endTime - now) / 1000);
        }
    }

    onCaffeineActiveChanged: {
        if (caffeineActive) updateCaffeineRemaining();
    }

    Connections {
        target: (typeof Gamma !== "undefined") ? Gamma : null
        ignoreUnknownSignals: true
        function onSettingsChanged() { root.configRevision++; }
    }

    Timer {
        id: caffeineTicker
        interval: 1000
        repeat: true
        running: root.showCaffeine && root.caffeineActive && !root.isPreview
        triggeredOnStart: true
        onTriggered: {
            root.updateCaffeineRemaining();
        }
    }

    readonly property string caffeineTimeString: {
        if (!caffeineActive) return "";
        if (caffeineRemainingSec < 0) return "∞";
        let h = Math.floor(caffeineRemainingSec / 3600);
        let m = Math.floor((caffeineRemainingSec % 3600) / 60);
        return (h < 10 ? "0" + h : h) + ":" + (m < 10 ? "0" + m : m);
    }

    function toggleNightLight() {
        if (typeof Gamma === "undefined" || typeof Gamma.setEnabled !== "function") return;
        let target = !root.nightLightActive;
        let monNames = [];
        let ds = Config.getSetting("display", {"monitors": {}});
        let mons = (ds && ds.monitors) ? ds.monitors : {};
        for (let m in mons) {
            if (monNames.indexOf(m) === -1) monNames.push(m);
        }
        if (Quickshell.screens) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                let scr = Quickshell.screens[i];
                if (scr && scr.name && monNames.indexOf(scr.name) === -1) monNames.push(scr.name);
            }
        }
        if (monNames.length > 0) {
            for (let i = 0; i < monNames.length; i++) Gamma.setEnabled(monNames[i], target);
        } else {
            Gamma.setEnabled("", target);
        }
    }

    function shuffleWallpaper(btn) {
        let scr = barWindow ? barWindow.screen : null;
        let transition = "circle";
        if (btn && scr && scr.width > 0 && scr.height > 0) {
            let pt = btn.mapToItem(null, btn.width / 2, btn.height / 2);
            let pos = barWindow.barPosition;
            let x = pt.x + (pos === "right" ? scr.width - barWindow.width : 0);
            let y = pt.y + (pos === "bottom" ? scr.height - barWindow.height : 0);
            transition = "circle:" + Math.max(0, Math.min(1, x / scr.width)) + ":" + Math.max(0, Math.min(1, y / scr.height));
        }
        Wallpaper.shuffle(scr && scr.name ? scr.name : "", transition);
    }

    function setCaffeine(enabled) {
        let now = Date.now();
        let idleObj = Object.assign({}, Config.getSetting("idle", {}));
        idleObj.manualInhibit = enabled;
        idleObj.caffeineStartTime = enabled ? now : 0;
        idleObj.caffeineEndTime = enabled ? now + 3600 * 1000 : 0;
        Config.setSetting("idle", idleObj);
    }

    readonly property int menuCount: menuItems ? menuItems.length : 0
    readonly property real buttonsLength: menuCount > 0
        ? menuCount * (isVertical ? s(isCompact ? 28 : 30) : s(isCompact ? 30 : 32)) + (menuCount - 1) * s(isCompact ? 2 : 4)
        : 0
    property real targetLength: {
        if (module && !module.moduleActive) return 0;
        let flowLen = isVertical ? buttonsFlow.implicitHeight : buttonsFlow.implicitWidth;
        let effectiveLen = Math.max(flowLen, buttonsLength);
        return effectiveLen > 0 ? (effectiveLen + s(isCompact ? 6 : 8)) : 0;
    }

    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)

    component MenuButton: Item {
        id: menuBtn
        signal clicked()
        property string glyph: ""
        property bool active: false
        property color activeColor: ThemeBackend.peach
        property int glyphYOffset: 0
        property string labelText: ""
        property string lastKnownText: ""

        onLabelTextChanged: {
            if (labelText !== "") lastKnownText = labelText;
        }

        readonly property bool hasLabel: labelText !== "" && active && !root.isVertical
        readonly property real baseWidth: root.isVertical ? root.s(root.isCompact ? 28 : 30) : root.s(root.isCompact ? 30 : 31.5)
        readonly property real baseIconLeft: Math.round((baseWidth - iconMeasure.implicitWidth) / 2)
        readonly property real textGap: root.s(root.isCompact ? 4 : 5)
        readonly property real targetLabelWidth: labelMeasure.implicitWidth
        readonly property real expandedWidth: hasLabel
            ? Math.round(baseIconLeft + iconMeasure.implicitWidth + textGap + targetLabelWidth + baseIconLeft)
            : baseWidth

        width: expandedWidth
        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        height: root.s(root.isCompact ? 28 : 31.5)

        opacity: (root.isVertical || root.showLayout) ? 1.0 : 0.0
        transform: Translate {
            y: (root.isVertical || root.showLayout) ? 0 : root.s(15)
            Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
        }
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        Text {
            id: iconMeasure
            visible: false
            text: menuBtn.glyph
            font.family: ThemeBackend.iconFont
            font.pixelSize: root.s(root.isCompact ? 14 : 15)
        }
        Text {
            id: labelMeasure
            visible: false
            text: menuBtn.labelText !== "" ? menuBtn.labelText : menuBtn.lastKnownText
            font.family: "JetBrains Mono"
            font.pixelSize: root.s(root.isCompact ? 10.5 : 11.5)
            font.weight: Font.Bold
        }

        Item {
            id: btnInner
            // anchors.left: parent.left
            // anchors.leftMargin: 1
            anchors.fill: parent
            scale: (btnMa.pressed ? 0.96 : (btnMa.containsMouse ? 1.04 : 1.0))
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

            Rectangle {
                id: btnBg
                anchors.fill: parent
                visible: !root.iconOnly
                radius: Math.max(0, ThemeBackend.borderRadius - root.s(2))
                clip: !menuGlass.active
                color: ThemeBackend.liquidGlass ? "transparent" : (
                    menuBtn.active
                        ? root.getPillAccentColor(menuBtn.activeColor, true)
                        : (btnMa.pressed
                            ? Qt.darker(root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0, 1.12)
                            : (btnMa.containsMouse
                                ? Qt.lighter(root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0, 1.12)
                                : (root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)))
                )
                opacity: menuBtn.active ? 1.0 : root.barOpacity

                Behavior on color { ColorAnimation { duration: 150 } }

                GlassFill {
                    id: menuGlass
                    anchors.fill: parent
                    radius: parent.radius
                    allowed: true
                    tintColor: menuBtn.active ? menuBtn.activeColor : (root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
                    tintAmount: menuBtn.active ? (root.isTintedPill ? 0.25 : 0.45) : (btnMa.containsMouse ? 0.35 : 0.2)
                    press: btnMa.pressed ? 0.8 : (btnMa.containsMouse ? 0.25 : 0)
                }
            }

            Item {
                id: contentContainer
                anchors.fill: parent

                Text {
                    id: iconText
                    x: menuBtn.baseIconLeft
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: menuBtn.glyphYOffset
                    text: menuBtn.glyph
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: root.s(root.isCompact ? 14 : 15)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: menuBtn.active
                        ? root.getPillTextColor(menuBtn.activeColor, true)
                        : (btnMa.containsMouse ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2))
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Item {
                    id: labelClip
                    anchors.left: iconText.right
                    anchors.leftMargin: menuBtn.textGap
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    width: menuBtn.hasLabel ? labelItem.implicitWidth : 0
                    height: labelItem.implicitHeight
                    opacity: menuBtn.hasLabel ? 1.0 : 0.0

                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Text {
                        id: labelItem
                        anchors.verticalCenter: parent.verticalCenter
                        text: menuBtn.labelText !== "" ? menuBtn.labelText : menuBtn.lastKnownText
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(root.isCompact ? 10.5 : 11.5)
                        font.weight: Font.Bold
                        color: menuBtn.active
                            ? root.getPillTextColor(menuBtn.activeColor, true)
                            : ThemeBackend.text
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
            }

            MouseArea {
                id: btnMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof Sounds !== "undefined") {
                        Sounds.playSfx("reusables/iconbutton/click.wav");
                    }
                    menuBtn.clicked();
                }
            }
        }
    }

    AxisFlow {
        id: buttonsFlow
        vertical: root.isVertical
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        spacing: root.s(root.isCompact ? 2 : 4)
        anchors.centerIn: root.isVertical ? parent : undefined
        anchors.verticalCenter: root.isVertical ? undefined : parent.verticalCenter
        anchors.left: root.isVertical ? undefined : parent.left
        anchors.leftMargin: root.isVertical ? 0 : root.s(root.isCompact ? 3 : 4)

        Repeater {
            id: menuRepeater
            model: root.menuItems

            MenuButton {
                id: menuItem
                required property string modelData
                readonly property string itemId: modelData
                glyph: BarModuleRegistry.menuItemIcon(itemId)
                glyphYOffset: itemId === "nightlight" ? -1 : 0
                active: itemId === "nightlight" ? root.nightLightActive : (itemId === "caffeine" ? root.caffeineActive : false)
                activeColor: itemId === "caffeine" ? ThemeBackend.yellow : ThemeBackend.peach
                labelText: {
                    if (itemId === "caffeine") return root.caffeineTimeString;
                    if (itemId === "nightlight") return root.nightLightValueString;
                    return "";
                }
                onClicked: {
                    if (root.isPreview) return;
                    if (itemId === "settings") Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle settings"]);
                    else if (itemId === "launcher") Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle launcher"]);
                    else if (itemId === "nightlight") root.toggleNightLight();
                    else if (itemId === "caffeine") root.setCaffeine(!root.caffeineActive);
                    else if (itemId === "shuffle") root.shuffleWallpaper(menuItem);
                }
            }
        }
    }
}
