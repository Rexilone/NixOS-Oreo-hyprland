// shell.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel

ShellRoot {
    id: root
    
    property bool isVisible: true
    property string wallpapersPath: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
    
    // Graceful shutdown function
    function closeApp() {
        root.isVisible = false
        Qt.callLater(function() {
            Qt.quit()
        })
    }
    
    // Function to set wallpaper using systemd-run for isolation
    function setWallpaper(path) {
        console.log("Setting wallpaper to:", path)
        
        // Use systemd-run to execute in separate context
        wallpaperSetter.command = ["systemd-run", "--user", "--scope", "swww", "img", path, "--transition-type", "fade", "--transition-duration", "1"]
        wallpaperSetter.running = true
        
        // Close after delay
        closeTimer.restart()
    }
    
    // Process for setting wallpaper
    Process {
        id: wallpaperSetter
        running: false
        
        stdout: SplitParser {
            onRead: function(data) {
                console.log("stdout:", data)
            }
        }
        
        stderr: SplitParser {
            onRead: function(data) {
                console.log("stderr:", data)
            }
        }
        
        onStarted: {
            console.log("Started:", command.join(" "))
        }
        
        onExited: function(code, status) {
            console.log("Exited with code:", code)
            if (code === 0) {
                console.log("✓ Wallpaper set!")
            }
        }
    }
    
    // Timer for delayed close after setting wallpaper
    Timer {
        id: closeTimer
        interval: 1000
        repeat: false
        onTriggered: root.closeApp()
    }
    
    Variants {
        model: Quickshell.screens
        
        PanelWindow {
            id: window
            
            property var modelData
            screen: modelData
            
            visible: root.isVisible
            
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            
            color: "transparent"
            
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "wallpaper-selector"
            mask: Region { item: container }
            
            // Prevent compositor crashes
            Component.onDestruction: {
                WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
            }
            
            Rectangle {
                id: container
                
                width: Math.min(900, parent.width - 40)
                height: Math.min(420, parent.height - 20)
                
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                
                color: "#151515"
                radius: 12
                
                border.color: "#2a2a2a"
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        Text {
                            text: "󰸉"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 24
                            color: "#ffffff"
                        }
                        
                        Text {
                            text: "Wallpapers"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            font.bold: true
                            color: "#ffffff"
                            Layout.fillWidth: true
                        }
                        
                        // Refresh button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            color: refreshArea.containsMouse ? "#2a2a2a" : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰑓"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                                color: "#888888"
                            }
                            
                            MouseArea {
                                id: refreshArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    var currentFolder = folderModel.folder
                                    folderModel.folder = ""
                                    Qt.callLater(function() {
                                        folderModel.folder = currentFolder
                                    })
                                }
                            }
                        }
                        
                        // Close button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 6
                            color: closeArea.containsMouse ? "#3a2a2a" : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                                color: closeArea.containsMouse ? "#ff6666" : "#888888"
                            }
                            
                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.closeApp()
                            }
                        }
                    }
                    
                    // Separator
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#2a2a2a"
                    }
                    
                    // Wallpaper grid
                    GridView {
                        id: gridView
                        
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        cellWidth: 160
                        cellHeight: 110
                        
                        clip: true
                        
                        model: FolderListModel {
                            id: folderModel
                            folder: root.wallpapersPath
                            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP", "*.GIF"]
                            showDirs: false
                            sortField: FolderListModel.Name
                        }
                        
                        delegate: Item {
                            width: gridView.cellWidth
                            height: gridView.cellHeight
                            
                            required property string fileName
                            required property string filePath
                            
                            Rectangle {
                                id: wallpaperItem
                                
                                anchors.fill: parent
                                anchors.margins: 6
                                
                                radius: 8
                                color: "#1a1a1a"
                                
                                border.color: itemArea.containsMouse ? "#4a9eff" : "#2a2a2a"
                                border.width: itemArea.containsMouse ? 2 : 1
                                
                                clip: true
                                
                                property bool isGif: fileName.toLowerCase().endsWith(".gif")
                                
                                // Static image preview
                                Image {
                                    id: staticImage
                                    
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    
                                    source: filePath
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                    
                                    visible: !wallpaperItem.isGif
                                }
                                
                                // Animated GIF preview
                                AnimatedImage {
                                    id: animatedImage
                                    
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    
                                    source: wallpaperItem.isGif ? filePath : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    smooth: true
                                    
                                    visible: wallpaperItem.isGif
                                    playing: wallpaperItem.isGif && itemArea.containsMouse
                                }
                                
                                // Loading indicator
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 40
                                    height: 40
                                    radius: 20
                                    color: "#252525"
                                    visible: staticImage.status === Image.Loading || animatedImage.status === AnimatedImage.Loading
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰦖"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 20
                                        color: "#666666"
                                        
                                        RotationAnimation on rotation {
                                            from: 0
                                            to: 360
                                            duration: 1000
                                            loops: Animation.Infinite
                                            running: parent.visible
                                        }
                                    }
                                }
                                
                                // GIF badge
                                Rectangle {
                                    visible: wallpaperItem.isGif
                                    
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 8
                                    
                                    width: gifLabel.width + 8
                                    height: 18
                                    radius: 4
                                    
                                    color: "#4a9eff"
                                    
                                    Text {
                                        id: gifLabel
                                        anchors.centerIn: parent
                                        text: "GIF"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }
                                
                                // Hover overlay
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: itemArea.containsMouse ? "#204a9eff" : "transparent"
                                    
                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                                
                                MouseArea {
                                    id: itemArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: {
                                        // Remove file:// prefix for swww
                                        var wallpaperPath = filePath.toString().replace("file://", "")
                                        
                                        // Set wallpaper using root function
                                        root.setWallpaper(wallpaperPath)
                                    }
                                }
                                
                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                        }
                        
                        // Empty state
                        Text {
                            anchors.centerIn: parent
                            visible: folderModel.count === 0
                            
                            text: "󰉖  No wallpapers found"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: "#666666"
                        }
                        
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: "#4a4a4a"
                            }
                            
                            background: Rectangle {
                                implicitWidth: 6
                                color: "transparent"
                            }
                        }
                    }
                    
                    // Footer info
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        Text {
                            text: "󰉏"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#666666"
                        }
                        
                        Text {
                            text: folderModel.count + " wallpapers"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: "#666666"
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Text {
                            text: "󰌑 Click to apply"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: "#666666"
                        }
                    }
                }
            }
            
            // Click outside to close
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.closeApp()
            }
            
            // Escape to close
            Shortcut {
                sequence: "Escape"
                onActivated: root.closeApp()
            }
        }
    }
}
