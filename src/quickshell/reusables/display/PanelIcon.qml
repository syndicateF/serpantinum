import QtQuick
import Qt5Compat.GraphicalEffects
Item {
    id: root
    property string icon: ""
    property color color: "#ffffff"
    property int size: 16
    property bool smooth: true
    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    readonly property string iconSource: {
        if (!root.icon || root.icon === "") return "";
        if (root.icon.startsWith("/") || root.icon.startsWith("file://") || root.icon.startsWith("image://")) {
            return root.icon;
        }
        return "image://icon/" + root.icon;
    }
    Image {
        id: img
        anchors.fill: parent
        source: root.iconSource
        sourceSize: Qt.size(root.size, root.size)
        asynchronous: false
        smooth: root.smooth
        visible: false
    }
    ColorOverlay {
        id: overlay
        anchors.fill: img
        source: img
        color: root.color
        visible: root.iconSource !== ""
        Behavior on color { ColorAnimation { duration: 150 } }
    }
}
