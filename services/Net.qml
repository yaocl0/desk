pragma Singleton

import Quickshell
import Quickshell.Networking

// 网络状态。走 Quickshell 自带的 NetworkManager 后端，不解析 nmcli。
Singleton {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null

    readonly property bool wiredUp: root.wiredDevice?.connected ?? false
    readonly property bool wifiUp: root.wifiDevice?.connected ?? false
    readonly property bool connected: root.wiredUp || root.wifiUp

    // 有线优先：插着网线时无线强度没意义
    readonly property string kind: root.wiredUp ? "wired" : root.wifiUp ? "wifi" : "none"

    readonly property var activeWifi: root.wifiDevice?.networks?.values?.find(n => n.connected) ?? null
    readonly property string ssid: root.activeWifi?.name ?? ""

    // signalStrength 是 0–1
    readonly property real signal: root.activeWifi?.signalStrength ?? 0
    readonly property int signalLevel: Math.max(0, Math.min(4, Math.ceil(root.signal * 4)))

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property string address: (root.wiredUp ? root.wiredDevice?.address : root.wifiDevice?.address) ?? ""
}
