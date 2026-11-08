import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"

Item {
    id: containerRoot
    required property var dockWindow
    property alias dockHover: dockHover
    property alias dockTransform: dockTransform

    readonly property bool isAttached: !dockWindow.dockFloating && !dockWindow.editMode && !(dockWindow.sameSideAsBar && !dockWindow.isBarSolid)
    property real outerCornerProgress: isAttached ? 1.0 : 0.0

    Behavior on outerCornerProgress {
        enabled: dockWindow.initialized && !dockWindow.positionChanging
        NumberAnimation {
            duration: containerRoot.isAttached ? 240 : 320
            easing.type: containerRoot.isAttached ? Easing.OutQuad : Easing.InQuad
        }
    }

    property real dynamicCornerRadius: (dockWindow.dockFloating || dockWindow.editMode)
        ? ThemeBackend.borderRadius
        : Math.max(0, Math.min(dockWindow.outerCornerRadius, (dockWindow.isVertical ? width : height) * 0.5))

    readonly property real dockSideRadius: dynamicCornerRadius * (1.0 - outerCornerProgress)
    readonly property real topLeftCorner: (dockWindow.dockPosition === "top" || dockWindow.dockPosition === "left") ? dockSideRadius : dynamicCornerRadius
    readonly property real topRightCorner: (dockWindow.dockPosition === "top" || dockWindow.dockPosition === "right") ? dockSideRadius : dynamicCornerRadius
    readonly property real bottomLeftCorner: (dockWindow.dockPosition === "bottom" || dockWindow.dockPosition === "left") ? dockSideRadius : dynamicCornerRadius
    readonly property real bottomRightCorner: (dockWindow.dockPosition === "bottom" || dockWindow.dockPosition === "right") ? dockSideRadius : dynamicCornerRadius
    readonly property bool fanFillets: dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || (dockWindow.isVertical ? width : height) >= dockWindow.outerCornerRadius)

    Behavior on dynamicCornerRadius {
        enabled: dockWindow.initialized && !dockWindow.positionChanging
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    readonly property int placeholderCount: 6
    readonly property int activeRunningAppsCount: {
        if (!dockWindow.showRunningApps || dockWindow.editMode) return 0;
        let count = 0;
        let model = dockWindow.runningAppsModel;
        if (model) {
            for (let i = 0; i < model.count; i++) {
                let it = model.get(i);
                if (it && !it.is_closing) count++;
            }
        }
        return count;
    }
    property int totalItemCount: {
        if (dockWindow.editMode) {
            return dockWindow.dockAppsModel.count > 0 ? dockWindow.dockAppsModel.count : placeholderCount;
        }
        let pinned = dockWindow.dockAppsModel.count;
        let running = activeRunningAppsCount;
        let hasSep = (pinned > 0 && running > 0);
        return pinned + (hasSep ? 1 : 0) + running;
    }
    property int effectiveItemCount: {
        if (dockWindow.enableScrolling && totalItemCount > 0) {
            return Math.min(totalItemCount, Math.max(1, dockWindow.dockVisibleElements));
        }
        return totalItemCount;
    }

    property int scrollIndex: 0
    readonly property int maxScrollIndex: Math.max(0, totalItemCount - effectiveItemCount)

    property int hoveredItemIndex: -1
    property var hoveredButton: null
    property string hoveredAppName: ""

    property int clickedItemIndex: -1
    property var clickedButton: null

    readonly property int effectiveHoveredIndex: {
        if (hoveredItemIndex >= 0) return hoveredItemIndex;
        if (clickedButton !== null && clickedButton.itemIndex !== undefined) return clickedButton.itemIndex;
        if (clickedItemIndex >= 0) return clickedItemIndex;
        return -1;
    }

    Timer {
        id: clickHoldTimer
        interval: 320
        repeat: false
        onTriggered: {
            containerRoot.clickedButton = null;
            containerRoot.clickedItemIndex = -1;
            if (!dockHover.hovered) {
                containerRoot.hoveredItemIndex = -1;
                containerRoot.hoveredButton = null;
                containerRoot.hoveredAppName = "";
            }
        }
    }

    function triggerClickFeedback(btn) {
        if (!btn) return;
        containerRoot.clickedButton = btn;
        containerRoot.clickedItemIndex = btn.itemIndex !== undefined ? btn.itemIndex : -1;
        clickHoldTimer.restart();
    }

    function cancelClickFeedback() {
        containerRoot.clickedButton = null;
        containerRoot.clickedItemIndex = -1;
        clickHoldTimer.stop();
    }

    readonly property bool canShowTooltip: {
        if (!dockWindow.initialized || dockWindow.editMode || dockWindow.positionChanging) return false;
        if (typeof DockAppMenuController !== "undefined" && DockAppMenuController.isVisible) return false;
        if (clickedItemIndex >= 0) return false;
        return hoveredItemIndex >= 0 && hoveredButton !== null && hoveredAppName !== "";
    }

    property bool tooltipPillActive: false

    Timer {
        id: tooltipShowTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (containerRoot.canShowTooltip) {
                containerRoot.tooltipPillActive = true;
            }
        }
    }

    onCanShowTooltipChanged: {
        if (canShowTooltip) {
            if (tooltipPill.opacity > 0.5) {
                tooltipPillActive = true;
            } else {
                tooltipShowTimer.restart();
            }
        } else {
            tooltipShowTimer.stop();
            tooltipPillActive = false;
        }
    }

    Timer {
        id: hoverResetTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (containerRoot.clickedItemIndex < 0) {
                containerRoot.hoveredItemIndex = -1;
                containerRoot.hoveredButton = null;
                containerRoot.hoveredAppName = "";
            }
        }
    }

    function checkHoverReset() {
        hoverResetTimer.restart();
    }

    function cancelHoverReset() {
        hoverResetTimer.stop();
    }

    onTotalItemCountChanged: {
        if (scrollIndex > maxScrollIndex) scrollIndex = maxScrollIndex;
    }
    onEffectiveItemCountChanged: {
        if (scrollIndex > maxScrollIndex) scrollIndex = maxScrollIndex;
    }

    function scrollNext() {
        if (scrollIndex < maxScrollIndex) scrollIndex++;
    }

    function scrollPrev() {
        if (scrollIndex > 0) scrollIndex--;
    }

    WheelHandler {
        id: dockWheelHandler
        target: null
        orientation: Qt.Vertical | Qt.Horizontal
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            if (!dockWindow.enableScrolling) return;
            let dy = (event.angleDelta && event.angleDelta.y !== 0) ? event.angleDelta.y : (event.pixelDelta ? event.pixelDelta.y : 0);
            let dx = (event.angleDelta && event.angleDelta.x !== 0) ? event.angleDelta.x : (event.pixelDelta ? event.pixelDelta.x : 0);
            let delta = Math.abs(dy) >= Math.abs(dx) ? dy : dx;
            if (delta < 0) {
                containerRoot.scrollNext();
            } else if (delta > 0) {
                containerRoot.scrollPrev();
            }
            event.accepted = true;
        }
    }

    property real itemSpacing: dockWindow.editMode ? dockWindow.s(10) : (dockWindow.dockAppTileBackground ? dockWindow.s(8) : 0)
    property real itemSize: dockWindow.s(dockWindow.dockElementSize)
    property real itemStep: itemSize + itemSpacing

    // Menghitung kebutuhan ekstra lebar yang SINKRON 1-to-1 dengan pergeseran animSpread
    readonly property real hoverExpansionLength: {
        if (dockWindow.editMode || effectiveHoveredIndex < 0) return 0.0;
        let delta = Math.max(0.0, dockWindow.dockHoverScaleMultiplier - 1.0);
        if (delta <= 0.001) return 0.0;

        let r0 = (delta * itemSize) / 2.0;
        if (dockWindow.dockCascadeScale) {
            let r1 = r0 * 0.45;
            let r2 = r0 * 0.15;
            // Total pertambahan lebar dock = 2x shift terluar (sisi kiri + sisi kanan)
            let maxShiftOneSide = r0 + (2.0 * r1) + r2;
            return Math.round(2.0 * maxShiftOneSide);
        } else {
            return Math.round(2.0 * r0);
        }
    }

    property real dockContentLength: {
        if (dockWindow.editMode) {
            let cnt = dockWindow.dockAppsModel.count > 0 ? dockWindow.dockAppsModel.count : placeholderCount;
            return cnt * itemSize + Math.max(0, cnt - 1) * itemSpacing;
        }
        let pinned = dockWindow.dockAppsModel.count;
        let running = activeRunningAppsCount;
        let hasSep = (pinned > 0 && running > 0);
        let totalCount = pinned + running + (hasSep ? 1 : 0);
        if (dockWindow.enableScrolling && totalCount > 0) {
            let vis = Math.min(totalCount, Math.max(1, dockWindow.dockVisibleElements));
            return vis * itemSize + Math.max(0, vis - 1) * itemSpacing;
        }
        let sepThickness = dockWindow.s(1);
        let appCount = pinned + running;
        if (appCount === 0) return 0;
        let appsLen = appCount * itemSize;
        let sepLen = hasSep ? sepThickness : 0;
        let spacingsLen = Math.max(0, totalCount - 1) * itemSpacing;
        return appsLen + sepLen + spacingsLen;
    }
    property real dockThickness: itemSize

    property real fullThickness: dockThickness + dockWindow.s(16)
    property real fullContentLength: dockContentLength + dockWindow.s(20) + hoverExpansionLength

    property real baseWidth: Math.round(dockWindow.isVertical ? fullThickness : fullContentLength)
    property real baseHeight: Math.round(dockWindow.isVertical ? fullContentLength : fullThickness)

    Behavior on baseWidth {
        enabled: dockWindow.initialized && !dockWindow.positionChanging
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }
    Behavior on baseHeight {
        enabled: dockWindow.initialized && !dockWindow.positionChanging
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    property real revealProgress: dockWindow.isRevealed ? 1.0 : 0.0
    Behavior on revealProgress {
        enabled: dockWindow.initialized && !dockWindow.positionChanging
        NumberAnimation {
            duration: dockWindow.isRevealed ? 240 : 180
            easing.type: dockWindow.isRevealed ? Easing.OutCubic : Easing.InCubic
        }
    }

    width: (dockWindow.sameSideAsBar && dockWindow.isVertical)
        ? Math.round(baseWidth * revealProgress)
        : baseWidth

    height: (dockWindow.sameSideAsBar && !dockWindow.isVertical)
        ? Math.round(baseHeight * revealProgress)
        : baseHeight

    x: {
        if (!dockWindow.isVertical) return Math.round((dockWindow.effectiveWindowWidth - width) / 2);
        if (dockWindow.dockPosition === "left") {
            return Math.round(dockWindow.barOffset + dockWindow.effectiveMargin);
        }
        if (dockWindow.dockPosition === "right") {
            return Math.round(dockWindow.effectiveWindowWidth - width - dockWindow.barOffset - dockWindow.effectiveMargin);
        }
        return Math.round((dockWindow.effectiveWindowWidth - width) / 2);
    }

    y: {
        if (dockWindow.isVertical) return Math.round((dockWindow.effectiveWindowHeight - height) / 2);
        if (dockWindow.dockPosition === "top") {
            return Math.round(dockWindow.barOffset + dockWindow.effectiveMargin);
        }
        if (dockWindow.dockPosition === "bottom") {
            return Math.round(dockWindow.effectiveWindowHeight - height - dockWindow.barOffset - dockWindow.effectiveMargin);
        }
        return Math.round((dockWindow.effectiveWindowHeight - height) / 2);
    }

    property real hideOffset: {
        if (dockWindow.isVertical) {
            let dist = width + dockWindow.barOffset + dockWindow.effectiveMargin + dockWindow.s(20);
            return dockWindow.dockPosition === "left" ? -dist : dist;
        } else {
            let dist = height + dockWindow.barOffset + dockWindow.effectiveMargin + dockWindow.s(20);
            return dockWindow.dockPosition === "top" ? -dist : dist;
        }
    }

    property real posAnimProgress: 1.0
    opacity: posAnimProgress

    readonly property real posOffsetDistance: {
        if (dockWindow.isVertical) {
            return width + dockWindow.barOffset + dockWindow.effectiveMargin + dockWindow.s(40);
        } else {
            return height + dockWindow.barOffset + dockWindow.effectiveMargin + dockWindow.s(40);
        }
    }

    readonly property real posTransitionOffsetX: {
        if (posAnimProgress >= 0.999) return 0;
        let dist = (1.0 - posAnimProgress) * posOffsetDistance;
        if (dockWindow.dockPosition === "left") return -dist;
        if (dockWindow.dockPosition === "right") return dist;
        return 0;
    }

    readonly property real posTransitionOffsetY: {
        if (posAnimProgress >= 0.999) return 0;
        let dist = (1.0 - posAnimProgress) * posOffsetDistance;
        if (dockWindow.dockPosition === "top") return -dist;
        if (dockWindow.dockPosition === "bottom") return dist;
        return 0;
    }

    SequentialAnimation {
        id: posTransitionSeq
        property string pendingPos: ""

        NumberAnimation {
            target: containerRoot
            property: "posAnimProgress"
            to: 0.0
            duration: 180
            easing.type: Easing.InQuad
        }

        ScriptAction {
            script: {
                dockWindow.dockPosition = posTransitionSeq.pendingPos;
                containerRoot.scrollIndex = 0;
                containerRoot.hoveredItemIndex = -1;
                containerRoot.cancelClickFeedback();
            }
        }

        PauseAnimation { duration: 25 }

        NumberAnimation {
            target: containerRoot
            property: "posAnimProgress"
            to: 1.0
            duration: 260
            easing.type: Easing.OutQuint
        }
    }

    function startPositionTransition(newPos) {
        if (!dockWindow.initialized) {
            dockWindow.dockPosition = newPos;
            return;
        }
        posTransitionSeq.pendingPos = newPos;
        posTransitionSeq.restart();
    }

    transform: [
        Translate {
            id: dockTransform
            x: (!dockWindow.sameSideAsBar && dockWindow.isVertical) ? (dockWindow.isRevealed ? 0 : containerRoot.hideOffset) : 0
            y: (!dockWindow.sameSideAsBar && !dockWindow.isVertical) ? (dockWindow.isRevealed ? 0 : containerRoot.hideOffset) : 0

            Behavior on x {
                enabled: dockWindow.initialized && !dockWindow.positionChanging && !dockWindow.sameSideAsBar
                NumberAnimation { duration: 280; easing.type: Easing.OutQuint }
            }
            Behavior on y {
                enabled: dockWindow.initialized && !dockWindow.positionChanging && !dockWindow.sameSideAsBar
                NumberAnimation { duration: 280; easing.type: Easing.OutQuint }
            }
        },
        Translate {
            id: posTransitionTransform
            x: containerRoot.posTransitionOffsetX
            y: containerRoot.posTransitionOffsetY
        }
    ]

    HoverHandler {
        id: dockHover
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        margin: dockWindow.effectiveHoverExpansion
        onHoveredChanged: {
            if (!hovered) {
                if (containerRoot.clickedItemIndex < 0) {
                    containerRoot.hoveredItemIndex = -1;
                    containerRoot.cancelHoverReset();
                }
            }
        }
    }

    function calculateDropIndex(mx, my) {
        if (dockWindow.dockAppsModel.count <= 1) return 0;
        let spacing = itemSpacing;
        let size = itemSize;
        let step = size + spacing;
        if (dockWindow.isVertical) {
            let layoutY = dockViewport.y + dockLayout.y;
            let relY = my - layoutY;
            let idx = Math.floor((relY + spacing / 2) / step);
            return Math.max(0, Math.min(dockWindow.dockAppsModel.count - 1, idx));
        } else {
            let layoutX = dockViewport.x + dockLayout.x;
            let relX = mx - layoutX;
            let idx = Math.floor((relX + spacing / 2) / step);
            return Math.max(0, Math.min(dockWindow.dockAppsModel.count - 1, idx));
        }
    }

    GlassFillets {
        id: dockFillets
        card: dockBg
        surfaceEnabled: dockWindow.dockBackground && filletRadius > 0.5
        opacity: (dockWindow.sameSideAsBar ? containerRoot.revealProgress : 1.0) * (ThemeBackend.liquidGlass ? 1.0 : containerRoot.outerCornerProgress)
        filletRadius: !containerRoot.fanFillets ? 0 : (ThemeBackend.liquidGlass ? dockWindow.outerCornerRadius * containerRoot.outerCornerProgress : (containerRoot.outerCornerProgress > 0.001 ? dockWindow.outerCornerRadius : 0))
        filletDir: dockWindow.dockPosition === "bottom" ? Qt.vector2d(0, 1)
                 : dockWindow.dockPosition === "top" ? Qt.vector2d(0, -1)
                 : dockWindow.dockPosition === "left" ? Qt.vector2d(-1, 0)
                 : Qt.vector2d(1, 0)
    }

    Item {
        anchors.fill: parent
        visible: dockWindow.dockBackground

        WallpaperBlur {
            anchors.fill: parent
            topLeftRadius: containerRoot.topLeftCorner
            topRightRadius: containerRoot.topRightCorner
            bottomLeftRadius: containerRoot.bottomLeftCorner
            bottomRightRadius: containerRoot.bottomRightCorner
            surfaceEnabled: dockWindow.dockBackground
            filletRadius: dockFillets.filletRadius
            filletDir: dockFillets.filletDir
        }
    }

    Item {
        id: dockBgWrapper
        anchors.fill: parent
        opacity: dockWindow.dockOpacity
        layer.enabled: dockWindow.dockOpacity < 1.0

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {
                if (typeof DockAppMenuController !== "undefined" && DockAppMenuController.isVisible) {
                    DockAppMenuController.hide();
                }
            }
        }

        Rectangle {
            id: dockBg
            anchors.fill: parent
            radius: containerRoot.dynamicCornerRadius
            topLeftRadius: containerRoot.topLeftCorner
            topRightRadius: containerRoot.topRightCorner
            bottomLeftRadius: containerRoot.bottomLeftCorner
            bottomRightRadius: containerRoot.bottomRightCorner
            color: ThemeBackend.liquidGlass ? "transparent" : ThemeBackend.base
            clip: true

        }
    }

    ShaderEffect {
        visible: !ThemeBackend.liquidGlass && containerRoot.outerCornerProgress > 0.001 && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || (dockWindow.isVertical ? containerRoot.width : containerRoot.height) >= dockWindow.outerCornerRadius)
        opacity: containerRoot.outerCornerProgress * (dockWindow.sameSideAsBar ? containerRoot.revealProgress : 1.0)
        x: {
            if (dockWindow.dockPosition === "left") return 0;
            if (dockWindow.dockPosition === "right") return containerRoot.width - dockWindow.outerCornerRadius;
            return -dockWindow.outerCornerRadius;
        }
        y: {
            if (dockWindow.dockPosition === "bottom") return containerRoot.height - dockWindow.outerCornerRadius;
            if (dockWindow.dockPosition === "left" || dockWindow.dockPosition === "right") return -dockWindow.outerCornerRadius;
            return 0;
        }
        width: dockWindow.outerCornerRadius
        height: dockWindow.outerCornerRadius
        property vector2d itemSize: Qt.vector2d(width, height)
        property real cornerIndex: {
            if (dockWindow.dockPosition === "bottom") return 3.0;
            if (dockWindow.dockPosition === "left") return 2.0;
            if (dockWindow.dockPosition === "right") return 3.0;
            return 1.0; // top
        }
        property color color: Qt.alpha(ThemeBackend.base, dockWindow.dockOpacity)
        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
    }

    ShaderEffect {
        visible: !ThemeBackend.liquidGlass && containerRoot.outerCornerProgress > 0.001 && dockWindow.outerCornerRadius > 0.5 && (!dockWindow.sameSideAsBar || (dockWindow.isVertical ? containerRoot.width : containerRoot.height) >= dockWindow.outerCornerRadius)
        opacity: containerRoot.outerCornerProgress * (dockWindow.sameSideAsBar ? containerRoot.revealProgress : 1.0)
        x: {
            if (dockWindow.dockPosition === "left") return 0;
            if (dockWindow.dockPosition === "right") return containerRoot.width - dockWindow.outerCornerRadius;
            return containerRoot.width;
        }
        y: {
            if (dockWindow.dockPosition === "bottom") return containerRoot.height - dockWindow.outerCornerRadius;
            if (dockWindow.dockPosition === "left" || dockWindow.dockPosition === "right") return containerRoot.height;
            return 0;
        }
        width: dockWindow.outerCornerRadius
        height: dockWindow.outerCornerRadius
        property vector2d itemSize: Qt.vector2d(width, height)
        property real cornerIndex: {
            if (dockWindow.dockPosition === "bottom") return 2.0;
            if (dockWindow.dockPosition === "left") return 0.0;
            if (dockWindow.dockPosition === "right") return 1.0;
            return 0.0; // top
        }
        property color color: Qt.alpha(ThemeBackend.base, dockWindow.dockOpacity)
        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
    }

    Item {
        id: dockContentClipper
        anchors.fill: parent
        clip: dockWindow.sameSideAsBar && containerRoot.revealProgress < 0.999
        opacity: dockWindow.sameSideAsBar ? containerRoot.revealProgress : 1.0
        visible: !dockWindow.sameSideAsBar || containerRoot.revealProgress > 0.001

        Item {
            id: dockViewport
            x: Math.round((containerRoot.width - width) / 2)
            y: Math.round((containerRoot.height - height) / 2)

            width: dockWindow.isVertical ? Math.round(containerRoot.dockThickness + dockWindow.s(16) + dockWindow.hoverExpansion * 2) : Math.max(0, containerRoot.width - dockWindow.s(20))
            height: dockWindow.isVertical ? Math.max(0, containerRoot.height - dockWindow.s(20)) : Math.round(containerRoot.dockThickness + dockWindow.s(16) + dockWindow.hoverExpansion * 2)
            clip: dockWindow.enableScrolling && (containerRoot.totalItemCount > containerRoot.effectiveItemCount)
            visible: width > 0 && height > 0

            GridLayout {
                id: dockLayout
                columns: dockWindow.isVertical ? 1 : Math.max(1, dockWindow.dockAppsModel.count + (dockWindow.showRunningApps ? dockWindow.runningAppsModel.count : 0) + 2)
                rows: dockWindow.isVertical ? Math.max(1, dockWindow.dockAppsModel.count + (dockWindow.showRunningApps ? dockWindow.runningAppsModel.count : 0) + 2) : 1
                columnSpacing: containerRoot.itemSpacing
                rowSpacing: containerRoot.itemSpacing
                width: implicitWidth
                height: implicitHeight

                Behavior on columnSpacing {
                    enabled: dockWindow.initialized && !dockWindow.positionChanging
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }
                Behavior on rowSpacing {
                    enabled: dockWindow.initialized && !dockWindow.positionChanging
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }

                x: {
                    if (dockWindow.isVertical) {
                        return Math.round((dockViewport.width - width) / 2);
                    }
                    if (!dockWindow.enableScrolling || containerRoot.totalItemCount <= containerRoot.effectiveItemCount) {
                        return Math.round((dockViewport.width - width) / 2);
                    }
                    return Math.round(-containerRoot.scrollIndex * containerRoot.itemStep);
                }

                y: {
                    if (!dockWindow.isVertical) {
                        return Math.round((dockViewport.height - height) / 2);
                    }
                    if (!dockWindow.enableScrolling || containerRoot.totalItemCount <= containerRoot.effectiveItemCount) {
                        return Math.round((dockViewport.height - height) / 2);
                    }
                    return Math.round(-containerRoot.scrollIndex * containerRoot.itemStep);
                }

                Behavior on x {
                    enabled: dockWindow.initialized && dockWindow.enableScrolling && containerRoot.revealProgress >= 0.99 && !dockWindow.positionChanging
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }
                Behavior on y {
                    enabled: dockWindow.initialized && dockWindow.enableScrolling && containerRoot.revealProgress >= 0.99 && !dockWindow.positionChanging
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }

                Repeater {
                    model: dockWindow.dockAppsModel

                    delegate: DockAppButton {
                        dockWindow: containerRoot.dockWindow
                        dockContainer: containerRoot
                    }
                }

                Item {
                    id: dockSeparator
                    property real sepProgress: (dockWindow.showRunningApps && containerRoot.activeRunningAppsCount > 0 && dockWindow.dockAppsModel.count > 0 && !dockWindow.editMode) ? 1.0 : 0.0
                    Behavior on sepProgress {
                        enabled: dockWindow.initialized && !dockWindow.positionChanging
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    visible: dockWindow.showRunningApps && (containerRoot.activeRunningAppsCount > 0 || sepProgress > 0.01 || dockWindow.runningAppsModel.count > 0) && dockWindow.dockAppsModel.count > 0 && !dockWindow.editMode
                    Layout.preferredWidth: visible ? (dockWindow.isVertical ? dockWindow.s(dockWindow.dockElementSize) : Math.round(dockWindow.s(1) * sepProgress)) : 0
                    Layout.preferredHeight: visible ? (dockWindow.isVertical ? Math.round(dockWindow.s(1) * sepProgress) : dockWindow.s(dockWindow.dockElementSize)) : 0
                    Layout.maximumWidth: visible ? -1 : 0
                    Layout.maximumHeight: visible ? -1 : 0
                    Layout.alignment: Qt.AlignCenter

                    readonly property int itemIndex: dockWindow.dockAppsModel.count
                    readonly property real maxHoverScale: dockWindow.dockHoverScaleMultiplier
                    readonly property real hoverScaleDelta: Math.max(0.0, maxHoverScale - 1.0)
                    readonly property int btnSize: dockWindow.s(dockWindow.dockElementSize)

                    property real animSpread: {
                        if (dockWindow.editMode || containerRoot.effectiveHoveredIndex < 0) return 0.0;
                        let diff = itemIndex - containerRoot.effectiveHoveredIndex;
                        if (diff === 0) return 0.0;
                        let sign = diff > 0 ? 1.0 : -1.0;
                        let d = Math.abs(diff);

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

                    property real targetOffsetX: !dockWindow.isVertical ? animSpread : 0.0
                    property real targetOffsetY: dockWindow.isVertical ? animSpread : 0.0

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
                        id: sepFloatWrapper
                        anchors.fill: parent
                        opacity: dockSeparator.sepProgress
                        transform: Translate {
                            x: dockSeparator.currentOffsetX
                            y: dockSeparator.currentOffsetY
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: dockWindow.isVertical ? Math.round(dockWindow.s(dockWindow.dockElementSize) * 0.5) : 1
                            height: dockWindow.isVertical ? 1 : Math.round(dockWindow.s(dockWindow.dockElementSize) * 0.5)
                            radius: 1
                            color: Qt.alpha(ThemeBackend.surface2, 0.7)
                        }
                    }
                }

                Repeater {
                    id: runningAppsRepeater
                    model: (dockWindow.showRunningApps && !dockWindow.editMode) ? dockWindow.runningAppsModel : null

                    delegate: DockRunningButton {
                        dockWindow: containerRoot.dockWindow
                        dockContainer: containerRoot
                    }
                }
            }
        }
    }

    Rectangle {
        id: tooltipPill
        z: 9999
        visible: opacity > 0.001
        enabled: false

        readonly property real pillGap: dockWindow.s(10)

        readonly property real btnCenterX: {
            if (!containerRoot.hoveredButton) return containerRoot.width / 2;
            return dockViewport.x + dockLayout.x + containerRoot.hoveredButton.x + (containerRoot.hoveredButton.width / 2) + containerRoot.hoveredButton.currentOffsetX;
        }

        readonly property real btnCenterY: {
            if (!containerRoot.hoveredButton) return containerRoot.height / 2;
            return dockViewport.y + dockLayout.y + containerRoot.hoveredButton.y + (containerRoot.hoveredButton.height / 2) + containerRoot.hoveredButton.currentOffsetY;
        }

        readonly property real curScale: {
            if (!containerRoot.hoveredButton) return 1.0;
            return (containerRoot.hoveredButton.visualScale !== undefined && containerRoot.hoveredButton.visualScale > 0)
                ? containerRoot.hoveredButton.visualScale
                : (containerRoot.hoveredButton.targetScale || 1.0);
        }

        readonly property real curBtnSize: containerRoot.hoveredButton ? containerRoot.hoveredButton.btnSize : dockWindow.s(dockWindow.dockElementSize)
        readonly property real scaleSideExpansion: (curBtnSize * Math.max(0.0, curScale - 1.0)) / 2

        property real targetX: {
            if (dockWindow.isVertical) {
                if (dockWindow.dockPosition === "left") {
                    let slotRight = dockViewport.x + dockLayout.x + (containerRoot.hoveredButton ? containerRoot.hoveredButton.x : 0) + curBtnSize;
                    let visualRight = slotRight + (containerRoot.hoveredButton ? containerRoot.hoveredButton.currentOffsetX : 0) + scaleSideExpansion;
                    let effectiveRight = Math.max(containerRoot.width, visualRight);
                    return effectiveRight + pillGap;
                } else {
                    let slotLeft = dockViewport.x + dockLayout.x + (containerRoot.hoveredButton ? containerRoot.hoveredButton.x : 0);
                    let visualLeft = slotLeft + (containerRoot.hoveredButton ? containerRoot.hoveredButton.currentOffsetX : 0) - scaleSideExpansion;
                    let effectiveLeft = Math.min(0, visualLeft);
                    return effectiveLeft - width - pillGap;
                }
            }
            let rawX = btnCenterX - (width / 2);
            let minX = -containerRoot.x + dockWindow.s(12);
            let maxX = dockWindow.effectiveWindowWidth - containerRoot.x - width - dockWindow.s(12);
            return Math.max(minX, Math.min(maxX, rawX));
        }

        property real targetY: {
            if (dockWindow.isVertical) {
                let rawY = btnCenterY - (height / 2);
                let minY = -containerRoot.y + dockWindow.s(12);
                let maxY = dockWindow.effectiveWindowHeight - containerRoot.y - height - dockWindow.s(12);
                return Math.max(minY, Math.min(maxY, rawY));
            }
            if (dockWindow.dockPosition === "top") {
                let slotBottom = dockViewport.y + dockLayout.y + (containerRoot.hoveredButton ? containerRoot.hoveredButton.y : 0) + curBtnSize;
                let visualBottom = slotBottom + (containerRoot.hoveredButton ? containerRoot.hoveredButton.currentOffsetY : 0) + scaleSideExpansion;
                let effectiveBottom = Math.max(containerRoot.height, visualBottom);
                return effectiveBottom + pillGap;
            } else {
                let slotTop = dockViewport.y + dockLayout.y + (containerRoot.hoveredButton ? containerRoot.hoveredButton.y : 0);
                let visualTop = slotTop + (containerRoot.hoveredButton ? containerRoot.hoveredButton.currentOffsetY : 0) - scaleSideExpansion;
                let effectiveTop = Math.min(0, visualTop);
                return effectiveTop - height - pillGap;
            }
        }

        x: targetX
        y: targetY

        implicitWidth: Math.min(dockWindow.s(220), labelText.implicitWidth + dockWindow.s(22))
        Behavior on implicitWidth {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        implicitHeight: dockWindow.s(26)
        radius: dockWindow.s(7)
        color: Qt.alpha(ThemeBackend.mantle, 0.88)
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.surface2, 0.5)

        opacity: containerRoot.tooltipPillActive ? 1.0 : 0.0
        scale: containerRoot.tooltipPillActive ? 1.0 : 0.90

        Behavior on opacity {
            NumberAnimation { duration: containerRoot.tooltipPillActive ? 150 : 100; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: containerRoot.tooltipPillActive ? 150 : 100; easing.type: Easing.OutCubic }
        }

        Text {
            id: labelText
            anchors.centerIn: parent
            text: containerRoot.hoveredAppName
            color: ThemeBackend.text
            font.family: ThemeBackend.fontFamily || "Inter"
            font.pixelSize: dockWindow.s(12)
            font.weight: Font.Medium
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            width: Math.min(implicitWidth, tooltipPill.width - dockWindow.s(16))
        }
    }
}
