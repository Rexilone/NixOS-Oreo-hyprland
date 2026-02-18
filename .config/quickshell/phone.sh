import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root
    
    // ==================== Процессы для выполнения команд ====================
    Process {
        id: adbConnectProcess
        property string targetIp: ""
        command: targetIp ? ["adb", "connect", targetIp] : []
        running: false
        
        onExited: {
            adbCheckDelayTimer.start()
        }
    }
    
    Process {
        id: adbCheckReadProcess
        command: ["sh", "-c", "adb devices 2>/dev/null | tail -n +2 | grep -v '^$' | wc -l"]
        running: false
        
        property string outputBuffer: ""
        
        stdout: SplitParser {
            onRead: data => {
                adbCheckReadProcess.outputBuffer += data
            }
        }
        
        onExited: code => {
            const count = parseInt(outputBuffer.trim())
            phoneManager.adbConnected = count > 0
            console.log("ADB devices count:", count)
            outputBuffer = ""
        }
    }
    
    Process {
        id: batteryProcess
        command: ["sh", "-c", "adb shell dumpsys battery 2>/dev/null | grep 'level:' | awk '{print $2}'"]
        running: false
        
        property string outputBuffer: ""
        
        stdout: SplitParser {
            onRead: data => {
                batteryProcess.outputBuffer += data
            }
        }
        
        onExited: {
            const level = parseInt(outputBuffer.trim())
            if (!isNaN(level) && level >= 0 && level <= 100) {
                phoneManager.batteryLevel = level
                console.log("Battery:", level + "%")
            }
            outputBuffer = ""
        }
    }
    
    Process {
        id: notificationProcess
        command: ["kdeconnect-cli", "-a", "--list-notifications"]
        running: false
        
        stdout: SplitParser {
            onRead: data => {
                const lines = data.trim().split('\n')
                if (lines.length > 0 && lines[0] !== "") {
                    phoneManager.lastNotification = lines[lines.length - 1]
                }
            }
        }
    }
    
    Process {
        id: scrcpyProcess
        command: ["scrcpy", "-e", "-S", "-m", "1920", "--max-fps", "60", 
                 "--video-bit-rate", "8M", "--render-driver=opengl", 
                 "--window-title", "phone"]
        running: false
        
        onRunningChanged: {
            if (running) {
                scrcpyCheckDelayTimer.start()
            }
        }
    }
    
    Process {
        id: clipboardProcess
        command: ["sh", "-c", "wl-paste | adb shell input text \"$(cat)\""]
        running: false
    }
    
    Process {
        id: hyprlandClientsProcess
        command: ["sh", "-c", "hyprctl clients 2>/dev/null | grep -i 'title: phone'"]
        running: false
        
        property string outputBuffer: ""
        
        stdout: SplitParser {
            onRead: data => {
                hyprlandClientsProcess.outputBuffer += data
            }
        }
        
        onExited: {
            phoneManager.scrcpyActive = outputBuffer.trim().length > 0
            console.log("Scrcpy active:", phoneManager.scrcpyActive)
            outputBuffer = ""
        }
    }
    
    // Процесс для загрузки IP
    Process {
        id: loadIpsProcess
        command: ["cat", Quickshell.env("HOME") + "/.config/quickshell/phone-ips.json"]
        running: false
        
        property string outputBuffer: ""
        
        stdout: SplitParser {
            onRead: data => {
                loadIpsProcess.outputBuffer += data
            }
        }
        
        onExited: code => {
            if (code === 0 && outputBuffer.trim().length > 0) {
                try {
                    const ips = JSON.parse(outputBuffer)
                    if (Array.isArray(ips)) {
                        ipListModel.clear()
                        ips.forEach(ip => ipListModel.append({"ip": ip}))
                        console.log("Loaded", ips.length, "IPs")
                    }
                } catch(e) {
                    console.log("Error parsing saved IPs:", e)
                }
            }
            outputBuffer = ""
        }
    }
    
    // Функция сохранения IP
    function saveIps() {
        let ips = []
        for (let i = 0; i < ipListModel.count; i++) {
            ips.push(ipListModel.get(i).ip)
        }
        
        const jsonData = JSON.stringify(ips).replace(/"/g, '\\"')
        const homeDir = Quickshell.env("HOME")
        const configDir = homeDir + "/.config/quickshell"
        
        // Создаем директорию
        const mkdirProc = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["mkdir", "-p", "${configDir}"]
                running: true
            }
        `, root)
        
        // Сохраняем через небольшую задержку
        saveTimer.jsonData = jsonData
        saveTimer.configDir = configDir
        saveTimer.start()
    }
    
    Timer {
        id: saveTimer
        interval: 100
        repeat: false
        property string jsonData: ""
        property string configDir: ""
        
        onTriggered: {
            const saveProc = Qt.createQmlObject(`
                import Quickshell.Io
                Process {
                    command: ["sh", "-c", "echo '${jsonData}' > ${configDir}/phone-ips.json"]
                    running: true
                    onExited: {
                        console.log("IPs saved")
                    }
                }
            `, root)
        }
    }
    
    // Загрузка IP при старте
    Timer {
        interval: 200
        repeat: false
        running: true
        onTriggered: {
            loadIpsProcess.running = true
        }
    }
    
    // ==================== Фоновый слой для закрытия ====================
    PanelWindow {
        id: backgroundLayer
        
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        
        visible: true
        
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-phone-manager-bg"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        
        color: "transparent"
        
        Item {
            anchors.fill: parent
            focus: true
            
            Component.onCompleted: {
                forceActiveFocus()
            }
            
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    Qt.quit()
                    event.accepted = true
                }
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    parent.forceActiveFocus()
                    Qt.quit()
                }
            }
        }
    }
    
    PanelWindow {
        id: phoneManager
        
        anchors {
            top: true
            left: true
            right: true
        }
        
        margins {
            top: 60
        }
        
        implicitWidth: mainContent.width
        implicitHeight: mainContent.height
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-phone-manager"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        
        visible: true
        
        color: "transparent"
        mask: Region { item: mainContent }
        
        // ==================== Главный контейнер ====================
        Rectangle {
            id: mainContent
            anchors.horizontalCenter: parent.horizontalCenter
            width: 520
            height: contentColumn.height + 28
            color: "#151515"
            radius: 14
            
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.4
                shadowBlur: 0.8
                shadowVerticalOffset: 8
                shadowHorizontalOffset: 0
            }
            
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    Qt.quit()
                    event.accepted = true
                }
            }
            
            ColumnLayout {
                id: contentColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 14
                }
                spacing: 12
                
                // ==================== Заголовок ====================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Rectangle {
                        width: 42
                        height: 42
                        radius: 11
                        color: "#1E1E1E"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰄜"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 22
                            color: "#4a9eff"
                        }
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        Text {
                            text: "Phone Manager"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                        }
                        
                        Text {
                            text: "ADB Device Control"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: "#888888"
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Кнопка закрытия
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 9
                        color: closeMouseArea.containsMouse ? "#ff4444" : "#1E1E1E"
                        
                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: "#ffffff"
                        }
                        
                        MouseArea {
                            id: closeMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.quit()
                        }
                    }
                }
                
                // ==================== Статус индикаторы ====================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    // ADB Status
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70
                        radius: 11
                        color: "#1E1E1E"
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6
                            
                            RowLayout {
                                Layout.fillWidth: true
                                
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: phoneManager.adbConnected ? "#00ff88" : "#ff4444"
                                    
                                    SequentialAnimation on opacity {
                                        running: phoneManager.adbConnected
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1.0; to: 0.3; duration: 1200 }
                                        NumberAnimation { from: 0.3; to: 1.0; duration: 1200 }
                                    }
                                }
                                
                                Text {
                                    text: "ADB"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: "#888888"
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                            
                            Text {
                                text: phoneManager.adbConnected ? "Connected" : "Disconnected"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: phoneManager.adbConnected ? "#00ff88" : "#ff4444"
                            }
                        }
                    }
                    
                    // Scrcpy Status
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70
                        radius: 11
                        color: "#1E1E1E"
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6
                            
                            RowLayout {
                                Layout.fillWidth: true
                                
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: phoneManager.scrcpyActive ? "#00ff88" : "#ff4444"
                                    
                                    SequentialAnimation on opacity {
                                        running: phoneManager.scrcpyActive
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1.0; to: 0.3; duration: 1200 }
                                        NumberAnimation { from: 0.3; to: 1.0; duration: 1200 }
                                    }
                                }
                                
                                Text {
                                    text: "Screen"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: "#888888"
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                            
                            Text {
                                text: phoneManager.scrcpyActive ? "Mirroring" : "Inactive"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: phoneManager.scrcpyActive ? "#00ff88" : "#ff4444"
                            }
                        }
                    }
                    
                    // Battery Status
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70
                        radius: 11
                        color: "#1E1E1E"
                        visible: phoneManager.adbConnected
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6
                            
                            RowLayout {
                                Layout.fillWidth: true
                                
                                Text {
                                    text: phoneManager.getBatteryIcon(phoneManager.batteryLevel)
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: phoneManager.getBatteryColor(phoneManager.batteryLevel)
                                }
                                
                                Text {
                                    text: "Battery"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: "#888888"
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                            
                            Text {
                                text: phoneManager.batteryLevel >= 0 ? phoneManager.batteryLevel + "%" : "N/A"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: phoneManager.getBatteryColor(phoneManager.batteryLevel)
                            }
                        }
                    }
                }
                
                // ==================== Поле ввода IP ====================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    color: "#1E1E1E"
                    radius: 11
                    border.width: ipInput.activeFocus ? 2 : 0
                    border.color: "#4a9eff"
                    
                    Behavior on border.width {
                        NumberAnimation { duration: 200 }
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: "#151515"
                            Layout.alignment: Qt.AlignVCenter
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰩟"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                color: "#4a9eff"
                            }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            
                            Text {
                                text: "Device IP Address"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                color: "#888888"
                            }
                            
                            TextInput {
                                id: ipInput
                                Layout.fillWidth: true
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: "#ffffff"
                                text: ""
                                selectByMouse: true
                                clip: true
                                verticalAlignment: TextInput.AlignVCenter
                                
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "192.168.1.100:5555"
                                    font.family: parent.font.family
                                    font.pixelSize: parent.font.pixelSize
                                    color: "#444444"
                                    visible: parent.text === ""
                                }
                                
                                Keys.onReturnPressed: {
                                    if (ipInput.text !== "") {
                                        ipListModel.append({"ip": ipInput.text})
                                        saveIps()
                                        ipInput.text = ""
                                    }
                                }
                                
                                Keys.onEscapePressed: {
                                    Qt.quit()
                                }
                            }
                        }
                        
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: addMouseArea.containsMouse ? "#4a9eff" : "#151515"
                            Layout.alignment: Qt.AlignVCenter
                            
                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰐕"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                color: "#ffffff"
                            }
                            
                            MouseArea {
                                id: addMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (ipInput.text !== "") {
                                        ipListModel.append({"ip": ipInput.text})
                                        saveIps()
                                        ipInput.text = ""
                                    }
                                }
                            }
                        }
                    }
                }
                
                // ==================== Список IP ====================
                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 180)
                    clip: true
                    spacing: 8
                    visible: count > 0
                    
                    model: ListModel {
                        id: ipListModel
                    }
                    
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 56
                        color: "#1E1E1E"
                        radius: 11
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10
                            
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 8
                                color: "#151515"
                                Layout.alignment: Qt.AlignVCenter
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰩟"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: "#4a9eff"
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                
                                Text {
                                    text: "IP Address"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 8
                                    color: "#888888"
                                }
                                
                                Text {
                                    Layout.fillWidth: true
                                    text: model.ip
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                }
                            }
                            
                            // Кнопка Connect
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 8
                                color: connectMouseArea.containsMouse ? "#00ff88" : "#151515"
                                Layout.alignment: Qt.AlignVCenter
                                
                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰌘"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: "#ffffff"
                                }
                                
                                MouseArea {
                                    id: connectMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: phoneManager.connectToDevice(model.ip)
                                }
                            }
                            
                            // Кнопка Screen
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 8
                                color: scrcpyMouseArea.containsMouse ? "#4a9eff" : "#151515"
                                Layout.alignment: Qt.AlignVCenter
                                
                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰍹"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: "#ffffff"
                                }
                                
                                MouseArea {
                                    id: scrcpyMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: phoneManager.launchScrcpy()
                                }
                            }
                            
                            // Кнопка Delete
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 8
                                color: deleteMouseArea.containsMouse ? "#ff4444" : "#151515"
                                Layout.alignment: Qt.AlignVCenter
                                
                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: "#ffffff"
                                }
                                
                                MouseArea {
                                    id: deleteMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ipListModel.remove(index)
                                        saveIps()
                                    }
                                }
                            }
                        }
                    }
                }
                
                // ==================== Буфер обмена ====================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: 11
                    color: clipboardMouseArea.containsMouse ? "#4a9eff" : "#1E1E1E"
                    
                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10
                        
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: clipboardMouseArea.containsMouse ? "#ffffff" : "#151515"
                            Layout.alignment: Qt.AlignVCenter
                            
                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰅍"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                color: clipboardMouseArea.containsMouse ? "#4a9eff" : "#4a9eff"
                            }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            
                            Text {
                                text: "Sync Clipboard"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: clipboardMouseArea.containsMouse ? "#ffffff" : "#ffffff"
                            }
                            
                            Text {
                                text: "Send clipboard content to phone"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: clipboardMouseArea.containsMouse ? "#e0e0e0" : "#888888"
                            }
                        }
                        
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: "transparent"
                            Layout.alignment: Qt.AlignVCenter
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰁔"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                color: clipboardMouseArea.containsMouse ? "#ffffff" : "#4a9eff"
                            }
                        }
                    }
                    
                    MouseArea {
                        id: clipboardMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: phoneManager.syncClipboard()
                    }
                }
            }
        }
        
        // ==================== Свойства ====================
        property bool adbConnected: false
        property bool scrcpyActive: false
        property int batteryLevel: -1
        property string lastNotification: ""
        
        // ==================== Функции ====================
        function getBatteryIcon(level) {
            if (level < 0) return "󰂎"
            if (level > 90) return "󰁹"
            if (level > 70) return "󰂀"
            if (level > 50) return "󰁾"
            if (level > 30) return "󰁼"
            if (level > 10) return "󰁺"
            return "󰂎"
        }
        
        function getBatteryColor(level) {
            if (level < 0) return "#666666"
            if (level > 50) return "#00ff88"
            if (level > 20) return "#ffaa00"
            return "#ff4444"
        }
        
        function connectToDevice(ip) {
            adbConnectProcess.targetIp = ip
            adbConnectProcess.running = true
        }
        
        function launchScrcpy() {
            scrcpyProcess.running = true
        }
        
        function syncClipboard() {
            clipboardProcess.running = true
        }
        
        function checkAdbConnection() {
            adbCheckReadProcess.running = true
        }
        
        function updateBattery() {
            batteryProcess.running = true
        }
        
        function updateNotifications() {
            notificationProcess.running = true
        }
        
        function checkScrcpyWindow() {
            hyprlandClientsProcess.running = true
        }
        
        // ==================== Таймеры ====================
        Timer {
            id: adbCheckDelayTimer
            interval: 5000
            repeat: false
            onTriggered: phoneManager.checkAdbConnection()
        }
        
        Timer {
            interval: 12000
            repeat: true
            running: true
            onTriggered: phoneManager.checkAdbConnection()
        }
        
        Timer {
            interval: 5000
            repeat: true
            running: true
            onTriggered: {
                if (phoneManager.adbConnected) {
                    phoneManager.updateBattery()
                }
            }
        }
        
        Timer {
            interval: 10000
            repeat: true
            running: true
            onTriggered: phoneManager.updateNotifications()
        }
        
        Timer {
            id: scrcpyCheckDelayTimer
            interval: 3000
            repeat: false
            onTriggered: phoneManager.checkScrcpyWindow()
        }
        
        Timer {
            interval: 2500
            repeat: true
            running: true
            onTriggered: phoneManager.checkScrcpyWindow()
        }
        
        Component.onCompleted: {
           checkAdbConnection()
            checkScrcpyWindow()
        }
    }
}
