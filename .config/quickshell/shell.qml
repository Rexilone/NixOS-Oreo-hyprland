import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ShellRoot {
    id: root

    // Цвета
    readonly property color colorBgPrimary: "#151515"
    readonly property color colorBgSecondary: "transparent"
    readonly property color colorBgWorkspaceActive: "#fff0f5"
    readonly property color colorBgWorkspaceHover: Qt.rgba(0, 0, 0, 0.2)
    readonly property color colorTextPrimary: "#ffffff"
    readonly property color colorTextSecondary: "#dcd7ba"
    readonly property color colorTextWorkspaceActive: "#000000"

    // Данные системы
    property int cpuUsage: 0
    property int memoryUsage: 0
    property int volume: 50
    property int micVolume: 80
    property int brightness: 50
    property int batteryLevel: 0
    property bool batteryCharging: false
    property string networkStatus: "wifi"
    property string networkSSID: ""
    property string currentLanguage: "EN"

    // Dynamic Island visibility
    property bool showDynamicIsland: false

    // Music Player
    property string musicTitle: "No Track Playing"
    property string musicArtist: "Unknown Artist"
    property string musicAlbum: ""
    property string musicArtUrl: ""
    property bool musicPlaying: false
    property bool musicCanPlay: false
    property bool musicCanPause: false
    property bool musicCanGoNext: false
    property bool musicCanGoPrevious: false

    // Wallpapers
    property var wallpaperList: []
    property int currentWallpaperIndex: 0
    property string wallpaperBuffer: ""

    // Notifications
    property var notifications: [
        { id: 1, title: "System Update", body: "New updates available", time: "5m ago" },
        { id: 2, title: "Battery Low", body: "15% remaining", time: "10m ago" }
    ]

    // Network
    property int currentNetworkTab: 0 // 0 = WiFi, 1 = Bluetooth
    property var wifiNetworks: [
        { ssid: "Home WiFi", signal: 85, secured: true, connected: true },
        { ssid: "Guest Network", signal: 60, secured: true, connected: false },
        { ssid: "Neighbor WiFi", signal: 45, secured: true, connected: false }
    ]
    property var bluetoothDevices: [
        { name: "AirPods Pro", connected: true, battery: 85, type: "audio" },
        { name: "Magic Mouse", connected: true, battery: 60, type: "input" },
        { name: "Sony Headphones", connected: false, battery: 0, type: "audio" }
    ]

    // User changing flags для ползунков
    property bool brightnessUserChanging: false
    property bool volumeUserChanging: false
    property bool micUserChanging: false

    // ===== ЯЗЫК =====
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: langProcess.running = true
    }

    Process {
        id: langProcess
        command: ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap'"]
        stdout: SplitParser {
            onRead: data => {
                let layout = data.trim()
                if (layout.toLowerCase().includes("russian") || layout.toLowerCase().includes("ru")) {
                    root.currentLanguage = "RU"
                } else if (layout.toLowerCase().includes("english") || layout.toLowerCase().includes("us") || layout.toLowerCase().includes("en")) {
                    root.currentLanguage = "EN"
                } else if (layout !== "" && layout !== "null") {
                    root.currentLanguage = layout.substring(0, 2).toUpperCase()
                } else {
                    root.currentLanguage = "EN"
                }
            }
        }
    }

    Process {
        id: hyprlandSocket
        running: true
        command: ["sh", "-c", `
            socat -u UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - 2>/dev/null | while IFS= read -r line; do
                if echo "$line" | grep -q "activelayout>>"; then
                    echo "LAYOUT_CHANGED"
                fi
            done
        `]
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("LAYOUT_CHANGED")) {
                    langProcess.running = true
                }
            }
        }
    }

    // ===== CPU монитор =====
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: cpuProcess.running = true
    }

    Process {
        id: cpuProcess
        command: ["sh", "-c", "grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf \"%.0f\", usage}'"]
        stdout: SplitParser {
            onRead: data => root.cpuUsage = parseInt(data.trim()) || 0
        }
    }

    // ===== Memory монитор =====
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: memProcess.running = true
    }

    Process {
        id: memProcess
        command: ["sh", "-c", "free | awk '/Mem:/ {printf \"%.0f\", $3/$2 * 100}'"]
        stdout: SplitParser {
            onRead: data => root.memoryUsage = parseInt(data.trim()) || 0
        }
    }

    // ===== Battery монитор =====
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            batteryLevelProcess.running = true
            batteryStatusProcess.running = true
        }
    }

    Process {
        id: batteryLevelProcess
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1 || echo '0'"]
        stdout: SplitParser {
            onRead: data => root.batteryLevel = parseInt(data.trim()) || 0
        }
    }

    Process {
        id: batteryStatusProcess
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1 || echo 'Unknown'"]
        stdout: SplitParser {
            onRead: data => root.batteryCharging = data.trim() === "Charging"
        }
    }

    // ===== Brightness монитор =====
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            if (!root.brightnessUserChanging) {
                brightnessProcess.running = true
            }
        }
    }

    Process {
        id: brightnessProcess
        command: ["sh", "-c", "brightnessctl get 2>/dev/null && brightnessctl max 2>/dev/null | awk 'NR==1{current=$1} NR==2{max=$1} END{printf \"%.0f\", (current/max)*100}' || echo '50'"]
        stdout: SplitParser {
            onRead: data => {
                if (!root.brightnessUserChanging) {
                    root.brightness = parseInt(data.trim()) || 50
                }
            }
        }
    }

    Process {
        id: brightnessChangeProcess
        property int targetBrightness: 50
        command: ["brightnessctl", "set", targetBrightness + "%"]
    }

    // ===== Volume монитор =====
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (!root.volumeUserChanging) {
                volumeProcess.running = true
            }
            if (!root.micUserChanging) {
                micProcess.running = true
            }
        }
    }

    Process {
        id: volumeProcess
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{muted=($3==\"[MUTED]\")?1:0; vol=int($2*100); print vol\" \"muted}' || pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -o '[0-9]*%' | head -1 | tr -d '%' | awk '{print $1\" 0\"}'"]
        stdout: SplitParser {
            onRead: data => {
                if (!root.volumeUserChanging) {
                    let parts = data.trim().split(' ')
                    if (parts.length >= 2) {
                        root.volume = parseInt(parts[0]) || 0
                    }
                }
            }
        }
    }

    Process {
        id: micProcess
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk '{muted=($3==\"[MUTED]\")?1:0; vol=int($2*100); print vol\" \"muted}' || pactl get-source-volume @DEFAULT_SOURCE@ 2>/dev/null | grep -o '[0-9]*%' | head -1 | tr -d '%' | awk '{print $1\" 0\"}'"]
        stdout: SplitParser {
            onRead: data => {
                if (!root.micUserChanging) {
                    let parts = data.trim().split(' ')
                    if (parts.length >= 2) {
                        root.micVolume = parseInt(parts[0]) || 0
                    }
                }
            }
        }
    }

    Process {
        id: volumeChangeProcess
        property int targetVolume: 50
        command: ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + targetVolume + "% 2>/dev/null || pactl set-sink-volume @DEFAULT_SINK@ " + targetVolume + "%"]
    }

    Process {
        id: micChangeProcess
        property int targetVolume: 50
        command: ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + targetVolume + "% 2>/dev/null || pactl set-source-volume @DEFAULT_SOURCE@ " + targetVolume + "%"]
    }

    // ===== Network монитор =====
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: networkProcess.running = true
    }

    Process {
        id: networkProcess
        command: ["sh", "-c", "if ping -c 1 8.8.8.8 >/dev/null 2>&1; then if iwgetid -r 2>/dev/null; then echo 'wifi'; else echo 'ethernet'; fi; else echo 'disconnected'; fi"]
        stdout: SplitParser {
            onRead: data => {
                let status = data.trim()
                if (status === "wifi") {
                    root.networkStatus = "wifi"
                    ssidProcess.running = true
                } else if (status === "ethernet") {
                    root.networkStatus = "ethernet"
                    root.networkSSID = ""
                } else {
                    root.networkStatus = "disconnected"
                    root.networkSSID = ""
                }
            }
        }
    }

    Process {
        id: ssidProcess
        command: ["sh", "-c", "iwgetid -r 2>/dev/null || echo ''"]
        stdout: SplitParser {
            onRead: data => root.networkSSID = data.trim()
        }
    }

    // ===== Music Player Monitor =====
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            playerctlMetadataProcess.running = true
            playerctlStatusProcess.running = true
        }
    }

    Process {
        id: playerctlMetadataProcess
        command: ["sh", "-c", "playerctl metadata --format '{{title}}|{{artist}}|{{album}}|{{mpris:artUrl}}' 2>/dev/null || echo 'No Track Playing|Unknown Artist||'"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split('|')
                root.musicTitle = parts[0] || "No Track Playing"
                root.musicArtist = parts[1] || "Unknown Artist"
                root.musicAlbum = parts[2] || ""
                root.musicArtUrl = parts[3] || ""
            }
        }
    }

    Process {
        id: playerctlStatusProcess
        command: ["sh", "-c", "playerctl status 2>/dev/null || echo 'Stopped'"]
        stdout: SplitParser {
            onRead: data => {
                let status = data.trim()
                root.musicPlaying = (status === "Playing")
                root.musicCanPlay = (status !== "Stopped")
                root.musicCanPause = (status === "Playing")
                root.musicCanGoNext = (status !== "Stopped")
                root.musicCanGoPrevious = (status !== "Stopped")
            }
        }
    }

    Process {
        id: playerctlPlayPauseProcess
        command: ["playerctl", "play-pause"]
    }

    Process {
        id: playerctlNextProcess
        command: ["playerctl", "next"]
    }

    Process {
        id: playerctlPreviousProcess
        command: ["playerctl", "previous"]
    }

    // ===== Wallpaper Scanner =====
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: wallpaperScanProcess.running = true
    }

    Process {
        id: wallpaperScanProcess
        command: ["sh", "-c", "find ~/Pictures/Wallpapers -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \\) 2>/dev/null | sort"]
        
        stdout: SplitParser {
            onRead: data => {
                root.wallpaperBuffer += data
            }
        }
        
        onRunningChanged: {
            if (!running && wallpaperBuffer.length > 0) {
                let lines = wallpaperBuffer.trim().split('\n').filter(x => x.trim() !== '')
                root.wallpaperList = lines
                console.log("Found", lines.length, "wallpapers:")
                for (let i = 0; i < Math.min(5, lines.length); i++) {
                    console.log("  -", lines[i])
                }
                root.wallpaperBuffer = ""
            }
        }
    }

    Process {
        id: swwwSetWallpaperProcess
        property string wallpaperPath: ""
        command: ["swww", "img", wallpaperPath, "--transition-type", "fade", "--transition-duration", "2"]
        onRunningChanged: {
            if (!running) {
                console.log("Wallpaper set to:", wallpaperPath)
            }
        }
    }

    Component.onCompleted: {
        networkProcess.running = true
        langProcess.running = true
        batteryLevelProcess.running = true
        batteryStatusProcess.running = true
        brightnessProcess.running = true
        wallpaperScanProcess.running = true
    }

    // Timer для скрытия Dynamic Island
    Timer {
        id: hideIslandTimer
        interval: 300
        onTriggered: {
            root.showDynamicIsland = false
        }
    }

    Variants {
        model: Quickshell.screens
        
        delegate: Component {
            Item {
                property var modelData

                // ===== DYNAMIC ISLAND WINDOW =====
                PanelWindow {
                    id: dynamicIsland
                    screen: modelData
                    visible: root.showDynamicIsland && modelData.name === "DP-1"
                    
                    anchors {
                        top: true
                        left: true
                    }
                    
                    margins {
                        top: 3
                        left: (modelData.width - 940) / 2
                    }
                    
                    width: 940
                    height: 530
                    
                    color: "transparent"
                    focusable: false
                    exclusionMode: ExclusionMode.Ignore
                    
                    Rectangle {
                        id: islandBackground
                        anchors.fill: parent
                        color: root.colorBgPrimary
                        radius: 15
                        
                        // Основная MouseArea для отслеживания hover на всем окне
                        MouseArea {
                            id: islandMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            propagateComposedEvents: true
                            
                            onEntered: {
                                hideIslandTimer.stop()
                                root.showDynamicIsland = true
                            }
                            
                            onExited: {
                                hideIslandTimer.restart()
                            }
                            
                            onPressed: mouse => {
                                mouse.accepted = false  // Пропускаем клики дальше
                            }
                            
                            onWheel: wheel => {
                                wheel.accepted = false  // Пропускаем скролл дальше
                            }
                        }
                        
                        Column {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 15
                            
                            // Tab selector
                            Row {
                                width: parent.width
                                height: 40
                                spacing: 10
                                
                                property int currentTab: 0
                                
                                Repeater {
                                    model: ["Dashboard", "Wallpapers", "Network"]
                                    
                                    Rectangle {
                                        width: (parent.width - 20) / 3
                                        height: 40
                                        radius: 8
                                        color: parent.currentTab === index ? root.colorBgWorkspaceActive : Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: parent.parent.currentTab === index ? root.colorTextWorkspaceActive : root.colorTextSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: parent.parent.currentTab = index
                                        }
                                    }
                                }
                            }
                            
                            // Content area
                            Item {
                                width: parent.width
                                height: parent.height - 55
                                
                                // ===== DASHBOARD TAB =====
                                Item {
                                    anchors.fill: parent
                                    visible: parent.parent.children[0].currentTab === 0
                                    
                                    Column {
                                        anchors.fill: parent
                                        spacing: 15
                                        
                                        // Music Player
                                        Rectangle {
                                            width: parent.width
                                            height: 100
                                            color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                            radius: 10
                                            
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 15
                                                spacing: 15
                                                
                                                // Album Art
                                                Rectangle {
                                                    width: 70
                                                    height: 70
                                                    radius: 8
                                                    color: Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                    clip: true
                                                    
                                                    Image {
                                                        anchors.fill: parent
                                                        source: root.musicArtUrl
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        visible: root.musicArtUrl !== ""
                                                    }
                                                    
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "\uf001"
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 30
                                                        color: root.colorTextSecondary
                                                        opacity: 0.3
                                                        visible: root.musicArtUrl === ""
                                                    }
                                                }
                                                
                                                // Track Info
                                                Column {
                                                    width: parent.width - 85 - 150
                                                    height: 70
                                                    spacing: 5
                                                    
                                                    Text {
                                                        text: root.musicTitle
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 16
                                                        font.weight: Font.Bold
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }
                                                    
                                                    Text {
                                                        text: root.musicArtist
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 13
                                                        opacity: 0.7
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }
                                                }
                                                
                                                // Controls
                                                Item {
                                                    width: 150
                                                    height: 70
                                                    
                                                    Row {
                                                        anchors.centerIn: parent
                                                        anchors.rightMargin: 10
                                                        spacing: 10
                                                        
                                                        // Previous
                                                        Rectangle {
                                                            width: 35
                                                            height: 35
                                                            radius: 17.5
                                                            color: Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                            
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "\uf048"
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 14
                                                                color: root.colorTextSecondary
                                                            }
                                                            
                                                            MouseArea {
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                onClicked: playerctlPreviousProcess.running = true
                                                            }
                                                        }
                                                        
                                                        // Play/Pause
                                                        Rectangle {
                                                            width: 40
                                                            height: 40
                                                            radius: 20
                                                            color: root.colorBgWorkspaceActive
                                                            
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: root.musicPlaying ? "\uf04c" : "\uf04b"
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 16
                                                                color: root.colorTextWorkspaceActive
                                                            }
                                                            
                                                            MouseArea {
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                onClicked: playerctlPlayPauseProcess.running = true
                                                            }
                                                        }
                                                        
                                                        // Next
                                                        Rectangle {
                                                            width: 35
                                                            height: 35
                                                            radius: 17.5
                                                            color: Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                            
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "\uf051"
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 14
                                                                color: root.colorTextSecondary
                                                            }
                                                            
                                                            MouseArea {
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                onClicked: playerctlNextProcess.running = true
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Stats Row
                                        Row {
                                            width: parent.width
                                            height: 60
                                            spacing: 10
                                            
                                            // CPU
                                            Rectangle {
                                                width: (parent.width - 20) / 3
                                                height: 60
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                radius: 10
                                                
                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: 5
                                                    
                                                    Row {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        spacing: 6
                                                        
                                                        Text {
                                                            text: "\uf2db"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 14
                                                        }
                                                        Text {
                                                            text: "CPU"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 13
                                                        }
                                                    }
                                                    
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: root.cpuUsage + "%"
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 18
                                                        font.weight: Font.Bold
                                                    }
                                                }
                                            }
                                            
                                            // RAM
                                            Rectangle {
                                                width: (parent.width - 20) / 3
                                                height: 60
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                radius: 10
                                                
                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: 5
                                                    
                                                    Row {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        spacing: 6
                                                        
                                                        Text {
                                                            text: "\uefc5"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 15
                                                        }
                                                        Text {
                                                            text: "RAM"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 13
                                                        }
                                                    }
                                                    
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: root.memoryUsage + "%"
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 18
                                                        font.weight: Font.Bold
                                                    }
                                                }
                                            }
                                            
                                            // Battery
                                            Rectangle {
                                                width: (parent.width - 20) / 3
                                                height: 60
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                radius: 10
                                                
                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: 5
                                                    
                                                    Row {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        spacing: 6
                                                        
                                                        Text {
                                                            text: root.batteryCharging ? "\uf0e7" : (root.batteryLevel > 80 ? "\uf240" : root.batteryLevel > 60 ? "\uf241" : root.batteryLevel > 40 ? "\uf242" : root.batteryLevel > 20 ? "\uf243" : "\uf244")
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 14
                                                        }
                                                        Text {
                                                            text: "Battery"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 13
                                                        }
                                                    }
                                                    
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: root.batteryLevel + "%"
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 18
                                                        font.weight: Font.Bold
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Sliders
                                        Column {
                                            width: parent.width
                                            spacing: 12
                                            
                                            // Brightness Slider
                                            Row {
                                                width: parent.width
                                                spacing: 15
                                                
                                                Text {
                                                    text: "\uf185"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 16
                                                    color: root.colorTextSecondary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                
                                                Slider {
                                                    id: brightnessSlider
                                                    width: parent.width - 80
                                                    from: 0
                                                    to: 100
                                                    value: root.brightness
                                                    
                                                    onValueChanged: {
                                                        if (pressed) {
                                                            root.brightnessUserChanging = true
                                                            brightnessChangeProcess.targetBrightness = Math.round(value)
                                                            brightnessChangeProcess.running = true
                                                        }
                                                    }
                                                    
                                                    onPressedChanged: {
                                                        if (!pressed) {
                                                            root.brightnessUserChanging = false
                                                        }
                                                    }
                                                    
                                                    background: Rectangle {
                                                        width: brightnessSlider.width
                                                        height: 6
                                                        color: Qt.rgba(220/255, 215/255, 186/255, 0.2)
                                                        radius: 3
                                                        
                                                        Rectangle {
                                                            width: brightnessSlider.visualPosition * parent.width
                                                            height: parent.height
                                                            color: root.colorBgWorkspaceActive
                                                            radius: 3
                                                        }
                                                    }
                                                    
                                                    handle: Rectangle {
                                                        x: brightnessSlider.visualPosition * (brightnessSlider.width - width)
                                                        y: (brightnessSlider.height - height) / 2
                                                        width: 18
                                                        height: 18
                                                        radius: 9
                                                        color: root.colorBgWorkspaceActive
                                                    }
                                                }
                                                
                                                Text {
                                                    text: Math.round(brightnessSlider.value) + "%"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 13
                                                    color: root.colorTextSecondary
                                                    width: 45
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                            
                                            // Volume Slider
                                            Row {
                                                width: parent.width
                                                spacing: 15
                                                
                                                Text {
                                                    text: "\uf028"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 16
                                                    color: root.colorTextSecondary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                
                                                Slider {
                                                    id: volumeSlider
                                                    width: parent.width - 80
                                                    from: 0
                                                    to: 100
                                                    value: root.volume
                                                    
                                                    onValueChanged: {
                                                        if (pressed) {
                                                            root.volumeUserChanging = true
                                                            volumeChangeProcess.targetVolume = Math.round(value)
                                                            volumeChangeProcess.running = true
                                                        }
                                                    }
                                                    
                                                    onPressedChanged: {
                                                        if (!pressed) {
                                                            root.volumeUserChanging = false
                                                        }
                                                    }
                                                    
                                                    background: Rectangle {
                                                        width: volumeSlider.width
                                                        height: 6
                                                        color: Qt.rgba(220/255, 215/255, 186/255, 0.2)
                                                        radius: 3
                                                        
                                                        Rectangle {
                                                            width: volumeSlider.visualPosition * parent.width
                                                            height: parent.height
                                                            color: root.colorBgWorkspaceActive
                                                            radius: 3
                                                        }
                                                    }
                                                    
                                                    handle: Rectangle {
                                                        x: volumeSlider.visualPosition * (volumeSlider.width - width)
                                                        y: (volumeSlider.height - height) / 2
                                                        width: 18
                                                        height: 18
                                                        radius: 9
                                                        color: root.colorBgWorkspaceActive
                                                    }
                                                }
                                                
                                                Text {
                                                    text: Math.round(volumeSlider.value) + "%"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 13
                                                    color: root.colorTextSecondary
                                                    width: 45
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                            
                                            // Mic Slider
                                            Row {
                                                width: parent.width
                                                spacing: 15
                                                
                                                Text {
                                                    text: "\uf130"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 16
                                                    color: root.colorTextSecondary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                
                                                Slider {
                                                    id: micSlider
                                                    width: parent.width - 80
                                                    from: 0
                                                    to: 100
                                                    value: root.micVolume
                                                    
                                                    onValueChanged: {
                                                        if (pressed) {
                                                            root.micUserChanging = true
                                                            micChangeProcess.targetVolume = Math.round(value)
                                                            micChangeProcess.running = true
                                                        }
                                                    }
                                                    
                                                    onPressedChanged: {
                                                        if (!pressed) {
                                                            root.micUserChanging = false
                                                        }
                                                    }
                                                    
                                                    background: Rectangle {
                                                        width: micSlider.width
                                                        height: 6
                                                        color: Qt.rgba(220/255, 215/255, 186/255, 0.2)
                                                        radius: 3
                                                        
                                                        Rectangle {
                                                            width: micSlider.visualPosition * parent.width
                                                            height: parent.height
                                                            color: root.colorBgWorkspaceActive
                                                            radius: 3
                                                        }
                                                    }
                                                    
                                                    handle: Rectangle {
                                                        x: micSlider.visualPosition * (micSlider.width - width)
                                                        y: (micSlider.height - height) / 2
                                                        width: 18
                                                        height: 18
                                                        radius: 9
                                                        color: root.colorBgWorkspaceActive
                                                    }
                                                }
                                                
                                                Text {
                                                    text: Math.round(micSlider.value) + "%"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 13
                                                    color: root.colorTextSecondary
                                                    width: 45
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }
                                        
                                        // Notifications
                                        Rectangle {
                                            width: parent.width
                                            height: 140
                                            color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                            radius: 10
                                            
                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 8
                                                
                                                Row {
                                                    width: parent.width
                                                    
                                                    Text {
                                                        text: "Notifications"
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 14
                                                        font.weight: Font.Bold
                                                        width: parent.width - 90
                                                    }
                                                    
                                                    Rectangle {
                                                        width: 80
                                                        height: 24
                                                        radius: 5
                                                        color: Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                        
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "Clear All"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 11
                                                        }
                                                        
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            onClicked: root.notifications = []
                                                        }
                                                    }
                                                }
                                                
                                                Column {
                                                    width: parent.width
                                                    spacing: 6
                                                    
                                                    Repeater {
                                                        model: root.notifications.slice(0, 2)
                                                        
                                                        Rectangle {
                                                            width: parent.width
                                                            height: 40
                                                            color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                            radius: 6
                                                            
                                                            Row {
                                                                anchors.fill: parent
                                                                anchors.margins: 8
                                                                spacing: 8
                                                                
                                                                Column {
                                                                    width: parent.width - 30
                                                                    spacing: 2
                                                                    
                                                                    Text {
                                                                        text: modelData.title
                                                                        color: root.colorTextSecondary
                                                                        font.family: "JetBrainsMono Nerd Font"
                                                                        font.pixelSize: 12
                                                                        font.weight: Font.Medium
                                                                        elide: Text.ElideRight
                                                                        width: parent.width
                                                                    }
                                                                    
                                                                    Text {
                                                                        text: modelData.body
                                                                        color: root.colorTextSecondary
                                                                        font.family: "JetBrainsMono Nerd Font"
                                                                        font.pixelSize: 10
                                                                        opacity: 0.6
                                                                        elide: Text.ElideRight
                                                                        width: parent.width
                                                                    }
                                                                }
                                                                
                                                                Text {
                                                                    text: "\uf00d"
                                                                    color: root.colorTextSecondary
                                                                    font.family: "JetBrainsMono Nerd Font"
                                                                    font.pixelSize: 12
                                                                    opacity: 0.5
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    
                                                                    MouseArea {
                                                                        anchors.fill: parent
                                                                        hoverEnabled: true
                                                                        onClicked: {
                                                                            let newNotifs = []
                                                                            for (let i = 0; i < root.notifications.length; i++) {
                                                                                if (root.notifications[i].id !== modelData.id) {
                                                                                    newNotifs.push(root.notifications[i])
                                                                                }
                                                                            }
                                                                            root.notifications = newNotifs
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
                                }
                                
                                // ===== WALLPAPERS TAB =====
                                Item {
                                    anchors.fill: parent
                                    visible: parent.parent.children[0].currentTab === 1
                                    
                                    Column {
                                        anchors.fill: parent
                                        spacing: 20
                                        
                                        // Carousel
                                        Item {
                                            width: parent.width
                                            height: 330
                                            
                                            // Center Preview
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 500
                                                height: 300
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                radius: 12
                                                clip: true
                                                
                                                Image {
                                                    anchors.fill: parent
                                                    source: root.wallpaperList.length > 0 ? ("file://" + root.wallpaperList[root.currentWallpaperIndex]) : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    
                                                    onStatusChanged: {
                                                        if (status === Image.Ready) {
                                                            console.log("Image loaded:", source)
                                                        } else if (status === Image.Error) {
                                                            console.log("Image error:", source)
                                                        }
                                                    }
                                                }
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.wallpaperList.length === 0 ? "No wallpapers found" : "Loading..."
                                                    color: root.colorTextSecondary
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 16
                                                    opacity: 0.5
                                                    visible: parent.children[0].status !== Image.Ready
                                                }
                                            }
                                            
                                            // Left Preview
                                            Rectangle {
                                                anchors.right: parent.horizontalCenter
                                                anchors.rightMargin: 270
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 150
                                                height: 100
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                radius: 8
                                                opacity: 0.5
                                                clip: true
                                                visible: root.wallpaperList.length > 1
                                                
                                                Image {
                                                    anchors.fill: parent
                                                    source: {
                                                        if (root.wallpaperList.length <= 1) return ""
                                                        let prevIndex = root.currentWallpaperIndex - 1
                                                        if (prevIndex < 0) prevIndex = root.wallpaperList.length - 1
                                                        return "file://" + root.wallpaperList[prevIndex]
                                                    }
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                }
                                            }
                                            
                                            // Right Preview
                                            Rectangle {
                                                anchors.left: parent.horizontalCenter
                                                anchors.leftMargin: 270
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 150
                                                height: 100
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                radius: 8
                                                opacity: 0.5
                                                clip: true
                                                visible: root.wallpaperList.length > 1
                                                
                                                Image {
                                                    anchors.fill: parent
                                                    source: {
                                                        if (root.wallpaperList.length <= 1) return ""
                                                        let nextIndex = root.currentWallpaperIndex + 1
                                                        if (nextIndex >= root.wallpaperList.length) nextIndex = 0
                                                        return "file://" + root.wallpaperList[nextIndex]
                                                    }
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                }
                                            }
                                            
                                            // Left Arrow
                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 20
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 50
                                                height: 50
                                                radius: 25
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                visible: root.wallpaperList.length > 1
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf053"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 20
                                                    color: root.colorTextSecondary
                                                }
                                                
                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        if (root.wallpaperList.length > 0) {
                                                            root.currentWallpaperIndex = (root.currentWallpaperIndex - 1 + root.wallpaperList.length) % root.wallpaperList.length
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            // Right Arrow
                                            Rectangle {
                                                anchors.right: parent.right
                                                anchors.rightMargin: 20
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 50
                                                height: 50
                                                radius: 25
                                                color: Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                visible: root.wallpaperList.length > 1
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf054"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 20
                                                    color: root.colorTextSecondary
                                                }
                                                
                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        if (root.wallpaperList.length > 0) {
                                                            root.currentWallpaperIndex = (root.currentWallpaperIndex + 1) % root.wallpaperList.length
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Counter and Button
                                        Column {
                                            width: parent.width
                                            spacing: 15
                                            
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: root.wallpaperList.length > 0 ? ((root.currentWallpaperIndex + 1) + " / " + root.wallpaperList.length) : "0 / 0"
                                                color: root.colorTextSecondary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 14
                                                opacity: 0.7
                                            }
                                            
                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 200
                                                height: 45
                                                radius: 10
                                                color: root.colorBgWorkspaceActive
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Set as Wallpaper"
                                                    color: root.colorTextWorkspaceActive
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 14
                                                    font.weight: Font.Bold
                                                }
                                                
                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        if (root.wallpaperList.length > 0) {
                                                            swwwSetWallpaperProcess.wallpaperPath = root.wallpaperList[root.currentWallpaperIndex]
                                                            swwwSetWallpaperProcess.running = true
                                                            console.log("Setting wallpaper:", root.wallpaperList[root.currentWallpaperIndex])
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // ===== NETWORK TAB =====
                                Item {
                                    anchors.fill: parent
                                    visible: parent.parent.children[0].currentTab === 2
                                    
                                    Column {
                                        anchors.fill: parent
                                        spacing: 15
                                        
                                        // WiFi / Bluetooth selector
                                        Row {
                                            width: parent.width
                                            height: 35
                                            spacing: 10
                                            
                                            Repeater {
                                                model: ["WiFi", "Bluetooth"]
                                                
                                                Rectangle {
                                                    width: (parent.width - 10) / 2
                                                    height: 35
                                                    radius: 8
                                                    color: root.currentNetworkTab === index ? root.colorBgWorkspaceActive : Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                    
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData
                                                        color: root.currentNetworkTab === index ? root.colorTextWorkspaceActive : root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 13
                                                        font.weight: Font.Bold
                                                    }
                                                    
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onClicked: root.currentNetworkTab = index
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // WiFi Panel
                                        Item {
                                            width: parent.width
                                            height: parent.height - 50
                                            visible: root.currentNetworkTab === 0
                                            
                                            Column {
                                                anchors.fill: parent
                                                spacing: 10
                                                
                                                Row {
                                                    width: parent.width
                                                    spacing: 10
                                                    
                                                    Text {
                                                        text: "WiFi Networks"
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 14
                                                        font.weight: Font.Bold
                                                        width: parent.width - 110
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    
                                                    Rectangle {
                                                        width: 100
                                                        height: 30
                                                        radius: 6
                                                        color: Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                        
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "\uf021 Scan"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 12
                                                        }
                                                        
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            onClicked: console.log("Scanning WiFi...")
                                                        }
                                                    }
                                                }
                                                
                                                Column {
                                                    width: parent.width
                                                    spacing: 8
                                                    
                                                    Repeater {
                                                        model: root.wifiNetworks
                                                        
                                                        Rectangle {
                                                            width: parent.width
                                                            height: 50
                                                            color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                            radius: 8
                                                            
                                                            Row {
                                                                anchors.fill: parent
                                                                anchors.margins: 12
                                                                spacing: 12
                                                                
                                                                Text {
                                                                    text: "\uf1eb"
                                                                    font.family: "JetBrainsMono Nerd Font"
                                                                    font.pixelSize: 18
                                                                    color: root.colorTextSecondary
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                }
                                                                
                                                                Column {
                                                                    width: parent.width - 150
                                                                    spacing: 3
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    
                                                                    Text {
                                                                        text: modelData.ssid
                                                                        color: root.colorTextSecondary
                                                                        font.family: "JetBrainsMono Nerd Font"
                                                                        font.pixelSize: 13
                                                                        font.weight: Font.Medium
                                                                    }
                                                                    
                                                                    Text {
                                                                        text: "Signal: " + modelData.signal + "% " + (modelData.secured ? "\uf023" : "")
                                                                        color: root.colorTextSecondary
                                                                        font.family: "JetBrainsMono Nerd Font"
                                                                        font.pixelSize: 10
                                                                        opacity: 0.6
                                                                    }
                                                                }
                                                                
                                                                Rectangle {
                                                                    width: 80
                                                                    height: 28
                                                                    radius: 6
                                                                    color: modelData.connected ? "#4ade80" : Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    
                                                                    Text {
                                                                        anchors.centerIn: parent
                                                                        text: modelData.connected ? "Connected" : "Connect"
                                                                        color: modelData.connected ? "#000000" : root.colorTextSecondary
                                                                        font.family: "JetBrainsMono Nerd Font"
                                                                        font.pixelSize: 11
                                                                        font.weight: Font.Medium
                                                                    }
                                                                    
                                                                    MouseArea {
                                                                        anchors.fill: parent
                                                                        hoverEnabled: true
                                                                        onClicked: console.log("Connect to", modelData.ssid)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Bluetooth Panel
                                        Item {
                                            width: parent.width
                                            height: parent.height - 50
                                            visible: root.currentNetworkTab === 1
                                            
                                            Column {
                                                anchors.fill: parent
                                                spacing: 10
                                                
                                                Row {
                                                    width: parent.width
                                                    spacing: 10
                                                    
                                                    Text {
                                                        text: "Bluetooth Devices"
                                                        color: root.colorTextSecondary
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 14
                                                        font.weight: Font.Bold
                                                        width: parent.width - 110
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    
                                                    Rectangle {
                                                        width: 100
                                                        height: 30
                                                        radius: 6
                                                        color: Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                        
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "\uf021 Scan"
                                                            color: root.colorTextSecondary
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 12
                                                        }
                                                        
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            onClicked: console.log("Scanning Bluetooth...")
                                                        }
                                                    }
                                                }
                                                
                                                Column {
                                                    width: parent.width
                                                    spacing: 8
                                                    
                                                    Repeater {
                                                        model: root.bluetoothDevices
                                                        
                                                        Rectangle {
                                                            width: parent.width
                                                            height: 50
                                                            color: Qt.rgba(220/255, 215/255, 186/255, 0.05)
                                                            radius: 8
                                                            
                                                            Row {
                                                                anchors.fill: parent
                                                                anchors.margins: 12
                                                                spacing: 12
                                                                
                                                                Text {
                                                                    text: modelData.type === "audio" ? "\uf025" : "\uf11b"
                                                                    font.family: "JetBrainsMono Nerd Font"
                                                                    font.pixelSize: 18
                                                                    color: root.colorTextSecondary
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                }
                                                                
                                                                Column {
                                                                    width: parent.width - 190
                                                                    spacing: 3
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    
                                                                    Text {
                                                                        text: modelData.name
                                                                        color: root.colorTextSecondary
                                                                        font.family: "JetBrainsMono Nerd Font"
                                                                        font.pixelSize: 13
                                                                        font.weight: Font.Medium
                                                                    }
                                                                    
                                                                    Text {
                                                                        text: modelData.connected && modelData.battery > 0 ? ("Battery: " + modelData.battery + "%") : "Not connected"
                                                                        color: root.colorTextSecondary
                                                                        font.family: "JetBrainsMono Nerd Font"
                                                                        font.pixelSize: 10
                                                                        opacity: 0.6
                                                                    }
                                                                }
                                                                
                                                                Rectangle {
                                                                    width: 80
                                                                    height: 28
                                                                    radius: 6
                                                                    color: modelData.connected ? "#4ade80" : Qt.rgba(220/255, 215/255, 186/255, 0.1)
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    
                                                                    Text {
                                                                        anchors.centerIn: parent
                                                                        text: modelData.connected ? "Connected" : "Connect"
                                                                        color: modelData.connected ? "#000000" : root.colorTextSecondary
                                                                        font.family: "JetBrainsMono Nerd Font"
                                                                        font.pixelSize: 11
                                                                        font.weight: Font.Medium
                                                                    }
                                                                    
                                                                    MouseArea {
                                                                        anchors.fill: parent
                                                                        hoverEnabled: true
                                                                        onClicked: console.log("Connect to", modelData.name)
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
                            }
                        }
                    }
                }

                // ===== MAIN BAR WINDOW =====
                PanelWindow {
                    id: bar
                    screen: modelData
                    visible: modelData.name === "DP-1"

                    anchors {
                        top: true
                        left: true
                        right: true
                    }

                    exclusionMode: ExclusionMode.Auto
                    exclusiveZone: 36
                    height: 36
                    focusable: false
                    
                    color: root.colorBgSecondary

                    Item {
                        anchors.fill: parent
                        anchors.margins: 3
                        anchors.leftMargin: 7
                        anchors.rightMargin: 7

                        // LEFT
                        RowLayout {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Rectangle {
                                color: root.colorBgPrimary
                                radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: workspacesRow.width + 18

                                RowLayout {
                                    id: workspacesRow
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Repeater {
                                        model: 6

                                        Rectangle {
                                            id: wsButton
                                            property int wsNumber: index + 1
                                            property bool isActive: Hyprland.focusedMonitor?.activeWorkspace?.id === wsNumber
                                            property bool hasWindows: {
                                                for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
                                                    let ws = Hyprland.workspaces.values[i]
                                                    if (ws.id === wsNumber) return true
                                                }
                                                return false
                                            }

                                            width: 24
                                            height: 24
                                            radius: 5
                                            color: isActive ? root.colorBgWorkspaceActive : 
                                                   wsMouseArea.containsMouse ? root.colorBgWorkspaceHover : "transparent"

                                            Behavior on color {
                                                ColorAnimation { duration: 150 }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: wsNumber
                                                color: wsButton.isActive ? root.colorTextWorkspaceActive : root.colorTextSecondary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                                opacity: wsButton.hasWindows || wsButton.isActive ? 1.0 : 0.5
                                            }

                                            MouseArea {
                                                id: wsMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: Hyprland.dispatch("workspace " + wsButton.wsNumber)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // CENTER - часы с hover эффектом
                        Rectangle {
                            id: centerClock
                            anchors.centerIn: parent
                            color: root.colorBgPrimary
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
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                
                                Text {
                                    text: "\uf017"
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                                
                                Text {
                                    id: clockTime
                                    text: Qt.formatDateTime(new Date(), "HH:mm")
                                    color: root.colorTextSecondary
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

                            MouseArea {
                                id: clockMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                
                                onEntered: {
                                    hideIslandTimer.stop()
                                    root.showDynamicIsland = true
                                }
                                
                                onExited: {
                                    // Запускаем таймер скрытия с задержкой
                                    hideIslandTimer.restart()
                                }
                                
                                onClicked: {
                                    swancProcess.running = true
                                }
                            }

                            Process {
                                id: swancProcess
                                command: ["swaync-client", "-t", "-sw"]
                            }
                        }

                        // RIGHT
                        RowLayout {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            // Language
                            Rectangle {
                                color: root.colorBgPrimary
                                radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: langRow.implicitWidth + 18

                                Row {
                                    id: langRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "\uf11c"
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }
                                    Text {
                                        text: root.currentLanguage
                                        color: root.colorTextSecondary
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }
                                }
                            }

                            // Audio
                            Rectangle {
                                color: root.colorBgPrimary
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
                                        width: volumeRow.width
                                        height: 30
                                        
                                        Row {
                                            id: volumeRow
                                            spacing: 4
                                            anchors.centerIn: parent
                                            
                                            Text {
                                                text: {
                                                    if (root.volume === 0) return "\uf6a9"
                                                    if (root.volume > 66) return "\uf028"
                                                    if (root.volume > 33) return "\uf027"
                                                    return "\uf026"
                                                }
                                                color: root.colorTextSecondary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                            }
                                            Text {
                                                text: root.volume + "%"
                                                color: root.colorTextSecondary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                            }
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.NoButton
                                            onClicked: pavuProcess.running = true
                                            onWheel: wheel => {
                                                let delta = wheel.angleDelta.y > 0 ? 5 : -5
                                                let newVol = Math.max(0, Math.min(100, root.volume + delta))
                                                volumeChangeProcess.targetVolume = newVol
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
                                                text: root.micVolume === 0 ? "\uf131" : "\uf130"
                                                color: root.colorTextSecondary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                            }
                                            Text {
                                                text: root.micVolume === 0 ? "" : root.micVolume + "%"
                                                color: root.colorTextSecondary
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                                visible: root.micVolume > 0
                                            }
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.NoButton
                                            onClicked: pavuProcess.running = true
                                            onWheel: wheel => {
                                                let delta = wheel.angleDelta.y > 0 ? 5 : -5
                                                let newVol = Math.max(0, Math.min(100, root.micVolume + delta))
                                                micChangeProcess.targetVolume = newVol
                                                micChangeProcess.running = true
                                            }
                                        }
                                    }
                                }
                            }

                            // Hardware
                            Rectangle {
                                color: root.colorBgPrimary
                                radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: hardwareRow.implicitWidth + 18

                                Row {
                                    id: hardwareRow
                                    anchors.centerIn: parent
                                    spacing: 10

                                    Row {
                                        spacing: 4
                                        Text {
                                            text: root.cpuUsage + "%"
                                            color: root.colorTextSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                        }
                                        Text {
                                            text: "\uf2db"
                                            color: root.colorTextSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                        }
                                    }

                                    Row {
                                        spacing: 4
                                        Text {
                                            text: root.memoryUsage + "%"
                                            color: root.colorTextSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                        }
                                        Text {
                                            text: "\uefc5"
                                            color: root.colorTextSecondary
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                        }
                                    }
                                }
                            }

                            // Network
                            Rectangle {
                                color: root.colorBgPrimary
                                radius: 5
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: networkText.implicitWidth + 18

                                MouseArea {
                                    id: networkMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: nmProcess.running = true
                                }

                                Process {
                                    id: nmProcess
                                    command: ["nm-connection-editor"]
                                }

                                Text {
                                    id: networkText
                                    anchors.centerIn: parent
                                    text: {
                                        if (root.networkStatus === "wifi") return "\uf1eb"
                                        if (root.networkStatus === "ethernet") return "\uf796"
                                        return "\uf06a"
                                    }
                                    color: root.colorTextSecondary
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15
                                }

                                Rectangle {
                                    visible: networkMouseArea.containsMouse && root.networkSSID !== ""
                                    color: root.colorBgPrimary
                                    radius: 5
                                    width: tooltipText.implicitWidth + 16
                                    height: tooltipText.implicitHeight + 8
                                    z: 1000
                                    anchors.top: parent.bottom
                                    anchors.topMargin: 5
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Text {
                                        id: tooltipText
                                        anchors.centerIn: parent
                                        text: "SSID: " + root.networkSSID
                                        color: root.colorTextSecondary
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
