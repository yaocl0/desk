pragma Singleton

import Quickshell
import Quickshell.Services.UPower

// UPower 的 displayDevice 是系统聚合后的"那块电池"，台式机上不存在。
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: root.device?.isLaptopBattery ?? false
    readonly property int percent: Math.round((root.device?.percentage ?? 0) * 100)
    readonly property bool charging: root.device?.state === UPowerDeviceState.Charging
    readonly property bool low: root.percent <= 20 && !root.charging
}
