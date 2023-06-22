import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import chatlistmodel
import download
import llm
import modellist
import network

Dialog {
    id: modelDownloaderDialog
    modal: true
    opacity: 0.9
    closePolicy: ModelList.installedModels.count === 0 ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)
    padding: 20
    bottomPadding: 30
    background: Rectangle {
        anchors.fill: parent
        color: theme.backgroundDarkest
        border.width: 1
        border.color: theme.dialogBorder
        radius: 10
    }

    onOpened: {
        Network.sendModelDownloaderDialog();
    }

    property string defaultModelPath: ModelList.defaultLocalModelsPath()
    property alias modelPath: settings.modelPath
    Settings {
        id: settings
        property string modelPath: modelDownloaderDialog.defaultModelPath
    }

    Component.onCompleted: {
        ModelList.localModelsPath = settings.modelPath
    }

    Component.onDestruction: {
        settings.sync()
    }

    PopupDialog {
        id: downloadingErrorPopup
        anchors.centerIn: parent
        shouldTimeOut: false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 30

        Label {
            id: listLabel
            text: qsTr("Available Models:")
            Layout.alignment: Qt.AlignLeft
            Layout.fillWidth: true
            color: theme.textColor
        }

        Label {
            visible: !ModelList.downloadableModels.count
            Layout.fillWidth: true
            Layout.fillHeight: true
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            text: qsTr("Network error: could not retrieve http://gpt4all.io/models/models.json")
            color: theme.mutedTextColor
        }

        ScrollView {
            id: scrollView
            ScrollBar.vertical.policy: ScrollBar.AlwaysOn
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: modelListView
                model: ModelList.downloadableModels
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: delegateItem
                    width: modelListView.width
                    height: childrenRect.height
                    color: index % 2 === 0 ? theme.backgroundLight : theme.backgroundLighter

                    GridLayout {
                        columns: 2
                        rowSpacing: 20
                        columnSpacing: 20
                        width: parent.width

                        Text {
                            text: name !== "" ? name : filename
                            font.bold: isDefault
                            font.pixelSize: theme.fontSizeLarger + 5
                            Layout.row: 0
                            Layout.column: 0
                            Layout.topMargin: 20
                            Layout.leftMargin: 20
                            color: theme.assistantColor
                            Accessible.role: Accessible.Paragraph
                            Accessible.name: qsTr("Model file")
                            Accessible.description: qsTr("Model file to be downloaded")
                        }

                        Label {
                            textFormat: Text.StyledText
                            text: qsTr("Status: ") + (installed ? qsTr("Installed")
                                : (downloadError !== "" ? qsTr("<a href=\"#error\">Error</a>") : qsTr("Available")))
                            Layout.row: 0
                            Layout.column: 1
                            Layout.topMargin: 20
                            Layout.rightMargin: 20
                            Layout.alignment: Qt.AlignRight
                            color: theme.textColor
                            Accessible.role: Accessible.Paragraph
                            Accessible.name: text
                            Accessible.description: qsTr("Whether the file is already installed on your system")
                            onLinkActivated: {
                                downloadingErrorPopup.text = downloadError;
                                downloadingErrorPopup.open();
                            }
                        }

                        Text {
                            id: descriptionText
                            text: description
                            Layout.row: 1
                            Layout.column: 0
                            Layout.leftMargin: 20
                            Layout.maximumWidth: modelListView.width - 40
                            Layout.columnSpan: 2
                            wrapMode: Text.WordWrap
                            textFormat: Text.StyledText
                            color: theme.textColor
                            linkColor: theme.textColor
                            Accessible.role: Accessible.Paragraph
                            Accessible.name: qsTr("Description")
                            Accessible.description: qsTr("The description of the file")
                            onLinkActivated: Qt.openUrlExternally(link)
                        }

                        Text {
                            visible: !isChatGPT
                            text: qsTr("Download size: ") + filesize
                            color: theme.textColor
                            Layout.row: 2
                            Layout.column: 0
                            Layout.leftMargin: 20
                            Accessible.role: Accessible.Paragraph
                            Accessible.name: qsTr("File size")
                            Accessible.description: qsTr("The size of the file")
                        }

                        RowLayout {
                            visible: isDownloading && !calcHash
                            Layout.row: 3
                            Layout.column: 0
                            Layout.leftMargin: 20
                            Layout.bottomMargin: 20
                            Layout.fillWidth: true
                            spacing: 20

                            ProgressBar {
                                id: itemProgressBar
                                width: 100
                                visible: isDownloading
                                value: bytesReceived / bytesTotal
                                background: Rectangle {
                                    implicitWidth: 350
                                    implicitHeight: 45
                                    color: theme.backgroundDarkest
                                    radius: 3
                                }
                                contentItem: Item {
                                    implicitWidth: 350
                                    implicitHeight: 40

                                    Rectangle {
                                        width: itemProgressBar.visualPosition * parent.width
                                        height: parent.height
                                        radius: 2
                                        color: theme.assistantColor
                                    }
                                }
                                Accessible.role: Accessible.ProgressBar
                                Accessible.name: qsTr("Download progressBar")
                                Accessible.description: qsTr("Shows the progress made in the download")
                            }

                            Label {
                                id: speedLabel
                                color: theme.textColor
                                text: speed
                                visible: isDownloading
                                Accessible.role: Accessible.Paragraph
                                Accessible.name: qsTr("Download speed")
                                Accessible.description: qsTr("Download speed in bytes/kilobytes/megabytes per second")
                            }
                        }

                        RowLayout {
                            visible: calcHash
                            Layout.row: 3
                            Layout.column: 0
                            Layout.leftMargin: 20
                            Layout.bottomMargin: 20

                            Label {
                                id: calcHashLabel
                                color: theme.textColor
                                text: qsTr("Calculating MD5...")
                                Accessible.role: Accessible.Paragraph
                                Accessible.name: text
                                Accessible.description: qsTr("Whether the file hash is being calculated")
                            }

                            MyBusyIndicator {
                                id: busyCalcHash
                                running: calcHash
                                Accessible.role: Accessible.Animation
                                Accessible.name: qsTr("Busy indicator")
                                Accessible.description: qsTr("Displayed when the file hash is being calculated")
                            }
                        }

                        MyTextField {
                            id: openaiKey
                            visible: !installed && isChatGPT
                            Layout.row: 3
                            Layout.column: 0
                            Layout.leftMargin: 20
                            Layout.bottomMargin: 20
                            Layout.fillWidth: true
                            color: theme.textColor
                            background: Rectangle {
                                color: theme.backgroundLighter
                                radius: 10
                            }
                            placeholderText: qsTr("enter $OPENAI_API_KEY")
                            placeholderTextColor: theme.backgroundLightest
                            Accessible.role: Accessible.EditableText
                            Accessible.name: placeholderText
                            Accessible.description: qsTr("Whether the file hash is being calculated")
                        }

                        MyButton {
                            id: installButton
                            visible: !installed && isChatGPT
                            Layout.row: 3
                            Layout.column: 1
                            Layout.rightMargin: 20
                            Layout.bottomMargin: 20
                            Layout.alignment: Qt.AlignRight
                            Layout.minimumWidth: 150
                            contentItem: Text {
                                color: openaiKey.text === "" ? theme.backgroundLightest : theme.textColor
                                text: "Install"
                                horizontalAlignment: Qt.AlignHCenter
                            }
                            enabled: openaiKey.text !== ""
                            background: Rectangle {
                                border.color: installButton.down ? theme.backgroundLightest : theme.buttonBorder
                                border.width: 2
                                radius: 10
                                color: installButton.hovered ? theme.backgroundDark : theme.backgroundDarkest
                            }
                            onClicked: {
                                Download.installModel(filename, openaiKey.text);
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: qsTr("Install button")
                            Accessible.description: qsTr("Install button to install chatgpt model")
                        }

                        MyButton {
                            id: downloadButton
                            text: isDownloading ? qsTr("Cancel") : isIncomplete ? qsTr("Resume") : qsTr("Download")
                            Layout.row: 3
                            Layout.column: 1
                            Layout.rightMargin: 20
                            Layout.bottomMargin: 20
                            Layout.alignment: Qt.AlignRight
                            Layout.minimumWidth: 150
                            visible: !isChatGPT && !installed && !calcHash && downloadError === ""
                            Accessible.description: qsTr("Cancel/Resume/Download button to stop/restart/start the download")
                            background: Rectangle {
                                border.color: downloadButton.down ? theme.backgroundLightest : theme.buttonBorder
                                border.width: 2
                                radius: 10
                                color: downloadButton.hovered ? theme.backgroundDark : theme.backgroundDarkest
                            }
                            onClicked: {
                                if (!isDownloading) {
                                    Download.downloadModel(filename);
                                } else {
                                    Download.cancelDownload(filename);
                                }
                            }
                        }

                        MyButton {
                            id: removeButton
                            text: qsTr("Remove")
                            Layout.row: 3
                            Layout.column: 1
                            Layout.rightMargin: 20
                            Layout.bottomMargin: 20
                            Layout.alignment: Qt.AlignRight
                            Layout.minimumWidth: 150
                            visible: installed || downloadError !== ""
                            Accessible.description: qsTr("Remove button to remove model from filesystem")
                            background: Rectangle {
                                border.color: removeButton.down ? theme.backgroundLightest : theme.buttonBorder
                                border.width: 2
                                radius: 10
                                color: removeButton.hovered ? theme.backgroundDark : theme.backgroundDarkest
                            }
                            onClicked: {
                                Download.removeModel(filename);
                            }
                        }
                    }
                }

                footer: Component {
                    Rectangle {
                        width: modelListView.width
                        height: expandButton.height + 80
                        color: ModelList.downloadableModels.count % 2 === 0 ? theme.backgroundLight : theme.backgroundLighter
                        MyButton {
                            id: expandButton
                            anchors.centerIn: parent
                            padding: 40
                            text: ModelList.downloadableModels.expanded ? qsTr("Show fewer models") : qsTr("Show more models")
                            background: Rectangle {
                                border.color: expandButton.down ? theme.backgroundLightest : theme.buttonBorder
                                border.width: 2
                                radius: 10
                                color: expandButton.hovered ? theme.backgroundDark : theme.backgroundDarkest
                            }
                            onClicked: {
                                ModelList.downloadableModels.expanded = !ModelList.downloadableModels.expanded;
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: true
            spacing: 20
            FolderDialog {
                id: modelPathDialog
                title: "Please choose a directory"
                currentFolder: "file://" + ModelList.localModelsPath
                onAccepted: {
                    modelPathDisplayField.text = selectedFolder
                    ModelList.localModelsPath = modelPathDisplayField.text
                    settings.modelPath = ModelList.localModelsPath
                    settings.sync()
                }
            }
            Label {
                id: modelPathLabel
                text: qsTr("Download path:")
                color: theme.textColor
                Layout.row: 1
                Layout.column: 0
            }
            MyDirectoryField {
                id: modelPathDisplayField
                text: ModelList.localModelsPath
                Layout.fillWidth: true
                ToolTip.text: qsTr("Path where model files will be downloaded to")
                ToolTip.visible: hovered
                Accessible.role: Accessible.ToolTip
                Accessible.name: modelPathDisplayField.text
                Accessible.description: ToolTip.text
                onEditingFinished: {
                    if (isValid) {
                        ModelList.localModelsPath = modelPathDisplayField.text
                        settings.modelPath = ModelList.localModelsPath
                        settings.sync()
                    } else {
                        text = ModelList.localModelsPath
                    }
                }
            }
            MyButton {
                text: qsTr("Browse")
                Accessible.description: qsTr("Opens a folder picker dialog to choose where to save model files")
                onClicked: modelPathDialog.open()
            }
        }
    }
}
