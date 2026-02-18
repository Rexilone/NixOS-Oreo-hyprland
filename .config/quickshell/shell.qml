import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ShellRoot {
    id: root

    // ===== ЦВЕТОВАЯ ПАЛИТРА =====
    readonly property color colorBgPrimary: "#151515"
    readonly property color colorBgSecondary: "transparent"
    readonly property color colorBgCard: "#1e1e1e"
    readonly property color colorBgCardHover: "#252525"
    readonly property color colorAccent: "#fff0f5"
    readonly property color colorAccentHover: "#ffffff"
    readonly property color colorTextPrimary: "#ffffff"
    readonly property color colorTextSecondary: "#dcd7ba"
    readonly property color colorTextDim: "#7c6f64"
    readonly property color colorActive: "#fff0f5"
    readonly property color colorConnected: "#4ade80"
    
    // ===== СИСТЕМНЫЕ ДАННЫЕ =====
    property int cpuUsage: 0
    property int memoryUsage: 0
    property int volume: 50
    property int micVolume: 80
    property int brightness: 50
    property int batteryLevel: 100
    property bool batteryCharging: false
    property string networkStatus: "wifi"
    property string networkSSID: ""
    property string currentLanguage: "EN"

    // ===== DYNAMIC DASHBOARD =====
    property bool showDashboard: false
    property bool isMouseOverDashboard: false
    
    // Dashboard progress animation
    property real dashboardProgress: 0.0

    // ===== MUSIC PLAYER =====
    property string musicTitle: "No Track Playing"
    property string musicArtist: "Unknown Artist"
    property string musicArtUrl: ""
    property bool musicPlaying: false
    property string activePlayer: ""
    property var availablePlayers: []
    property int currentPlayerIndex: 0
    property real musicPosition: 0.0
    property real musicDuration: 1.0

    // ===== CALENDAR =====
    property date currentDate: new Date()
    property int currentMonth: currentDate.getMonth()
    property int currentYear: currentDate.getFullYear()

    // ===== QUICK SETTINGS =====
    property bool wifiEnabled: true
    property bool bluetoothEnabled: true
    property bool doNotDisturb: false
    property bool nightLight: false

    // ===== NOTIFICATIONS =====
    property var notifications: [
        { id: 1, title: "System Update", body: "New updates available for your system", time: "5m ago", icon: "\uf0ed" },
        { id: 2, title: "Battery Low", body: "15% battery remaining", time: "10m ago", icon: "\uf244" },
        { id: 3, title: "Message", body: "You have a new message", time: "15m ago", icon: "\uf0e0" }
    ]

    // ===== SLIDER CONTROL =====
    property int activeSlider: 0 // 0 = brightness, 1 = volume

    // ===== USER INPUT FLAGS =====
    property bool brightnessUserChanging: false
    property bool volumeUserChanging: false
    property bool micUserChanging: false

    // ===== ФУНКЦИИ УПРАВЛЕНИЯ DASHBOARD =====
    function openDashboard() {
        hideDashboardTimer.stop()
        showDashboard = true
    }

    function closeDashboard() {
        showDashboard = false
    }

    // ===== ФУНКЦИИ ПЛЕЕРА =====
    function switchToPlayer(index) {
        if (index >= 0 && index < availablePlayers.length) {
            currentPlayerIndex = index
            activePlayer = availablePlayers[index]
            playerMetadataProcess.running = true
            playerStatusProcess.running = true
            playerPositionProcess.running = true
        }
    }

    function nextPlayer() {
        if (availablePlayers.length > 1)
            switchToPlayer((currentPlayerIndex + 1) % availablePlayers.length)
    }

    function prevPlayer() {
        if (availablePlayers.length > 1)
            switchToPlayer((currentPlayerIndex - 1 + availablePlayers.length) % availablePlayers.length)
    }

    // ===== CALENDAR FUNCTIONS =====
    function getDaysInMonth(month, year) {
        return new Date(year, month + 1, 0).getDate()
    }

    function getFirstDayOfMonth(month, year) {
        return new Date(year, month, 1).getDay()
    }

    function isToday(day, month, year) {
        let today = new Date()
        return day === today.getDate() && month === today.getMonth() && year === today.getFullYear()
    }

    // ===== ТАЙМЕРЫ =====
    Timer {
        id: hideDashboardTimer
        interval: 300
        onTriggered: if (!isMouseOverDashboard) closeDashboard()
    }

    // Быстрый таймер (300ms) - аудио, яркость
    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            if (!volumeUserChanging && !micUserChanging) audioProcess.running = true
            if (!brightnessUserChanging) brightnessProcess.running = true
        }
    }

    // Средний таймер (1.5s) - CPU, RAM, плеер
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            systemStatsProcess.running = true
            playerListProcess.running = true
        }
    }

    // Быстрый таймер для раскладки (200ms) - мгновенное обновление
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            langProcess.running = true
        }
    }

    // Медленный таймер (4s) - сеть, батарея
    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: {
            batteryProcess.running = true
            networkProcess.running = true
        }
    }

    // Таймер позиции плеера (обновление каждые 500ms)
    Timer {
        interval: 500
        running: showDashboard && activePlayer !== ""
        repeat: true
        onTriggered: playerPositionProcess.running = true
    }
    
    // Таймер для плавного обновления прогресса (каждые 100ms когда играет)
    Timer {
        interval: 100
        running: showDashboard && musicPlaying && musicDuration > 0
        repeat: true
        onTriggered: {
            // Плавное увеличение позиции между обновлениями от playerctl
            if (musicPosition < musicDuration) {
                musicPosition += 0.1 // 100ms = 0.1 секунды
            }
        }
    }

    // Таймер обновления времени
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: currentDate = new Date()
    }

    // ===== ПРОЦЕССЫ =====
    
    // Язык
    Process {
        id: langProcess
        command: ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap'"]
        stdout: SplitParser {
            onRead: data => {
                let l = data.trim().toLowerCase()
                currentLanguage = l.includes("russian") || l.includes("ru") ? "RU" :
                                  l.includes("english") || l.includes("us") || l.includes("en") ? "EN" :
                                  l && l !== "null" ? l.substring(0, 2).toUpperCase() : "EN"
            }
        }
    }

    // CPU + RAM
    Process {
        id: systemStatsProcess
        command: ["sh", "-c", "echo $(grep 'cpu ' /proc/stat | awk '{printf \"%.0f\", ($2+$4)*100/($2+$4+$5)}') $(free | awk '/Mem:/ {printf \"%.0f\", $3/$2 * 100}')"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(' ')
                if (parts.length >= 2) {
                    cpuUsage = parseInt(parts[0]) || 0
                    memoryUsage = parseInt(parts[1]) || 0
                }
            }
        }
    }

    // Батарея
    Process {
        id: batteryProcess
        command: ["sh", "-c", "echo $(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1 || echo '100') $(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1 || echo 'Full')"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(' ')
                batteryLevel = parseInt(parts[0]) || 100
                batteryCharging = parts[1] === "Charging"
            }
        }
    }

    // Яркость
    Process {
        id: brightnessProcess
        command: ["sh", "-c", "brightnessctl -m | cut -d',' -f4 | tr -d '%'"]
        stdout: SplitParser {
            onRead: data => { if (!brightnessUserChanging) brightness = parseInt(data.trim()) || 50 }
        }
    }

    Process {
        id: brightnessChangeProcess
        property int targetBrightness: 50
        command: ["brightnessctl", "set", targetBrightness + "%"]
    }

    // Громкость + Микрофон
    Process {
        id: audioProcess
        command: ["sh", "-c", "echo $(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}') $(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{print int($2*100)}')"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(' ')
                if (parts.length >= 2) {
                    if (!volumeUserChanging) volume = parseInt(parts[0]) || 0
                    if (!micUserChanging) micVolume = parseInt(parts[1]) || 0
                }
            }
        }
    }

    Process {
        id: volumeChangeProcess
        property int targetVolume: 50
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (targetVolume / 100).toFixed(2)]
    }

    Process {
        id: micChangeProcess
        property int targetVolume: 50
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", (targetVolume / 100).toFixed(2)]
    }

    // Сеть
    Process {
        id: networkProcess
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device | grep connected | head -1"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(':')
                if (parts.length >= 3) {
                    networkStatus = parts[0] === "wifi" ? "wifi" : parts[0] === "ethernet" ? "ethernet" : "disconnected"
                    networkSSID = parts[2]
                } else {
                    networkStatus = "disconnected"
                    networkSSID = ""
                }
            }
        }
    }

    // ===== ПЛЕЕР =====
    Process {
        id: playerListProcess
        command: ["playerctl", "-l"]
        stdout: SplitParser {
            onRead: data => {
                let players = data.trim().split('\n').filter(p => p.length > 0)
                availablePlayers = players
                
                if (players.length > 0) {
                    if (currentPlayerIndex >= players.length) currentPlayerIndex = 0
                    if (activePlayer && players.includes(activePlayer)) {
                        currentPlayerIndex = players.indexOf(activePlayer)
                    } else {
                        activePlayer = players[currentPlayerIndex]
                    }
                    playerMetadataProcess.running = true
                    playerStatusProcess.running = true
                    playerPositionProcess.running = true
                } else {
                    activePlayer = ""
                    currentPlayerIndex = 0
                    musicTitle = "No Track Playing"
                    musicArtist = "Unknown Artist"
                    musicPlaying = false
                }
            }
        }
    }

    Process {
        id: playerMetadataProcess
        command: ["sh", "-c", activePlayer ? 
            "playerctl -p '" + activePlayer + "' metadata --format '{{title}}|||{{artist}}|||{{mpris:artUrl}}' 2>/dev/null" : "echo ''"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split('|||')
                if (parts.length >= 1 && parts[0]) {
                    musicTitle = parts[0] || "No Track Playing"
                    musicArtist = parts[1] || "Unknown Artist"
                    musicArtUrl = parts[2] || ""
                }
            }
        }
    }

    Process {
        id: playerStatusProcess
        command: ["sh", "-c", activePlayer ? "playerctl -p '" + activePlayer + "' status 2>/dev/null" : "echo 'Stopped'"]
        stdout: SplitParser {
            onRead: data => { musicPlaying = data.trim() === "Playing" }
        }
    }

    Process {
        id: playerPositionProcess
        command: ["sh", "-c", activePlayer ? 
            "echo $(playerctl -p '" + activePlayer + "' position 2>/dev/null || echo '0') $(playerctl -p '" + activePlayer + "' metadata mpris:length 2>/dev/null || echo '1000000')" : "echo '0 1000000'"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(' ')
                if (parts.length >= 2) {
                    // playerctl position возвращает секунды с плавающей точкой
                    musicPosition = parseFloat(parts[0]) || 0
                    // mpris:length в микросекундах, конвертируем в секунды
                    musicDuration = (parseFloat(parts[1]) / 1000000) || 1
                }
            }
        }
    }

    Process {
        id: playerPlayPauseProcess
        command: ["sh", "-c", activePlayer ? "playerctl -p '" + activePlayer + "' play-pause" : "playerctl play-pause"]
    }

    Process {
        id: playerNextProcess
        command: ["sh", "-c", activePlayer ? "playerctl -p '" + activePlayer + "' next" : "playerctl next"]
    }

    Process {
        id: playerPreviousProcess
        command: ["sh", "-c", activePlayer ? "playerctl -p '" + activePlayer + "' previous" : "playerctl previous"]
    }

    // ===== КОМПОНЕНТЫ =====
    
    // Круговой прогресс-бар для плеера
    component CircularProgress: Item {
        id: circProg
        property real progress: 0.0
        property real size: 140
        property real lineWidth: 6
        
        width: size
        height: size
        
        Canvas {
            anchors.fill: parent
            onPaint: {
                let ctx = getContext("2d")
                let centerX = width / 2
                let centerY = height / 2
                let radius = (width - circProg.lineWidth) / 2
                
                ctx.clearRect(0, 0, width, height)
                
                // Background circle
                ctx.beginPath()
                ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI)
                ctx.strokeStyle = "#2a2a2a"
                ctx.lineWidth = circProg.lineWidth
                ctx.stroke()
                
                // Progress arc
                ctx.beginPath()
                ctx.arc(centerX, centerY, radius, -Math.PI / 2, -Math.PI / 2 + (2 * Math.PI * circProg.progress))
                ctx.strokeStyle = colorAccent
                ctx.lineWidth = circProg.lineWidth
                ctx.lineCap = "round"
                ctx.stroke()
            }
        }
        
        onProgressChanged: requestPaint()
        
        Component.onCompleted: requestPaint()
    }

    // Быстрая настройка
    component QuickSettingButton: Rectangle {
        id: qsBtn
        property string icon: ""
        property string label: ""
        property bool active: false
        signal clicked()
        
        width: 50
        height: 50
        radius: 10
        color: active ? colorAccent : (qsMouse.containsMouse ? colorBgCardHover : colorBgCard)
        
        Behavior on color { ColorAnimation { duration: 200 } }
        
        Column {
            anchors.centerIn: parent
            spacing: 4
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsBtn.icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: qsBtn.active ? colorBgPrimary : colorTextPrimary
            }
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsBtn.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 7
                color: qsBtn.active ? colorBgPrimary : colorTextSecondary
            }
        }
        
        MouseArea {
            id: qsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: qsBtn.clicked()
        }
    }

    // Вертикальный слайдер
    component VerticalSlider: Column {
        id: vSlider
        property string icon: ""
        property real sliderValue: 50
        signal sliderMoved(real newValue)
        
        spacing: 10
        width: 50
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: vSlider.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20
            color: colorTextPrimary
        }
        
        Item {
            width: 50
            height: 200
            anchors.horizontalCenter: parent.horizontalCenter
            
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 8
                height: parent.height
                color: "#2a2a2a"
                radius: 4
                
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: (vSlider.sliderValue / 100) * parent.height
                    color: colorAccent
                    radius: 4
                }
            }
            
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - (vSlider.sliderValue / 100) * parent.height - height / 2
                width: 20
                height: 20
                radius: 10
                color: colorAccent
                
                Behavior on y { 
                    enabled: !vSliderMouse.pressed
                    NumberAnimation { duration: 100 }
                }
            }
            
            MouseArea {
                id: vSliderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                function updateValue(mouseY) {
                    let val = 100 - Math.max(0, Math.min(100, (mouseY / height) * 100))
                    vSlider.sliderMoved(Math.round(val))
                }
                
                onPressed: updateValue(mouse.y)
                onPositionChanged: if (pressed) updateValue(mouse.y)
            }
        }
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(vSlider.sliderValue) + "%"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: colorTextSecondary
        }
    }

    // Карточка уведомления
    component NotificationCard: Rectangle {
        id: notifCard
        property string icon: "\uf0f3"
        property string title: ""
        property string body: ""
        property string time: ""
        signal removeClicked()
        
        width: parent.width
        height: 70
        radius: 12
        color: notifMouse.containsMouse ? colorBgCardHover : colorBgCard
        
        Behavior on color { ColorAnimation { duration: 150 } }
        
        MouseArea {
            id: notifMouse
            anchors.fill: parent
            hoverEnabled: true
        }
        
        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            
            Rectangle {
                width: 45
                height: 45
                radius: 10
                color: Qt.rgba(0.91, 0.71, 0.64, 0.1)
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    anchors.centerIn: parent
                    text: notifCard.icon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                    color: colorAccent
                }
            }
            
            Column {
                width: parent.width - 120
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    text: notifCard.title
                    color: colorTextPrimary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    width: parent.width
                }
                
                Text {
                    text: notifCard.body
                    color: colorTextSecondary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                }
                
                Text {
                    text: notifCard.time
                    color: colorTextDim
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                }
            }
            
            Rectangle {
                width: 30
                height: 30
                radius: 8
                color: closeMouse.containsMouse ? Qt.rgba(0.91, 0.71, 0.64, 0.2) : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: colorTextSecondary
                }
                
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: notifCard.removeClicked()
                }
            }
        }
    }

    Component.onCompleted: {
        networkProcess.running = true
        batteryProcess.running = true
        systemStatsProcess.running = true
    }

    // ===== ЭКРАНЫ =====
    Variants {
        model: Quickshell.screens
        
        delegate: Component {
            Item {
                property var modelData

                // ===== DASHBOARD =====
                PanelWindow {
                    id: dashboard
                    screen: modelData
                    visible: showDashboard && modelData.name === "DP-1"
                    
                    anchors { top: true; left: true }
                    margins { 
                        top: 3
                        left: (modelData.width - 880) / 2 
                    }
                    width: 880
                    height: 520
                    color: "transparent"
                    focusable: true
                    exclusionMode: ExclusionMode.Ignore
                    
                    Item {
                        anchors.fill: parent
                        focus: true
                        Keys.onEscapePressed: closeDashboard()
                    }
                    
                    // Контейнер с анимацией
                    Item {
                        id: dashboardScaleContainer
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: parent.width
                        height: parent.height
                        transformOrigin: Item.Top
                        
                        scale: dashboardProgress
                        opacity: dashboardProgress
                        
                        Behavior on scale {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        Rectangle {
                            anchors.fill: parent
                            color: colorBgPrimary
                            radius: 20
                            
                            HoverHandler {
                                onHoveredChanged: {
                                    isMouseOverDashboard = hovered
                                    if (hovered) hideDashboardTimer.stop()
                                    else hideDashboardTimer.restart()
                                }
                            }
                            
                            Row {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 12
                                
                                // ===== LEFT: ПЛЕЕР =====
                                Rectangle {
                                    width: 210
                                    height: parent.height
                                    radius: 18
                                    color: colorBgCard
                                    
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 20
                                        
                                        // Круговой прогресс с обложкой
                                        Item {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 130
                                            height: 130
                                            
                                            CircularProgress {
                                                anchors.centerIn: parent
                                                size: 130
                                                lineWidth: 5
                                                progress: musicDuration > 0 ? musicPosition / musicDuration : 0
                                            }
                                            
                                            // Обложка альбома
                                            Item {
                                                id: albumArtContainer
                                                anchors.centerIn: parent
                                                width: 100
                                                height: 100
                                                
                                                // Загрузка изображения (скрыто)
                                                Image {
                                                    id: albumImage
                                                    source: musicArtUrl
                                                    visible: false
                                                    asynchronous: true
                                                    cache: true
                                                    smooth: true
                                                }
                                                
                                                // Canvas для рисования круглого изображения
                                                Canvas {
                                                    id: albumCanvas
                                                    anchors.fill: parent
                                                    visible: albumImage.status === Image.Ready
                                                    
                                                    onPaint: {
                                                        let ctx = getContext("2d")
                                                        ctx.clearRect(0, 0, width, height)
                                                        
                                                        // Создаём круглую маску
                                                        ctx.save()
                                                        ctx.beginPath()
                                                        ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI)
                                                        ctx.closePath()
                                                        ctx.clip()
                                                        
                                                        // Рисуем изображение
                                                        if (albumImage.status === Image.Ready) {
                                                            ctx.drawImage(albumImage, 0, 0, width, height)
                                                        }
                                                        
                                                        ctx.restore()
                                                    }
                                                    
                                                    Connections {
                                                        target: albumImage
                                                        function onStatusChanged() {
                                                            if (albumImage.status === Image.Ready) {
                                                                albumCanvas.requestPaint()
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                // Placeholder когда нет изображения
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 50
                                                    color: colorBgPrimary
                                                    visible: musicArtUrl === "" || albumImage.status !== Image.Ready
                                                    
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "\uf001"
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 40
                                                        color: colorTextDim
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Информация о треке
                                        Column {
                                            width: 200
                                            spacing: 5
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            
                                            Text {
                                                text: musicTitle
                                                color: colorTextPrimary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                elide: Text.ElideRight
                                                width: parent.width
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                            
                                            Text {
                                                text: musicArtist
                                                color: colorTextSecondary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                                width: parent.width
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                        
                                        // Время
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 10
                                            
                                            Text {
                                                text: {
                                                    let pos = Math.floor(musicPosition)
                                                    let mins = Math.floor(pos / 60)
                                                    let secs = pos % 60
                                                    return mins + ":" + (secs < 10 ? "0" : "") + secs
                                                }
                                                color: colorTextDim
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                            }
                                            
                                            Text {
                                                text: "/"
                                                color: colorTextDim
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                            }
                                            
                                            Text {
                                                text: {
                                                    let dur = Math.floor(musicDuration)
                                                    let mins = Math.floor(dur / 60)
                                                    let secs = dur % 60
                                                    return mins + ":" + (secs < 10 ? "0" : "") + secs
                                                }
                                                color: colorTextDim
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                            }
                                        }
                                        
                                        // Контролы
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 15
                                            
                                            Rectangle {
                                                width: 45
                                                height: 45
                                                radius: 12
                                                color: prevMouse.containsMouse ? colorBgCardHover : "transparent"
                                                
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf048"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 18
                                                    color: colorTextPrimary
                                                }
                                                
                                                MouseArea {
                                                    id: prevMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: playerPreviousProcess.running = true
                                                }
                                            }
                                            
                                            Rectangle {
                                                width: 55
                                                height: 55
                                                radius: 15
                                                color: playMouse.containsMouse ? colorAccentHover : colorAccent
                                                
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: musicPlaying ? "\uf04c" : "\uf04b"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 20
                                                    color: colorBgPrimary
                                                }
                                                
                                                MouseArea {
                                                    id: playMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: playerPlayPauseProcess.running = true
                                                }
                                            }
                                            
                                            Rectangle {
                                                width: 45
                                                height: 45
                                                radius: 12
                                                color: nextMouse.containsMouse ? colorBgCardHover : "transparent"
                                                
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf051"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 18
                                                    color: colorTextPrimary
                                                }
                                                
                                                MouseArea {
                                                    id: nextMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: playerNextProcess.running = true
                                                }
                                            }
                                        }
                                        
                                        // Индикатор плееров
                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 6
                                            visible: availablePlayers.length > 1
                                            
                                            Repeater {
                                                model: Math.min(availablePlayers.length, 5)
                                                
                                                Rectangle {
                                                    width: index === currentPlayerIndex ? 20 : 8
                                                    height: 8
                                                    radius: 4
                                                    color: index === currentPlayerIndex ? colorAccent : colorTextDim
                                                    
                                                    Behavior on width { NumberAnimation { duration: 200 } }
                                                    Behavior on color { ColorAnimation { duration: 200 } }
                                                    
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        anchors.margins: -5
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: switchToPlayer(index)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // ===== CENTER: БЫСТРЫЕ НАСТРОЙКИ + КАЛЕНДАРЬ =====
                                Column {
                                    width: 390
                                    height: parent.height
                                    spacing: 12
                                    
                                    // Быстрые настройки
                                    Rectangle {
                                        width: parent.width
                                        height: 100
                                        radius: 15
                                        color: colorBgCard
                                        
                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10
                                            
                                            Text {
                                                text: "Quick Settings"
                                                color: colorTextPrimary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                            }
                                            
                                            Row {
                                                spacing: 8
                                                
                                                QuickSettingButton {
                                                    icon: "\uf1eb"
                                                    label: "WiFi"
                                                    active: wifiEnabled
                                                    onClicked: wifiEnabled = !wifiEnabled
                                                }
                                                
                                                QuickSettingButton {
                                                    icon: "\uf293"
                                                    label: "Bluetooth"
                                                    active: bluetoothEnabled
                                                    onClicked: bluetoothEnabled = !bluetoothEnabled
                                                }
                                                
                                                QuickSettingButton {
                                                    icon: "\uf1f6"
                                                    label: "DND"
                                                    active: doNotDisturb
                                                    onClicked: doNotDisturb = !doNotDisturb
                                                }
                                                
                                                QuickSettingButton {
                                                    icon: "\uf186"
                                                    label: "Night"
                                                    active: nightLight
                                                    onClicked: nightLight = !nightLight
                                                }
                                                
                                                QuickSettingButton {
                                                    icon: "\uf011"
                                                    label: "Power"
                                                    active: false
                                                    onClicked: {
                                                        // Power menu
                                                    }
                                                }
                                                
                                                QuickSettingButton {
                                                    icon: "\uf013"
                                                    label: "Settings"
                                                    active: false
                                                    onClicked: {
                                                        // Settings
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Календарь
                                    Rectangle {
                                        width: parent.width
                                        height: parent.height - 112
                                        radius: 15
                                        color: colorBgCard
                                        
                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 15
                                            spacing: 12
                                            
                                            // Заголовок календаря
                                            Row {
                                                width: parent.width
                                                
                                                Text {
                                                    text: Qt.formatDate(new Date(currentYear, currentMonth, 1), "MMMM yyyy")
                                                    color: colorTextPrimary
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 16
                                                    font.weight: Font.Bold
                                                    width: parent.width - 100
                                                }
                                                
                                                Row {
                                                    spacing: 8
                                                    
                                                    Rectangle {
                                                        width: 35
                                                        height: 35
                                                        radius: 10
                                                        color: prevMonthMouse.containsMouse ? colorBgCardHover : "transparent"
                                                        
                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                        
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "\uf053"
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 14
                                                            color: colorTextPrimary
                                                        }
                                                        
                                                        MouseArea {
                                                            id: prevMonthMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (currentMonth === 0) {
                                                                    currentMonth = 11
                                                                    currentYear--
                                                                } else {
                                                                    currentMonth--
                                                                }
                                                            }
                                                        }
                                                    }
                                                    
                                                    Rectangle {
                                                        width: 35
                                                        height: 35
                                                        radius: 10
                                                        color: nextMonthMouse.containsMouse ? colorBgCardHover : "transparent"
                                                        
                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                        
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "\uf054"
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 14
                                                            color: colorTextPrimary
                                                        }
                                                        
                                                        MouseArea {
                                                            id: nextMonthMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (currentMonth === 11) {
                                                                    currentMonth = 0
                                                                    currentYear++
                                                                } else {
                                                                    currentMonth++
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            // Дни недели
                                            Grid {
                                                columns: 7
                                                columnSpacing: 6
                                                rowSpacing: 0
                                                width: parent.width
                                                
                                                Repeater {
                                                    model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                                                    
                                                    Text {
                                                        text: modelData
                                                        color: colorTextDim
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 10
                                                        font.weight: Font.Medium
                                                        width: (parent.width - 36) / 7
                                                        horizontalAlignment: Text.AlignHCenter
                                                    }
                                                }
                                            }
                                            
                                            // Сетка календаря
                                            Grid {
                                                columns: 7
                                                columnSpacing: 6
                                                rowSpacing: 6
                                                width: parent.width
                                                
                                                Repeater {
                                                    model: {
                                                        let days = []
                                                        let firstDay = getFirstDayOfMonth(currentMonth, currentYear)
                                                        let daysInMonth = getDaysInMonth(currentMonth, currentYear)
                                                        
                                                        // Пустые ячейки до первого дня
                                                        for (let i = 0; i < firstDay; i++) {
                                                            days.push({ day: 0, isCurrentMonth: false })
                                                        }
                                                        
                                                        // Дни текущего месяца
                                                        for (let i = 1; i <= daysInMonth; i++) {
                                                            days.push({ day: i, isCurrentMonth: true })
                                                        }
                                                        
                                                        return days
                                                    }
                                                    
                                                    Rectangle {
                                                        width: (parent.width - 36) / 7
                                                        height: width
                                                        radius: width / 2
                                                        color: {
                                                            if (!modelData.isCurrentMonth) return "transparent"
                                                            if (isToday(modelData.day, currentMonth, currentYear)) return colorAccent
                                                            if (dayMouse.containsMouse) return colorBgCardHover
                                                            return "transparent"
                                                        }
                                                        
                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                        
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData.isCurrentMonth ? modelData.day : ""
                                                            color: {
                                                                if (!modelData.isCurrentMonth) return "transparent"
                                                                if (isToday(modelData.day, currentMonth, currentYear)) return colorBgPrimary
                                                                return colorTextPrimary
                                                            }
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 12
                                                            font.weight: isToday(modelData.day, currentMonth, currentYear) ? Font.Bold : Font.Normal
                                                        }
                                                        
                                                        MouseArea {
                                                            id: dayMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: modelData.isCurrentMonth
                                                            cursorShape: modelData.isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // ===== RIGHT: СИСТЕМНАЯ ИНФОРМАЦИЯ + ЗВУК + УВЕДОМЛЕНИЯ =====
                                Column {
                                    width: 220
                                    height: parent.height
                                    spacing: 12
                                    
                                    // Системная информация
                                    Rectangle {
                                        width: parent.width
                                        height: 100
                                        radius: 15
                                        color: colorBgCard
                                        
                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 20
                                            
                                            Column {
                                                spacing: 4
                                                
                                                Text {
                                                    text: "\uf2db"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 18
                                                    color: colorTextPrimary
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                                
                                                Text {
                                                    text: cpuUsage + "%"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    color: colorTextPrimary
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                                
                                                Text {
                                                    text: "CPU"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 8
                                                    color: colorTextDim
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                            }
                                            
                                            Column {
                                                spacing: 4
                                                
                                                Text {
                                                    text: "\uefc5"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 18
                                                    color: colorTextPrimary
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                                
                                                Text {
                                                    text: memoryUsage + "%"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    color: colorTextPrimary
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                                
                                                Text {
                                                    text: "RAM"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 8
                                                    color: colorTextDim
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                            }
                                            
                                            Column {
                                                spacing: 4
                                                
                                                Text {
                                                    text: batteryCharging ? "\uf0e7" : 
                                                          batteryLevel > 80 ? "\uf240" : batteryLevel > 60 ? "\uf241" : 
                                                          batteryLevel > 40 ? "\uf242" : batteryLevel > 20 ? "\uf243" : "\uf244"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 18
                                                    color: colorTextPrimary
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                                
                                                Text {
                                                    text: batteryLevel + "%"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    color: colorTextPrimary
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                                
                                                Text {
                                                    text: "BAT"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 8
                                                    color: colorTextDim
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Настройки звука и яркости (вертикальные слайдеры)
                                    Rectangle {
                                        width: parent.width
                                        height: parent.height - 112
                                        radius: 15
                                        color: colorBgCard
                                        
                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10
                                            
                                            Text {
                                                text: "Controls"
                                                color: colorTextPrimary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }
                                            
                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 12
                                                
                                                // Яркость
                                                Column {
                                                    spacing: 15
                                                    
                                                    Text {
                                                        text: "\uf185"
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 18
                                                        color: colorTextPrimary
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                    }
                                                    
                                                    Item {
                                                        width: 30
                                                        height: 230
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        
                                                        Rectangle {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            width: 8
                                                            height: parent.height
                                                            color: "#2a2a2a"
                                                            radius: 4
                                                            
                                                            Rectangle {
                                                                anchors.bottom: parent.bottom
                                                                width: parent.width
                                                                height: (brightness / 100) * parent.height
                                                                color: colorAccent
                                                                radius: 4
                                                            }
                                                        }
                                                        
                                                        Rectangle {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            y: parent.height - (brightness / 100) * parent.height - height / 2
                                                            width: 20
                                                            height: 20
                                                            radius: 10
                                                            color: colorAccent
                                                            
                                                            Behavior on y {
                                                                enabled: !brightSliderMouse.pressed
                                                                NumberAnimation { duration: 100 }
                                                            }
                                                        }
                                                        
                                                        MouseArea {
                                                            id: brightSliderMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            
                                                            function updateValue(mouseY) {
                                                                let val = 100 - Math.max(0, Math.min(100, (mouseY / height) * 100))
                                                                brightnessUserChanging = true
                                                                brightness = Math.round(val)
                                                                brightnessChangeProcess.targetBrightness = Math.round(val)
                                                                brightnessChangeProcess.running = true
                                                                Qt.callLater(() => brightnessUserChanging = false)
                                                            }
                                                            
                                                            onPressed: updateValue(mouse.y)
                                                            onPositionChanged: if (pressed) updateValue(mouse.y)
                                                        }
                                                    }
                                                    
                                                    Text {
                                                        text: brightness + "%"
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 11
                                                        color: colorTextSecondary
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                    }
                                                }
                                                
                                                // Громкость
                                                Column {
                                                    spacing: 15
                                                    
                                                    Text {
                                                        text: volume === 0 ? "\uf6a9" : volume > 66 ? "\uf028" : volume > 33 ? "\uf027" : "\uf026"
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 18
                                                        color: colorTextPrimary
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                    }
                                                    
                                                    Item {
                                                        width: 30
                                                        height: 230
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        
                                                        Rectangle {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            width: 8
                                                            height: parent.height
                                                            color: "#2a2a2a"
                                                            radius: 4
                                                            
                                                            Rectangle {
                                                                anchors.bottom: parent.bottom
                                                                width: parent.width
                                                                height: (volume / 100) * parent.height
                                                                color: colorAccent
                                                                radius: 4
                                                            }
                                                        }
                                                        
                                                        Rectangle {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            y: parent.height - (volume / 100) * parent.height - height / 2
                                                            width: 20
                                                            height: 20
                                                            radius: 10
                                                            color: colorAccent
                                                            
                                                            Behavior on y {
                                                                enabled: !volSliderMouse.pressed
                                                                NumberAnimation { duration: 100 }
                                                            }
                                                        }
                                                        
                                                        MouseArea {
                                                            id: volSliderMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            
                                                            function updateValue(mouseY) {
                                                                let val = 100 - Math.max(0, Math.min(100, (mouseY / height) * 100))
                                                                volumeUserChanging = true
                                                                volume = Math.round(val)
                                                                volumeChangeProcess.targetVolume = Math.round(val)
                                                                volumeChangeProcess.running = true
                                                                Qt.callLater(() => volumeUserChanging = false)
                                                            }
                                                            
                                                            onPressed: updateValue(mouse.y)
                                                            onPositionChanged: if (pressed) updateValue(mouse.y)
                                                        }
                                                    }
                                                    
                                                    Text {
                                                        text: volume + "%"
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 11
                                                        color: colorTextSecondary
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                    }
                                                }
                                                
                                                // Микрофон
                                                Column {
                                                    spacing: 15
                                                    
                                                    Text {
                                                        text: micVolume === 0 ? "\uf131" : "\uf130"
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 18
                                                        color: colorTextPrimary
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                    }
                                                    
                                                    Item {
                                                        width: 30
                                                        height: 230
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        
                                                        Rectangle {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            width: 8
                                                            height: parent.height
                                                            color: "#2a2a2a"
                                                            radius: 4
                                                            
                                                            Rectangle {
                                                                anchors.bottom: parent.bottom
                                                                width: parent.width
                                                                height: (micVolume / 100) * parent.height
                                                                color: colorAccent
                                                                radius: 4
                                                            }
                                                        }
                                                        
                                                        Rectangle {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            y: parent.height - (micVolume / 100) * parent.height - height / 2
                                                            width: 20
                                                            height: 20
                                                            radius: 10
                                                            color: colorAccent
                                                            
                                                            Behavior on y {
                                                                enabled: !micSliderMouse.pressed
                                                                NumberAnimation { duration: 100 }
                                                            }
                                                        }
                                                        
                                                        MouseArea {
                                                            id: micSliderMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            
                                                            function updateValue(mouseY) {
                                                                let val = 100 - Math.max(0, Math.min(100, (mouseY / height) * 100))
                                                                micUserChanging = true
                                                                micVolume = Math.round(val)
                                                                micChangeProcess.targetVolume = Math.round(val)
                                                                micChangeProcess.running = true
                                                                Qt.callLater(() => micUserChanging = false)
                                                            }
                                                            
                                                            onPressed: updateValue(mouse.y)
                                                            onPositionChanged: if (pressed) updateValue(mouse.y)
                                                        }
                                                    }
                                                    
                                                    Text {
                                                        text: micVolume + "%"
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 11
                                                        color: colorTextSecondary
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    onVisibleChanged: {
                        if (visible) {
                            dashboardProgress = 1.0
                        }
                    }
                }
                
                Connections {
                    target: root
                    function onShowDashboardChanged() {
                        if (!showDashboard) {
                            dashboardProgress = 0.0
                        } else {
                            dashboardProgress = 1.0
                        }
                    }
                }

                // ===== MAIN BAR =====
                PanelWindow {
                    id: bar
                    screen: modelData
                    visible: modelData.name === "DP-1"
                    
                    anchors { top: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Auto
                    exclusiveZone: 36
                    height: 36
                    focusable: false
                    color: colorBgSecondary

                    Item {
                        anchors.fill: parent
                        anchors.margins: 3
                        anchors.leftMargin: 7
                        anchors.rightMargin: 7

                        // LEFT - Workspaces
                        RowLayout {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Rectangle {
                                color: colorBgPrimary
                                radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: wsRow.width + 18

                                RowLayout {
                                    id: wsRow
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Repeater {
                                        model: 6

                                        Rectangle {
                                            id: wsBtn
                                            property int wsNum: index + 1
                                            property bool isActive: Hyprland.focusedMonitor?.activeWorkspace?.id === wsNum
                                            property bool hasWindows: {
                                                for (let i = 0; i < Hyprland.workspaces.values.length; i++)
                                                    if (Hyprland.workspaces.values[i].id === wsNum) return true
                                                return false
                                            }

                                            width: 24
                                            height: 24
                                            radius: 5
                                            color: isActive ? colorAccent : 
                                                   wsMouse.containsMouse ? Qt.rgba(0.91, 0.71, 0.64, 0.2) : "transparent"
                                            
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: wsBtn.wsNum
                                                color: wsBtn.isActive ? colorBgPrimary : colorTextPrimary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                                opacity: wsBtn.hasWindows || wsBtn.isActive ? 1.0 : 0.5
                                            }

                                            MouseArea {
                                                id: wsMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Hyprland.dispatch("workspace " + wsBtn.wsNum)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // CENTER - Clock (триггер для Dashboard)
                        Rectangle {
                            id: centerClock
                            anchors.centerIn: parent
                            color: colorBgPrimary
                            radius: 5
                            height: 30
                            width: clockRow.implicitWidth + 18

                            Row {
                                id: clockRow
                                anchors.centerIn: parent
                                spacing: 6
                                
                                Text {
                                    id: clockDate
                                    text: Qt.formatDateTime(new Date(), "ddd dd MMM yyyy")
                                    color: colorTextPrimary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                
                                Text {
                                    text: "\uf017"
                                    color: colorTextPrimary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                
                                Text {
                                    id: clockTime
                                    text: Qt.formatDateTime(new Date(), "HH:mm")
                                    color: colorTextPrimary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                            }

                            Timer {
                                interval: 1000
                                running: true
                                repeat: true
                                onTriggered: {
                                    let now = new Date()
                                    clockDate.text = Qt.formatDateTime(now, "ddd dd MMM yyyy")
                                    clockTime.text = Qt.formatDateTime(now, "HH:mm")
                                }
                            }

                            HoverHandler {
                                onHoveredChanged: {
                                    isMouseOverDashboard = hovered
                                    if (hovered) openDashboard()
                                    else hideDashboardTimer.restart()
                                }
                            }
                            
                            TapHandler {
                                onTapped: {
                                    if (showDashboard) closeDashboard()
                                    else openDashboard()
                                }
                            }
                        }

                        // RIGHT
                        RowLayout {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            // Language
                            Rectangle {
                                color: colorBgPrimary
                                radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: langRow.implicitWidth + 18

                                Row {
                                    id: langRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    
                                    Text {
                                        text: "\uf11c"
                                        color: colorTextPrimary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }
                                    
                                    Text {
                                        text: currentLanguage
                                        color: colorTextPrimary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }
                                }
                            }

                            // Audio
                            Rectangle {
                                color: colorBgPrimary
                                radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: audioRow.implicitWidth + 18

                                Process {
                                    id: pavuProcess
                                    command: ["pavucontrol"]
                                }

                                Row {
                                    id: audioRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Item {
                                        width: volRow.width
                                        height: 30
                                        
                                        Row {
                                            id: volRow
                                            spacing: 4
                                            anchors.centerIn: parent
                                            
                                            Text {
                                                text: volume === 0 ? "\uf6a9" : volume > 66 ? "\uf028" : volume > 33 ? "\uf027" : "\uf026"
                                                color: colorTextPrimary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                            }
                                            
                                            Text {
                                                text: volume + "%"
                                                color: colorTextPrimary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                            }
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton
                                            onClicked: pavuProcess.running = true
                                            onWheel: wheel => {
                                                let nv = Math.max(0, Math.min(100, volume + (wheel.angleDelta.y > 0 ? 5 : -5)))
                                                volumeChangeProcess.targetVolume = nv
                                                volumeChangeProcess.running = true
                                            }
                                        }
                                    }

                                    Item {
                                        width: micRow.width
                                        height: 30
                                        
                                        Row {
                                            id: micRow
                                            spacing: 4
                                            anchors.centerIn: parent
                                            
                                            Text {
                                                text: micVolume === 0 ? "\uf131" : "\uf130"
                                                color: colorTextPrimary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                            }
                                            
                                            Text {
                                                text: micVolume > 0 ? micVolume + "%" : ""
                                                color: colorTextPrimary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                                visible: micVolume > 0
                                            }
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton
                                            onClicked: pavuProcess.running = true
                                            onWheel: wheel => {
                                                let nv = Math.max(0, Math.min(100, micVolume + (wheel.angleDelta.y > 0 ? 5 : -5)))
                                                micChangeProcess.targetVolume = nv
                                                micChangeProcess.running = true
                                            }
                                        }
                                    }
                                }
                            }

                            // Hardware
                            Rectangle {
                                color: colorBgPrimary
                                radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: hwRow.implicitWidth + 18

                                Row {
                                    id: hwRow
                                    anchors.centerIn: parent
                                    spacing: 10
                                    
                                    Row {
                                        spacing: 4
                                        
                                        Text {
                                            text: cpuUsage + "%"
                                            color: colorTextPrimary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                        }
                                        
                                        Text {
                                            text: "\uf2db"
                                            color: colorTextPrimary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                        }
                                    }
                                    
                                    Row {
                                        spacing: 4
                                        
                                        Text {
                                            text: memoryUsage + "%"
                                            color: colorTextPrimary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                        }
                                        
                                        Text {
                                            text: "\uefc5"
                                            color: colorTextPrimary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                        }
                                    }
                                }
                            }

                            // Network
                            Rectangle {
                                color: colorBgPrimary
                                radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: netText.implicitWidth + 18

                                Process {
                                    id: nmProcess
                                    command: ["nm-connection-editor"]
                                }

                                MouseArea {
                                    id: netMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: nmProcess.running = true
                                }

                                Text {
                                    id: netText
                                    anchors.centerIn: parent
                                    text: networkStatus === "wifi" ? "\uf1eb" : networkStatus === "ethernet" ? "\uf796" : "\uf06a"
                                    color: colorTextPrimary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15
                                }

                                Rectangle {
                                    visible: netMouse.containsMouse && networkSSID !== ""
                                    color: colorBgPrimary
                                    radius: 5
                                    width: ttText.implicitWidth + 16
                                    height: ttText.implicitHeight + 8
                                    z: 1000
                                    anchors.top: parent.bottom
                                    anchors.topMargin: 5
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Text {
                                        id: ttText
                                        anchors.centerIn: parent
                                        text: "SSID: " + networkSSID
                                        color: colorTextPrimary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
