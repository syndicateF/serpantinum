import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"

Item {
    id: runningDockButton
    required property var dockWindow
    required property var dockContainer
    required property var model
    required property int index

    readonly property bool isClosing: Boolean(model && model.is_closing)
    property real slotProgress: 1.0

    property int itemIndex: dockWindow.dockAppsModel.count + 1 + index
    property real popScale: 1.0
    property real flashOpacity: 0.0
    property color btnColor: ThemeBackend.surface0
    property int cornerRadius: Math.round(dockWindow.s(dockWindow.dockElementSize) * 0.28)
    property int btnSize: dockWindow.s(dockWindow.dockElementSize)

    implicitWidth: dockWindow.isVertical ? btnSize : Math.round(btnSize * slotProgress)
    implicitHeight: dockWindow.isVertical ? Math.round(btnSize * slotProgress) : btnSize
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.maximumWidth: implicitWidth
    Layout.maximumHeight: implicitHeight
    Layout.alignment: Qt.AlignCenter

    NumberAnimation {
        id: enterAnim
        target: runningDockButton
        property: "slotProgress"
        to: 1.0
        duration: 220
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: exitAnim
        NumberAnimation {
            target: runningDockButton
            property: "slotProgress"
            to: 0.0
            duration: 220
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: {
                if (runningDockButton.isClosing) {
                    dockWindow.removeClosingRunningApp(model.desktop_id, model.canonical_id);
                }
            }
        }
    }

    Timer {
        id: safetyExitTimer
        interval: 350
        repeat: false
        running: runningDockButton.isClosing
        onTriggered: {
            if (runningDockButton.isClosing) {
                dockWindow.removeClosingRunningApp(model.desktop_id, model.canonical_id);
            }
        }
    }

    Component.onCompleted: {
        if (dockWindow.initialized && !isClosing) {
            slotProgress = 0.0;
            enterAnim.restart();
        }
    }

    onIsClosingChanged: {
        if (isClosing) {
            if (dockContainer.hoveredItemIndex === runningDockButton.itemIndex) {
                dockContainer.hoveredItemIndex = -1;
                dockContainer.hoveredButton = null;
                dockContainer.hoveredAppName = "";
            }
            if (dockContainer.clickedItemIndex === runningDockButton.itemIndex) {
                dockContainer.cancelClickFeedback();
            }
            enterAnim.stop();
            exitAnim.restart();
        } else {
            exitAnim.stop();
            safetyExitTimer.stop();
            enterAnim.restart();
        }
    }

    readonly property var runningInfo: dockWindow.getRunningInfoForApp(model.desktop_id)
    readonly property bool isAppRunning: runningInfo !== null && runningInfo.hasWindows
    readonly property bool isAppHere: runningInfo !== null && runningInfo.count > 0
    readonly property bool isAppFocused: runningInfo !== null && runningInfo.isFocused
    readonly property int appWindowCount: runningInfo !== null ? runningInfo.count : 0
    readonly property bool isOnlyElsewhere: runningInfo !== null && runningInfo.count === 0 && runningInfo.elsewhere.length > 0

    z: Math.round(runningBtnShape.scale * 100)

    readonly property bool canHoverScale: !dockWindow.editMode && dockWindow.dragSourceIndex === -1
    readonly property real maxHoverScale: dockWindow.dockHoverScaleMultiplier
    readonly property real hoverScaleDelta: Math.max(0.0, maxHoverScale - 1.0)

    readonly property string appName: {
        if (model && model.name && String(model.name).length > 0) return String(model.name);
        if (model && model.title && String(model.title).length > 0) return String(model.title);
        if (runningInfo && runningInfo.appId && String(runningInfo.appId).length > 0) return String(runningInfo.appId);
        return "";
    }

    readonly property real visualScale: runningBtnShape.scale
    readonly property real indicatorScaleOffset: (runningDockButton.btnSize * Math.max(0.0, runningBtnShape.scale - 1.0)) / 2

    property real baseHoverScale: {
        if (!canHoverScale || dockContainer.effectiveHoveredIndex < 0) return 1.0;
        let diff = Math.abs(runningDockButton.itemIndex - dockContainer.effectiveHoveredIndex);
        if (diff === 0) return maxHoverScale;
        if (dockWindow.dockCascadeScale) {
            if (diff === 1) return 1.0 + hoverScaleDelta * 0.45;
            if (diff === 2) return 1.0 + hoverScaleDelta * 0.15;
        }
        return 1.0;
    }

    property real targetScale: {
        let s = baseHoverScale;
        if (runningBtnMa.pressed && canHoverScale) {
            return s > 1.0 ? (s * 1.04) : 1.06;
        }
        return s;
    }

    property real animSpread: {
        if (!canHoverScale || dockContainer.effectiveHoveredIndex < 0) return 0.0;
        let diff = itemIndex - dockContainer.effectiveHoveredIndex;
        if (diff === 0) return 0.0;
        let sign = diff > 0 ? 1.0 : -1.0;
        let d = Math.abs(diff);

        // Pertambahan radius setengah-lebar dari icon yang membesar
        let r0 = (hoverScaleDelta * btnSize) / 2.0;
        if (r0 <= 0.001) return 0.0;

        if (dockWindow.dockCascadeScale) {
            let r1 = r0 * 0.45;
            let r2 = r0 * 0.15;
            let shift1 = r0 + r1;
            let shift2 = r0 + (2.0 * r1) + r2;
            let shift = (d === 1) ? shift1 : shift2;
            return sign * shift;
        } else {
            return sign * r0;
        }
    }

    property real animLift: {
        if (!canHoverScale || dockContainer.effectiveHoveredIndex < 0 || dockWindow.dockHoverLift <= 0) return 0.0;
        let maxLift = dockWindow.s(dockWindow.dockHoverLift);
        if (maxHoverScale <= 1.001) {
            let diff = Math.abs(runningDockButton.itemIndex - dockContainer.effectiveHoveredIndex);
            if (diff === 0) return maxLift;
            if (dockWindow.dockCascadeScale) {
                if (diff === 1) return maxLift * 0.45;
                if (diff === 2) return maxLift * 0.15;
            }
            return 0.0;
        }
        if (targetScale <= 1.0) return 0.0;
        let liftProgress = (targetScale - 1.0) / Math.max(0.01, maxHoverScale - 1.0);
        return maxLift * Math.min(1.0, Math.max(0.0, liftProgress));
    }

    property real targetOffsetX: {
        if (dockWindow.isVertical) {
            if (dockWindow.dockPosition === "left") return animLift;
            if (dockWindow.dockPosition === "right") return -animLift;
            return 0.0;
        }
        return animSpread;
    }

    property real targetOffsetY: {
        if (dockWindow.isVertical) return animSpread;
        if (dockWindow.dockPosition === "bottom") return -animLift;
        if (dockWindow.dockPosition === "top") return animLift;
        return 0.0;
    }

    property real currentOffsetX: targetOffsetX
    property real currentOffsetY: targetOffsetY

    Behavior on currentOffsetX {
        enabled: dockWindow.initialized && !dockWindow.positionChanging
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }
    Behavior on currentOffsetY {
        enabled: dockWindow.initialized && !dockWindow.positionChanging
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    Item {
        id: runningFloatWrapper
        anchors.centerIn: parent
        width: runningDockButton.btnSize
        height: runningDockButton.btnSize

        transformOrigin: Item.Center
        scale: Math.max(0.001, runningDockButton.slotProgress)
        opacity: Math.min(1.0, runningDockButton.slotProgress * 1.5)

        transform: Translate {
            x: runningDockButton.currentOffsetX
            y: runningDockButton.currentOffsetY
        }

        Rectangle {
            id: runningBtnShape
            anchors.fill: parent
            radius: runningDockButton.cornerRadius
            clip: dockWindow.dockAppTileBackground
            color: !dockWindow.dockAppTileBackground ? "transparent" : (runningBtnGlass.active ? "transparent" : Qt.alpha(runningBtnMa.pressed ? Qt.darker(runningDockButton.btnColor, 1.12) : (runningBtnMa.containsMouse ? Qt.lighter(runningDockButton.btnColor, 1.12) : runningDockButton.btnColor), ThemeBackend.elementOpacity))

            readonly property real iconPadding: dockWindow.dockAppTileBackground ? dockWindow.s(Math.round(dockWindow.dockElementSize * 0.14)) : dockWindow.s(2)
            readonly property real indicatorMargin: (!dockWindow.dockAppTileBackground && dockWindow.showRunningIndicators) ? dockWindow.s(5) : iconPadding

            GlassFill {
                id: runningBtnGlass
                anchors.fill: parent
                radius: parent.radius
                visible: dockWindow.dockAppTileBackground
                tintColor: runningDockButton.btnColor
                tintAmount: 0.3
                press: runningBtnMa.pressed ? 1 : Math.max(runningBtnMa.containsMouse ? 0.3 : 0, 0.3 * Math.max(0, Math.min(1, (runningDockButton.baseHoverScale - 1.0) / Math.max(0.01, runningDockButton.hoverScaleDelta))))
                Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }
            transformOrigin: Item.Center
            scale: runningDockButton.targetScale * runningDockButton.popScale

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            SequentialAnimation {
                id: runningBtnPopAnim
                NumberAnimation { target: runningDockButton; property: "popScale"; to: 1.08; duration: 100; easing.type: Easing.OutQuad }
                NumberAnimation { target: runningDockButton; property: "popScale"; to: 1.0; duration: 220; easing.type: Easing.OutQuad }
            }

            Image {
                id: runningAppIcon
                anchors.fill: parent
                anchors.margins: runningBtnShape.iconPadding
                anchors.bottomMargin: dockWindow.dockPosition === "bottom" ? runningBtnShape.indicatorMargin : runningBtnShape.iconPadding
                anchors.topMargin: dockWindow.dockPosition === "top" ? runningBtnShape.indicatorMargin : runningBtnShape.iconPadding
                anchors.leftMargin: dockWindow.dockPosition === "left" ? runningBtnShape.indicatorMargin : runningBtnShape.iconPadding
                anchors.rightMargin: dockWindow.dockPosition === "right" ? runningBtnShape.indicatorMargin : runningBtnShape.iconPadding
                sourceSize: Qt.size(dockWindow.s(dockWindow.dockElementSize * 2), dockWindow.s(dockWindow.dockElementSize * 2))
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
                property bool failedLoad: false
                opacity: (!dockWindow.dockAppTileBackground && runningBtnMa.pressed) ? 0.75 : 1.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
                visible: source !== "" && status === Image.Ready && !failedLoad

                source: {
                    let ic = model.icon || "";
                    if (!ic) return "";
                    if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                    return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
                }
                onStatusChanged: {
                    if (status === Image.Error) failedLoad = true;
                }
            }

            Text {
                anchors.centerIn: parent
                visible: runningAppIcon.source === "" || runningAppIcon.failedLoad || runningAppIcon.status === Image.Error
                text: model.name ? model.name.charAt(0).toUpperCase() : "?"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: dockWindow.s(Math.round(dockWindow.dockElementSize * (dockWindow.dockAppTileBackground ? 0.42 : 0.62)))
                font.weight: Font.Bold
                color: ThemeBackend.text
            }

            Rectangle {
                anchors.fill: parent
                radius: runningDockButton.cornerRadius
                color: "#ffffff"
                visible: dockWindow.dockAppTileBackground
                opacity: runningDockButton.flashOpacity
                PropertyAnimation on opacity {
                    id: runningBtnFlashAnim
                    to: 0
                    duration: 400
                    easing.type: Easing.OutExpo
                }
            }
        }

        Item {
            id: runningIndicatorContainer
            visible: dockWindow.showRunningIndicators && runningDockButton.isAppRunning && !runningDockButton.isClosing
            opacity: (visible && dockContainer.revealProgress > 0.1) ? 1.0 : 0.0

            width: dockWindow.isVertical ? dockWindow.s(4) : runningRow.implicitWidth
            height: dockWindow.isVertical ? runningCol.implicitHeight : dockWindow.s(4)

            x: dockWindow.isVertical
                ? (dockWindow.dockPosition === "left" ? dockWindow.s(2) : Math.round(parent.width - width - dockWindow.s(2)))
                : Math.round((parent.width - width) / 2)
            y: !dockWindow.isVertical
                ? (dockWindow.dockPosition === "top" ? dockWindow.s(2) : Math.round(parent.height - height - dockWindow.s(2)))
                : Math.round((parent.height - height) / 2)

            transform: Translate {
                x: {
                    if (dockWindow.dockPosition === "left") return -runningDockButton.indicatorScaleOffset;
                    if (dockWindow.dockPosition === "right") return runningDockButton.indicatorScaleOffset;
                    return 0;
                }
                y: {
                    if (dockWindow.dockPosition === "bottom") return runningDockButton.indicatorScaleOffset;
                    if (dockWindow.dockPosition === "top") return -runningDockButton.indicatorScaleOffset;
                    return 0;
                }
            }

            Rectangle {
                visible: runningDockButton.isOnlyElsewhere
                anchors.centerIn: parent
                width: dockWindow.s(4)
                height: dockWindow.s(4)
                radius: width / 2
                color: "transparent"
            }

            Rectangle {
                id: runningSinglePill
                visible: !runningDockButton.isOnlyElsewhere && runningDockButton.appWindowCount === 1 && runningDockButton.isAppFocused
                anchors.centerIn: parent
                width: dockWindow.isVertical ? dockWindow.s(3.5) : dockWindow.s(14)
                height: dockWindow.isVertical ? dockWindow.s(14) : dockWindow.s(3.5)
                radius: dockWindow.s(2)
                color: ThemeBackend.mauve
            }

            Row {
                id: runningRow
                visible: !runningDockButton.isOnlyElsewhere && !runningSinglePill.visible && !dockWindow.isVertical
                anchors.centerIn: parent
                spacing: dockWindow.s(2.5)

                Repeater {
                    model: Math.min(3, Math.max(1, runningDockButton.appWindowCount))
                    delegate: Rectangle {
                        width: dockWindow.s(3.5)
                        height: dockWindow.s(3.5)
                        radius: width / 2
                        color: (index === 0 && runningDockButton.isAppFocused) ? ThemeBackend.mauve : (index === 0 ? ThemeBackend.subtext0 : ThemeBackend.surface2)
                    }
                }
            }

            Column {
                id: runningCol
                visible: !runningDockButton.isOnlyElsewhere && !runningSinglePill.visible && dockWindow.isVertical
                anchors.centerIn: parent
                spacing: dockWindow.s(2.5)

                Repeater {
                    model: Math.min(3, Math.max(1, runningDockButton.appWindowCount))
                    delegate: Rectangle {
                        width: dockWindow.s(3.5)
                        height: dockWindow.s(3.5)
                        radius: width / 2
                        color: (index === 0 && runningDockButton.isAppFocused) ? ThemeBackend.mauve : (index === 0 ? ThemeBackend.subtext0 : ThemeBackend.surface2)
                    }
                }
            }
        }

        MouseArea {
            id: runningBtnMa
            anchors.fill: parent
            enabled: !runningDockButton.isClosing
            anchors.margins: -Math.max(dockContainer.itemSpacing / 2, (runningBtnShape.scale - 1.0) * runningDockButton.btnSize / 2)
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onEntered: {
                dockContainer.cancelHoverReset();
                if (dockContainer.clickedItemIndex >= 0) {
                    dockContainer.cancelClickFeedback();
                }
                if (runningDockButton.canHoverScale) {
                    dockContainer.hoveredItemIndex = runningDockButton.itemIndex;
                    dockContainer.hoveredButton = runningDockButton;
                    dockContainer.hoveredAppName = runningDockButton.appName;
                }
            }

            onExited: {
                if (dockContainer.hoveredItemIndex === runningDockButton.itemIndex) {
                    dockContainer.checkHoverReset();
                }
            }

            onClicked: function(mouse) {
                if (mouse.button === Qt.MiddleButton) {
                    runningBtnPopAnim.start();
                    dockContainer.triggerClickFeedback(runningDockButton);
                    dockWindow.launchApp(model.desktop_id);
                    return;
                }
                if (mouse.button === Qt.RightButton) {
                    let pt = runningDockButton.mapToItem(null, 0, 0);
                    let globX = pt.x + (runningDockButton.width / 2);
                    let globY = pt.y + (runningDockButton.height / 2);
                    let info = dockWindow.getRunningInfoForApp(model.desktop_id);
                    let winList = [];
                    if (info) {
                        if (info.here) winList = winList.concat(info.here);
                        if (info.elsewhere) winList = winList.concat(info.elsewhere);
                    }
                    DockAppMenuController.toggle(
                        dockWindow.screen,
                        globX,
                        globY,
                        dockWindow.dockPosition,
                        model.desktop_id,
                        model.name || (info ? info.appId : ""),
                        model.icon || "",
                        false,
                        winList,
                        runningDockButton.width
                    );
                    return;
                }
                if (mouse.button === Qt.LeftButton) {
                    if (typeof DockAppMenuController !== "undefined" && DockAppMenuController.isVisible && !DockAppMenuController.isSameApp(DockAppMenuController.desktopId, model.desktop_id)) {
                        let pt = runningDockButton.mapToItem(null, 0, 0);
                        let globX = pt.x + (runningDockButton.width / 2);
                        let globY = pt.y + (runningDockButton.height / 2);
                        let info = dockWindow.getRunningInfoForApp(model.desktop_id);
                        let winList = [];
                        if (info) {
                            if (info.here) winList = winList.concat(info.here);
                            if (info.elsewhere) winList = winList.concat(info.elsewhere);
                        }
                        DockAppMenuController.show(
                            dockWindow.screen,
                            globX,
                            globY,
                            dockWindow.dockPosition,
                            model.desktop_id,
                            model.name || (info ? info.appId : ""),
                            model.icon || "",
                            false,
                            winList,
                            runningDockButton.width
                        );
                        return;
                    }

                    if (typeof DockAppMenuController !== "undefined" && DockAppMenuController.isVisible && DockAppMenuController.isSameApp(DockAppMenuController.desktopId, model.desktop_id)) {
                        DockAppMenuController.hide();
                    }

                    runningBtnPopAnim.start();
                    dockContainer.triggerClickFeedback(runningDockButton);
                    runningDockButton.flashOpacity = 0.4;
                    runningBtnFlashAnim.start();
                    if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/iconbutton/click.wav");
                    dockWindow.activateOrLaunch(model.desktop_id, mouse.modifiers);
                }
            }
        }
    }
}
