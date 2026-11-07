pragma Singleton
import QtQuick
import Quickshell

Item {
    id: controller

    signal commandRequested(string cmd, string targetWidget, string arg)
    signal closeRequested()

    property string currentActive: "hidden"
    property string activeArg: ""
    property bool isVisible: false

    function handleCommand(cmd, targetWidget, arg) {
        let c = cmd !== undefined && cmd !== null ? String(cmd).trim() : "";
        let t = targetWidget !== undefined && targetWidget !== null ? String(targetWidget).trim() : "";
        let a = arg !== undefined && arg !== null ? String(arg).trim() : "";
        controller.commandRequested(c, t, a);
    }

    function toggle(targetWidget, arg) {
        controller.handleCommand("toggle", targetWidget, arg);
    }

    function open(targetWidget, arg) {
        controller.handleCommand("open", targetWidget, arg);
    }

    function close() {
        controller.handleCommand("close", "", "");
        controller.closeRequested();
    }

    function clearNotifications() {
        controller.handleCommand("notifications", "clear", "");
    }

    function toggleAirplaneMode() {
        controller.handleCommand("network", "airplane", "");
    }

    function toggleBarAutohide() {
        controller.handleCommand("bar", "autohide", "");
    }
}
