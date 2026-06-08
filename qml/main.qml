import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts
import VertexStore

ApplicationWindow {
    id: root
    visible: true
    width: 1200
    height: 780
    minimumWidth: 900
    minimumHeight: 600
    title: "Vertex Store"

    color: Theme.bg

    property var taskList: []
    property bool showTaskQueue: false

    // Package detail overlay state
    property var  selectedPkg: null
    property bool showDetail: false

    function openPackageDetail(pkg) {
        selectedPkg = pkg
        showDetail  = true
        backend.get_package_details(pkg.name, pkg.source, pkg.app_id || pkg.name)
    }

    // Global confirmation dialog state
    property bool   confirmVisible: false
    property string confirmTitle: ""
    property string confirmMessage: ""
    property string confirmLabel: "Confirm"
    property bool   confirmDestructive: true
    property var    confirmCallback: null

    function askConfirm(title, message, callback, label, destructive) {
        confirmTitle       = title
        confirmMessage     = message
        confirmCallback    = callback
        confirmLabel       = label       !== undefined ? label       : "Confirm"
        confirmDestructive = destructive !== undefined ? destructive : true
        confirmVisible     = true
    }

    // Poll backend for async results every 200ms
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: backend.poll_events()
    }

    StoreBackend {
        id: backend

        onSearch_results_ready: (json) => {
            searchPage.loadResults(json)
        }
        onInstalled_ready: (json) => {
            installedPage.loadPackages(json)
        }
        onUpdates_ready: (json) => {
            updatesPage.loadUpdates(json)
        }
        onOperation_complete: (success, message) => {
            toast.show(message, success)
            if (nav.currentIndex === 1) backend.get_installed()
            if (nav.currentIndex === 2) backend.get_updates()
        }
        onTasks_updated: (json) => {
            try { root.taskList = JSON.parse(json) } catch(e) { root.taskList = [] }
        }

        Component.onCompleted: {
            load_config()
            Theme.apply(String(theme_name))
        }

        onTheme_nameChanged: Theme.apply(String(theme_name))
    }

    // Refresh page data when navigating
    Connections {
        target: nav
        function onCurrentIndexChanged() {
            if (nav.currentIndex === 1) installedPage.refresh()
            if (nav.currentIndex === 2) updatesPage.refresh()
        }
    }

    // ── Toast notification ─────────────────────────────────────────────────────
    Popup {
        id: toast
        x: root.width - width - 24
        y: root.height - height - 24
        width: 340; height: 60
        padding: 0; modal: false
        closePolicy: Popup.NoAutoClose

        property bool isSuccess: true
        property string msg: ""

        function show(message, success) {
            msg = message; isSuccess = success; open(); toastTimer.restart()
        }

        Timer { id: toastTimer; interval: 4000; onTriggered: toast.close() }

        background: Rectangle {
            radius: Theme.radiusMd
            color: toast.isSuccess ? Theme.success : Theme.danger
            opacity: 0.95
        }
        contentItem: RowLayout {
            anchors.fill: parent; anchors.margins: 14; spacing: 10
            Text { text: toast.isSuccess ? "✓" : "✗"; color: "white"; font.pixelSize: 18; font.bold: true }
            Text {
                Layout.fillWidth: true
                text: toast.msg; color: "white"; font.pixelSize: Theme.fontMd
                wrapMode: Text.WordWrap; elide: Text.ElideRight; maximumLineCount: 2
            }
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }
        exit:  Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 200 } }
    }

    // ── Main layout ────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        SideBar {
            id: nav
            Layout.fillHeight: true
            activeTasks: backend.active_task_count
            totalTasks: root.taskList.length
            onQueueClicked: root.showTaskQueue = true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.bg

            StackLayout {
                anchors.fill: parent
                currentIndex: nav.currentIndex
                enabled: !root.showDetail

                HomePage {
                    id: homePage
                    backend: backend
                    onNavigateTo: (idx) => nav.currentIndex = idx
                    onSearchRequested: (q) => { nav.currentIndex = 3; searchPage.startSearch(q) }
                }
                InstalledPage { id: installedPage; backend: backend; confirmFn: root.askConfirm; openDetail: root.openPackageDetail }
                UpdatesPage   { id: updatesPage;   backend: backend; confirmFn: root.askConfirm; openDetail: root.openPackageDetail }
                SearchPage    { id: searchPage;    backend: backend; confirmFn: root.askConfirm; openDetail: root.openPackageDetail }
                SettingsPage  { id: settingsPage;  backend: backend }
            }
        }
    }

    // ── Package detail overlay ─────────────────────────────────────────────────
    PackageDetailPage {
        id: detailPage
        anchors.fill: parent
        z: 50
        backend: backend
        pkg: root.selectedPkg
        visible: opacity > 0
        opacity: root.showDetail ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        onClosed: root.showDetail = false

        onInstallRequested: (src) => {
            root.showDetail = false
            backend.install_package(root.selectedPkg.app_id || root.selectedPkg.name, src)
        }
        onRemoveRequested: {
            var nm = root.selectedPkg.name
            var id = root.selectedPkg.app_id || root.selectedPkg.name
            var src = root.selectedPkg.source
            root.askConfirm(
                "Remove " + nm + "?",
                "This will uninstall " + nm + " from your system.",
                function() { root.showDetail = false; backend.remove_package(id, src) }
            )
        }
    }

    // ── Search/fetch loading overlay ───────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: backend.is_loading
        z: 100

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            LoadingSpinner {
                size: 48; color: Theme.accent
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: backend.status_message || "Loading..."
                color: Theme.textPri; font.pixelSize: Theme.fontLg
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // ── Confirmation dialog ────────────────────────────────────────────────────
    ConfirmDialog {
        anchors.fill: parent
        z: 300
        visible: root.confirmVisible
        title: root.confirmTitle
        message: root.confirmMessage
        confirmLabel: root.confirmLabel
        destructive: root.confirmDestructive
        onAccepted: {
            root.confirmVisible = false
            if (root.confirmCallback) root.confirmCallback()
        }
        onRejected: root.confirmVisible = false
    }

    // ── Task queue full-screen overlay ─────────────────────────────────────────
    TaskQueueOverlay {
        id: taskOverlay
        anchors.fill: parent
        z: 200
        visible: root.showTaskQueue
        tasks: root.taskList
        backend: backend
        onClosed: root.showTaskQueue = false

        // Fade in/out
        opacity: root.showTaskQueue ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }
}
