/*
 * Copyright 2016 Canonical Ltd.
 *
 * This file is part of messaging-app.
 *
 * dialer-app is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * dialer-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3 as ListItems
import Ubuntu.History 0.1
import Ubuntu.Telephony 0.1
import ".."

Page {
    id: newGroupPage
    property bool multimedia: false
    property bool creationInProgress: false
    property var participants: []
    property var account: null

    function addRecipient(identifier, contact) {
        var alias = contact.displayLabel.label
        if (alias == "") {
            alias = identifier
        }
        addRecipientFromSearch(identifier, alias, contact.avatar.imageUrl)
    }

    function addRecipientFromSearch(identifier, alias, avatar) {
        for (var i=0; i < participantsModel.count; i++) {
            if (identifier == participantsModel.get(i).identifier) {
                application.showNotificationMessage(i18n.tr("This recipient was already selected"), "dialog-error-symbolic")
                return
            }
        }
        searchItem.text = ""
        participantsModel.append({"identifier": identifier, "alias": alias, "avatar": avatar })
    }

    header: PageHeader {
        title: {
            if (creationInProgress) {
                return i18n.tr("Creating Group...")
            }
            if (multimedia) {
                var protocolDisplayName = mainView.multimediaAccount.protocolInfo.serviceDisplayName;
                if (protocolDisplayName === "") {
                   protocolDisplayName = mainView.multimediaAccount.protocolInfo.serviceName;
                }
                return i18n.tr("New %1 Group").arg(protocolDisplayName);
            } else {
                return i18n.tr("New MMS Group")
            }
        }
        leadingActionBar {
            actions: [
                Action {
                    objectName: "cancelAction"
                    iconName: "close"
                    onTriggered: {
                        Qt.inputMethod.commit()
                        mainStack.removePages(newGroupPage)
                    }
                }
            ]
        }
        trailingActionBar {
            actions: [
                Action {
                    objectName: "createAction"
                    enabled: {
                        if (newGroupPage.creationInProgress) {
                            return false
                        }
                        if (participantsModel.count == 0) {
                            return false
                        }
                        if (multimedia) {
                            return ((groupTitleField.text != "" || groupTitleField.inputMethodComposing) && participantsModel.count > 1)
                        }
                        return participantsModel.count > 1
                    }
                    iconName: "ok"
                    onTriggered: {
                        Qt.inputMethod.commit()
                        newGroupPage.creationInProgress = true
                        chatEntry.startChat()
                    }
                }
            ]
        }

        extension: Sections {
            id: newGroupHeaderSections
            objectName: "newGroupHeaderSections"
            height: !visible ? 0 : undefined
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: units.gu(2)
                bottom: parent.bottom
            }
            visible: {
                if (newGroupPage.account.type == AccountEntry.GenericType) {
                    return true
                }
                console.log("mainView.multiplePhoneAccounts", mainView.multiplePhoneAccounts)
                // only show if we have more than one sim card
                return mainView.multiplePhoneAccounts
            }
            enabled: visible
            model: visible ? [account.displayName] : undefined
        }
    }

    ListModel {
        id: participantsModel
        dynamicRoles: true
        property var participantIds: {
            var ids = []
            for (var i=0; i < participantsModel.count; i++) {
                ids.push(participantsModel.get(i).identifier)
            }
            return ids
        }
        Component.onCompleted: {
            for (var i in newGroupPage.participants) {
                participantsModel.append(newGroupPage.participants[i])
            }
        }
    }

    ChatEntry {
        id: chatEntry
        accountId: {
            if (newGroupPage.multimedia) {
                return mainView.multimediaAccount.accountId
            }
            return newGroupPage.account.accountId
        }
        title: groupTitleField.text
        autoRequest: false
        chatType: newGroupPage.multimedia ? HistoryThreadModel.ChatTypeRoom : HistoryThreadModel.ChatTypeNone
        onChatReady: {
            // give history service time to create the thread
            creationTimer.start()
        }
        participantIds: participantsModel.participantIds
        onStartChatFailed: {
            application.showNotificationMessage(i18n.tr("Failed to create group"), "dialog-error-symbolic")
            mainStack.removePage(newGroupPage)
        }
    }

    Timer {
        id: creationTimer
        interval: 1000
        onTriggered: {
            var properties ={}
            properties["accountId"] = chatEntry.accountId
            properties["threadId"] = chatEntry.chatId
            properties["chatType"] = chatEntry.chatType
            properties["participantIds"] = chatEntry.participantIds

            mainView.emptyStack()
            mainView.startChat(properties)
        }
    }

    Flickable {
        id: flick
        clip: true
        property var emptySpaceHeight: height - contentColumn.topItemsHeight+flick.contentY
        flickableDirection: Flickable.VerticalFlick
        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            bottom: keyboard.top
        }
        contentWidth: parent.width
        contentHeight: contentColumn.height

        FocusScope {
            id: contentColumn
            property var topItemsHeight: groupNameItem.height+searchItem.height
            height: childrenRect.height
            anchors.left: parent.left
            anchors.right: parent.right
            enabled: !creationInProgress

/*            ActivityIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: creationInProgress
                visible: running
            }*/
            Item {
                id: groupNameItem
                clip: true 
                height: multimedia ? units.gu(6) : 0
                anchors {
                    top: contentColumn.top
                    left: parent.left
                    right: parent.right
                    leftMargin: units.gu(2)
                    rightMargin: units.gu(2)
                }
                Label {
                    id: groupNameLabel
                    height: units.gu(2)
                    verticalAlignment: Text.AlignVCenter
                    anchors.verticalCenter: groupTitleField.verticalCenter
                    anchors.left: parent.left
                    text: i18n.tr("Group name:")
                }
                TextField {
                    id: groupTitleField
                    anchors {
                        left: groupNameLabel.right
                        leftMargin: units.gu(2)
                        right: parent.right
                        topMargin: units.gu(1)
                        top: parent.top
                    }
                    height: units.gu(4)
                    placeholderText: i18n.tr("Type a name...")
                    inputMethodHints: Qt.ImhNoPredictiveText
                    Timer {
                        interval: 1
                        onTriggered: {
                            if (!multimedia) {
                                return
                            }
                            groupTitleField.forceActiveFocus()
                        }
                        Component.onCompleted: start()
                    }
                }
            }
            Rectangle {
               id: separator
               anchors {
                   left: parent.left
                   right: parent.right
                   bottom: groupNameItem.bottom
               }
               height: 1
               color: UbuntuColors.lightGrey
               z: 2
            }
            ContactSearchWidget {
                id: searchItem
                parentPage: newGroupPage
                searchResultsHeight: flick.emptySpaceHeight
                onContactPicked: addRecipientFromSearch(identifier, alias, avatar)
                anchors {
                    left: parent.left
                    right: parent.right
                    top: groupNameItem.bottom
                }
            }
            Rectangle {
               id: separator2
               anchors {
                   left: parent.left
                   right: parent.right
                   bottom: searchItem.bottom
               }
               height: 1
               color: UbuntuColors.lightGrey
               z: 2
            }
            ListItemActions {
                id: participantLeadingActions
                actions: [
                    Action {
                        iconName: "delete"
                        text: i18n.tr("Delete")
                        onTriggered: {
                            participantsModel.remove(value)
                        }
                    }
                ]
            }
            Column {
                id: participantsColumn
                anchors.top: searchItem.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                Repeater {
                    id: participantsRepeater
                    model: participantsModel

                    delegate: ParticipantDelegate {
                        id: participantDelegate
                        participant: participantsModel.get(index)
                        leadingActions: participantLeadingActions
                    }
                }
            }
        }
    }

    KeyboardRectangle {
       id: keyboard
    }
}