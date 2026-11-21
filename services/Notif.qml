pragma Singleton

import Quickshell
import Quickshell.Services.Notifications

// 通知服务端。Quickshell 要求在 onNotification 里把 tracked 置 true，
// 否则通知对象发完就被丢弃。
Singleton {
    id: root

    property bool dnd: false
    readonly property int historyLimit: 50

    readonly property var active: server.trackedNotifications.values
    property var history: []

    function clearHistory() {
        root.history = [];
    }

    function dismissAll() {
        for (const n of [...root.active])
            n.dismiss();
    }

    NotificationServer {
        id: server

        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = !root.dnd;

            root.history = [
                {
                    appName: n.appName,
                    summary: n.summary,
                    body: n.body,
                    urgency: n.urgency,
                    time: Date.now()
                },
                ...root.history
            ].slice(0, root.historyLimit);
        }
    }
}
