/*
 * Copyright 2012, 2013, 2014 Canonical Ltd.
 *
 * This file is part of messaging-app.
 *
 * messaging-app is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * messaging-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import QtQuick.Window 2.0
import QtContacts 5.0
import Ubuntu.Components 0.1
import Ubuntu.Components.ListItems 0.1 as ListItem
import Ubuntu.Components.Popups 0.1
import Ubuntu.Content 0.1
import Ubuntu.History 0.1
import Ubuntu.Telephony 0.1
import Ubuntu.Contacts 0.1
import QtContacts 5.0

Page {
    id: messages
    objectName: "messagesPage"
    property string threadId: ""
    property bool newMessage: threadId === ""
    // FIXME: we should get the account ID properly when dealing with multiple accounts
    property string accountId: telepathyHelper.accountIds[0]
    property variant participants: []
    property bool groupChat: participants.length > 1
    property bool keyboardFocus: true
    property alias selectionMode: messageList.isInSelectionMode
    // FIXME: MainView should provide if the view is in portait or landscape
    property int orientationAngle: Screen.angleBetween(Screen.primaryOrientation, Screen.orientation)
    property bool landscape: orientationAngle == 90 || orientationAngle == 270
    property bool pendingMessage: false
    property var activeTransfer: null
    property int activeAttachmentIndex: -1
    property var sharedAttachmentsTransfer: []
    property string text: ""

    function addAttachmentsToModel(transfer) {
        for (var i = 0; i < transfer.items.length; i++) {
            var attachment = {}
            if (!startsWith(String(transfer.items[i].url),"file://")) {
                messages.text = String(transfer.items[i].url)
                continue
            }
            var filePath = String(transfer.items[i].url).replace('file://', '')
            // get only the basename
            attachment["name"] = filePath.split('/').reverse()[0]
            attachment["contentType"] = application.fileMimeType(filePath)
            attachment["filePath"] = filePath
            attachments.append(attachment)
        }
    }

    ListModel {
        id: attachments
    }

    Connections {
        target: activeTransfer !== null ? activeTransfer : null
        onStateChanged: {
            var done = ((activeTransfer.state === ContentTransfer.Charged) ||
                        (activeTransfer.state === ContentTransfer.Aborted));

            if (activeTransfer.state === ContentTransfer.Charged) {
                if (activeTransfer.items.length > 0) {
                    addAttachmentsToModel(activeTransfer)
                    textEntry.forceActiveFocus()
                }
            }
        }
    }

    flickable: null
    // we need to use isReady here to know if this is a bottom edge page or not.
    __customHeaderContents: newMessage && isReady ? newMessageHeader : null
    property bool isReady: false
    signal ready
    onReady: {
        isReady = true
        if (participants.length === 0 && keyboardFocus)
            multiRecipient.forceFocus()
    }

    title: {
        if (selectionMode) {
            return i18n.tr("Edit")
        }

        if (landscape) {
            return ""
        }
        if (participants.length > 0) {
            var firstRecipient = ""
            if (contactWatcher.isUnknown) {
                firstRecipient = contactWatcher.phoneNumber
            } else {
                firstRecipient = contactWatcher.alias
            }
            if (participants.length == 1) {
                return firstRecipient
            } else {
                return i18n.tr("Group")
            }
        }
        return i18n.tr("New Message")
    }
    tools: {
        if (selectionMode) {
            return messagesToolbarSelectionMode
        }

        if (participants.length == 0) {
            return messagesToolbarNewMessage
        } else if (participants.length == 1) {
            if (contactWatcher.isUnknown) {
                return messagesToolbarUnknownContact
            } else {
                return messagesToolbarKnownContact
            }
        } else if (groupChat){
            return messagesToolbarGroupChat
        }
    }

    Component.onCompleted: {
        threadId = getCurrentThreadId()
        addAttachmentsToModel(sharedAttachmentsTransfer)
    }

    function getCurrentThreadId() {
        if (participants.length == 0)
            return ""
        return eventModel.threadIdForParticipants(accountId,
                                                              HistoryThreadModel.EventTypeText,
                                                              participants,
                                                              HistoryThreadModel.MatchPhoneNumber)
    }

    function markMessageAsRead(accountId, threadId, eventId, type) {
        chatManager.acknowledgeMessage(participants[0], eventId, accountId)
        return eventModel.markEventAsRead(accountId, threadId, eventId, type);
    }

    ContentPeer {
        id: defaultSource
        contentType: ContentType.Pictures
        handler: ContentHandler.Source
        selectionType: ContentTransfer.Single
    }

    Component {
        id: attachmentPopover

        Popover {
            id: popover
            Column {
                id: containerLayout
                anchors {
                    left: parent.left
                    top: parent.top
                    right: parent.right
                }
                ListItem.Standard {
                    text: i18n.tr("Remove")
                    onClicked: {
                        attachments.remove(activeAttachmentIndex)
                        PopupUtils.close(popover)
                    }
                }
            }
            Component.onDestruction: activeAttachmentIndex = -1
        }
    }

    Component {
        id: participantsPopover

        Popover {
            id: popover
            Column {
                id: containerLayout
                anchors {
                    left: parent.left
                    top: parent.top
                    right: parent.right
                }
                Repeater {
                    model: participants
                    Item {
                        height: childrenRect.height
                        width: popover.width
                        ListItem.Standard {
                            id: listItem
                            text: contactWatcher.isUnknown ? contactWatcher.phoneNumber : contactWatcher.alias
                        }
                        ContactWatcher {
                            id: contactWatcher
                            phoneNumber: modelData
                        }
                    }
                }
            }
        }
    }

    Component {
         id: newContactDialog
         Dialog {
             id: dialogue
             title: i18n.tr("Save contact")
             text: i18n.tr("How do you want to save the contact?")
             Button {
                 objectName: "addToExistingContact"
                 text: i18n.tr("Add to existing contact")
                 color: UbuntuColors.orange
                 onClicked: {
                     PopupUtils.close(dialogue)
                     Qt.inputMethod.hide()
                     mainStack.push(Qt.resolvedUrl("AddPhoneNumberToContactPage.qml"), {"phoneNumber": contactWatcher.phoneNumber})
                 }
             }
             Button {
                 objectName: "createNewContact"
                 text: i18n.tr("Create new contact")
                 color: UbuntuColors.orange
                 onClicked: {
                     Qt.openUrlExternally("addressbook:///create?phone=" + encodeURIComponent(contactWatcher.phoneNumber));
                     PopupUtils.close(dialogue)
                 }
             }
             Button {
                 objectName: "cancelSave"
                 text: i18n.tr("Cancel")
                 color: UbuntuColors.warmGrey
                 onClicked: {
                     PopupUtils.close(dialogue)
                 }
             }
         }
    }

    Item {
        id: newMessageHeader
        anchors {
            left: parent.left
            rightMargin: units.gu(1)
            right: parent.right
            bottom: parent.bottom
            top: parent.top
        }
        visible: participants.length == 0 && isReady && messages.active
        MultiRecipientInput {
            id: multiRecipient
            objectName: "multiRecipient"
            enabled: visible
            width: childrenRect.width
            anchors {
                left: parent.left
                right: addIcon.left
                rightMargin: units.gu(1)
                verticalCenter: parent.verticalCenter
            }
        }
        Icon {
            id: addIcon
            visible: multiRecipient.visible
            height: units.gu(3)
            width: units.gu(3)
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }

            name: "new-contact"
            color: "gray"
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    Qt.inputMethod.hide()
                    mainStack.push(Qt.resolvedUrl("NewRecipientPage.qml"), {"multiRecipient": multiRecipient, "parentPage": messages})
                }
            }
        }
    }

    ContactListView {
        id: contactSearch

        property bool searchEnabled: multiRecipient.searchString !== "" && multiRecipient.focus

        visible: searchEnabled
        detailToPick: ContactDetail.PhoneNumber
        clip: true
        z: 1
        autoUpdate: false
        filterTerm: multiRecipient.searchString
        showSections: false

        states: [
            State {
                name: "empty"
                when: contactSearch.count === 0
                PropertyChanges {
                    target: contactSearch
                    height: 0
                }
            }
        ]

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: bottomPanel.top
        }

        Behavior on height {
            UbuntuNumberAnimation { }
        }

        InvalidFilter {
            id: invalidFilter
        }

        // clear list if it is invisible to save some memory
        onVisibleChanged: {
            if (visible && (filter != null)) {
                changeFilter(null)
                update()
            } else if (!visible && filter != invalidFilter) {
                changeFilter(invalidFilter)
                update()
            }
        }

        listDelegate: Item {
            anchors {
                left: parent.left
                right: parent.right
                margins: units.gu(2)
            }
            height: phoneRepeater.count * units.gu(7)
            Column {
                anchors.fill: parent
                spacing: units.gu(1)

                Repeater {
                    id: phoneRepeater

                    model: contact.phoneNumbers.length

                    delegate: MouseArea {
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        height: units.gu(6)

                        onClicked: {
                            multiRecipient.addRecipient(contact.phoneNumbers[index].number)
                            multiRecipient.clearSearch()
                            multiRecipient.forceActiveFocus()
                        }

                        Column {
                            anchors.fill: parent

                            Label {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                }
                                height: units.gu(3)
                                text: {
                                    // this is necessary to keep the string in the original format
                                    var originalText = contact.displayLabel.label
                                    var lowerSearchText =  multiRecipient.searchString.toLowerCase()
                                    var lowerText = originalText.toLowerCase()
                                    var searchIndex = lowerText.indexOf(lowerSearchText)
                                    if (searchIndex !== -1) {
                                        var piece = originalText.substr(searchIndex, lowerSearchText.length)
                                        return originalText.replace(piece, "<b>" + piece + "</b>")
                                    } else {
                                        return originalText
                                    }
                                }
                                fontSize: "medium"
                                color: UbuntuColors.lightAubergine
                            }
                            Label {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                }
                                height: units.gu(2)
                                text: contact.phoneNumbers[index].number
                            }
                            Item {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                }
                                height: units.gu(1)
                            }

                            ListItem.ThinDivider {}
                        }
                    }
                }
            }
        }
    }

    ContactWatcher {
        id: contactWatcher
        phoneNumber: participants.length > 0 ? participants[0] : ""
    }

    onParticipantsChanged: {
        threadId = getCurrentThreadId()
    }

    ToolbarItems {
        id: messagesToolbarSelectionMode
        visible: false
        back: ToolbarButton {
            id: selectionModeCancelButton
            objectName: "selectionModeCancelButton"
            action: Action {
                objectName: "selectionModeCancelAction"
                iconSource: "image://theme/close"
                onTriggered: messageList.cancelSelection()
            }
        }
        ToolbarButton {
            id: selectionModeSelectAllButton
            objectName: "selectionModeSelectAllButton"
            action: Action {
                objectName: "selectionModeSelectAllAction"
                iconSource: "image://theme/filter"
                onTriggered: messageList.selectAll()
            }
        }
        ToolbarButton {
            id: selectionModeDeleteButton
            objectName: "selectionModeDeleteButton"
            action: Action {
                objectName: "selectionModeDeleteAction"
                enabled: messageList.selectedItems.count > 0
                iconSource: "image://theme/delete"
                onTriggered: messageList.endSelection()
            }
        }
    }

    ToolbarItems {
        id: messagesToolbarGroupChat
        visible: false
        ToolbarButton {
            id: groupChatButton
            objectName: "groupChatButton"
            action: Action {
                objectName: "groupChatAction"
                iconSource: "image://theme/navigation-menu"
                onTriggered: {
                    PopupUtils.open(participantsPopover, messages.header)
                }
            }
        }
    }

    ToolbarItems {
        id: messagesToolbarNewMessage
        visible: false
        back: ToolbarButton {
            action: Action {
                onTriggered: {
                    mainPage.temporaryProperties = null
                    mainStack.pop()
                }
                iconSource: "image://theme/back"
            }
        }
    }

    ToolbarItems {
        id: messagesToolbarUnknownContact
        visible: false
        ToolbarButton {
            objectName: "contactCallButton"
            action: Action {
                objectName: "contactCallAction"
                visible: participants.length == 1
                iconSource: "image://theme/call-start"
                text: i18n.tr("Call")
                onTriggered: {
                    Qt.inputMethod.hide()
                    Qt.openUrlExternally("tel:///" + encodeURIComponent(contactWatcher.phoneNumber))
                }
            }
        }
        ToolbarButton {
            objectName: "addContactButton"
            action: Action {
                objectName: "addContactAction"
                visible: contactWatcher.isUnknown && participants.length == 1
                iconSource: "image://theme/new-contact"
                text: i18n.tr("Add")
                onTriggered: {
                    Qt.inputMethod.hide()
                    PopupUtils.open(newContactDialog)
                }
            }
        }
    }

    ToolbarItems {
        id: messagesToolbarKnownContact
        visible: false
        ToolbarButton {
            objectName: "contactCallButton"
            action: Action {
                objectName: "contactCallKnownAction"
                visible: participants.length == 1
                iconSource: "image://theme/call-start"
                text: i18n.tr("Call")
                onTriggered: {
                    Qt.inputMethod.hide()
                    Qt.openUrlExternally("tel:///" + encodeURIComponent(contactWatcher.phoneNumber))
                }
            }
        }
        ToolbarButton {
            objectName: "contactProfileButton"
            action: Action {
                objectName: "contactProfileAction"
                visible: !contactWatcher.isUnknown && participants.length == 1
                iconSource: "image://theme/contact"
                text: i18n.tr("Contact")
                onTriggered: {
                    Qt.openUrlExternally("addressbook:///contact?id=" + encodeURIComponent(contactWatcher.contactId))
                }
            }
        }
    }

    HistoryEventModel {
        id: eventModel
        type: HistoryThreadModel.EventTypeText
        filter: HistoryIntersectionFilter {
            HistoryFilter {
                filterProperty: "threadId"
                filterValue: threadId
            }
            HistoryFilter {
                filterProperty: "accountId"
                filterValue: accountId
            }
        }
        sort: HistorySort {
           sortField: "timestamp"
           sortOrder: HistorySort.DescendingOrder
        }
    }

    SortProxyModel {
        id: sortProxy
        sourceModel: eventModel
        sortRole: HistoryEventModel.TimestampRole
        ascending: false
    }

    MultipleSelectionListView {
        id: messageList
        objectName: "messageList"
        clip: true
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: bottomPanel.top
        }
        // TODO: workaround to add some extra space at the bottom and top
        header: Item {
            height: units.gu(2)
        }
        footer: Item {
            height: units.gu(2)
        }
        listModel: !newMessage ? sortProxy : null
        verticalLayoutDirection: ListView.BottomToTop
        spacing: units.gu(2)
        highlightFollowsCurrentItem: false
        listDelegate: MessageDelegate {
            id: messageDelegate
            objectName: "message%1".arg(index)
            incoming: senderId != "self"
            selected: messageList.isSelected(messageDelegate)
            unread: newEvent
            removable: !messages.selectionMode
            selectionMode: messages.selectionMode
            confirmRemoval: true
            onClicked: {
                if (messageList.isInSelectionMode) {
                    if (!messageList.selectItem(messageDelegate)) {
                        messageList.deselectItem(messageDelegate)
                    }
                }
            }
            onTriggerSelectionMode: {
                messageList.startSelection()
                clicked()
            }

            Component.onCompleted: {
                if (newEvent) {
                    messages.markMessageAsRead(accountId, threadId, eventId, type);
                }
            }
            onResend: {
                // resend this message and remove the old one
                if (textMessageAttachments.length > 0) {
                    var newAttachments = []
                    for (var i = 0; i < textMessageAttachments.length; i++) {
                        var attachment = []
                        var item = textMessageAttachments[i]
                        // we dont include smil files. they will be auto generated
                        if (item.contentType.toLowerCase() == "application/smil") {
                            continue
                        }
                        attachment.push(item.attachmentId)
                        attachment.push(item.contentType)
                        attachment.push(item.filePath)
                        newAttachments.push(attachment)
                    }
                    eventModel.removeEvent(accountId, threadId, eventId, type)
                    chatManager.sendMMS(participants, textMessage, newAttachments, messages.accountId)
                    return
                }
                eventModel.removeEvent(accountId, threadId, eventId, type)
                chatManager.sendMessage(messages.participants, textMessage, accountId)
            }
        }
        onSelectionDone: {
            for (var i=0; i < items.count; i++) {
                var event = items.get(i).model
                eventModel.removeEvent(event.accountId, event.threadId, event.eventId, event.type)
            }
        }
        onCountChanged: {
            if (messages.pendingMessage) {
                messageList.contentY = 0
                messages.pendingMessage = false
            }
        }
    }

    Item {
        id: bottomPanel
        anchors.bottom: keyboard.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: selectionMode ? 0 : textEntry.height + units.gu(2)
        visible: !selectionMode
        clip: true

        Behavior on height {
            UbuntuNumberAnimation { }
        }

        ListItem.ThinDivider {
            anchors.top: parent.top
        }

        Icon {
            id: attachButton
            anchors.left: parent.left
            anchors.leftMargin: units.gu(2)
            anchors.verticalCenter: sendButton.verticalCenter
            height: units.gu(3)
            width: units.gu(3)
            color: "gray"
            name: "camera"
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    activeTransfer = defaultSource.request();
                }
            }
        }

        StyledItem {
            id: textEntry
            property alias text: messageTextArea.text
            property alias inputMethodComposing: messageTextArea.inputMethodComposing
            property int fullSize: attachmentThumbnails.height + messageTextArea.height
            style: Theme.createStyleComponent("TextFieldStyle.qml", textEntry)
            anchors.bottomMargin: units.gu(1)
            anchors.bottom: parent.bottom
            anchors.left: attachButton.right
            anchors.leftMargin: units.gu(1)
            anchors.right: sendButton.left
            anchors.rightMargin: units.gu(1)
            height: attachments.count !== 0 ? fullSize + units.gu(1) : fullSize
            onActiveFocusChanged: {
                if(activeFocus) {
                    messageTextArea.forceActiveFocus()
                } else {
                    focus = false
                }
            }
            focus: false
            MouseArea {
                anchors.fill: parent
                onClicked: messageTextArea.forceActiveFocus()
            }
            Flow {
                id: attachmentThumbnails
                spacing: units.gu(1)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: units.gu(1)
                anchors.rightMargin: units.gu(1)
                anchors.topMargin: units.gu(1)
                height: childrenRect.height
                Component {
                    id: thumbnailImage
                    UbuntuShape {
                        property int index
                        property string filePath
                        width: childrenRect.width
                        height: childrenRect.height
                        image: Image {
                            id: avatarImage
                            width: units.gu(8)
                            height: units.gu(8)
                            fillMode: Image.PreserveAspectCrop
                            source: filePath
                            asynchronous: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                mouse.accept = true
                                activeAttachmentIndex = index
                                PopupUtils.open(attachmentPopover, parent)
                            }
                        }
                    }
                }

                Component {
                    id: thumbnailContact
                    UbuntuShape {
                        property int index
                        property string filePath
                        width: childrenRect.width
                        height: childrenRect.height
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(6)
                            height: units.gu(6)
                            name: "contact"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                mouse.accept = true
                                activeAttachmentIndex = index
                                PopupUtils.open(attachmentPopover, parent)
                            }
                        }
                    }
                }

                Component {
                    id: thumbnailUnknown
                    UbuntuShape {
                        property int index
                        property string filePath
                        width: childrenRect.width
                        height: childrenRect.height
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(6)
                            height: units.gu(6)
                            name: "attachment"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                mouse.accept = true
                                activeAttachmentIndex = index
                                PopupUtils.open(attachmentPopover, parent)
                            }
                        }
                    }
                }

                Repeater {
                    model: attachments
                    delegate: Loader {
                        height: units.gu(8)
                        width: units.gu(8)
                        sourceComponent: {
                            var contentType = getContentType(filePath)
                            console.log(contentType)
                            switch(contentType) {
                            case ContentType.Contacts:
                                return thumbnailContact
                            case ContentType.Pictures:
                                return thumbnailImage
                            case ContentType.Unknown:
                                return thumbnailUnknown
                            default:
                                console.log("unknown content Type")
                            }
                        }
                        onStatusChanged: {
                            if (status == Loader.Ready) {
                                item.index = index
                                item.filePath = filePath
                            }
                        }
                    }
                }
            }

            TextArea {
                id: messageTextArea
                anchors.top: attachments.count == 0 ? textEntry.top : attachmentThumbnails.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: units.gu(4)
                style: MultiRecipientFieldStyle {}
                autoSize: true
                maximumLineCount: 0
                placeholderText: i18n.tr("Write a message...")
                focus: textEntry.focus
                font.family: "Ubuntu"
                text: messages.text
            }

            /*InverseMouseArea {
                anchors.fill: parent
                visible: textEntry.activeFocus
                onClicked: {
                    textEntry.focus = false;
                }
            }*/
            Component.onCompleted: {
                // if page is active, it means this is not a bottom edge page
                if (messages.active && messages.keyboardFocus && participants.length != 0) {
                    messageTextArea.forceActiveFocus()
                }
            }
        }

        Button {
            id: sendButton
            anchors.bottomMargin: units.gu(1)
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: units.gu(2)
            text: "Send"
            color: "green"
            width: units.gu(7)
            enabled: {
                if (!telepathyHelper.connected)
                    return false
                if (participants.length > 0 || multiRecipient.recipientCount > 0) {
                    if (textEntry.text != "" || textEntry.inputMethodComposing || attachments.count > 0) {
                        return true
                    }
                }
                return false
            }
            onClicked: {
                // make sure we flush everything we have prepared in the OSK preedit
                Qt.inputMethod.commit();
                if (textEntry.text == "" && attachments.count == 0) {
                    return
                }
                if (participants.length == 0 && multiRecipient.recipientCount > 0) {
                    participants = multiRecipient.recipients
                }
                if (messages.accountId == "") {
                    // FIXME: handle dual sim
                    messages.accountId = telepathyHelper.accountIds[0]
                }
                if (messages.newMessage) {
                    // create the new thread and get the threadId
                    messages.threadId = eventModel.threadIdForParticipants(messages.accountId,
                                                                            HistoryThreadModel.EventTypeText,
                                                                            participants,
                                                                            HistoryThreadModel.MatchPhoneNumber,
                                                                            true)
                }
                messages.pendingMessage = true
                if (attachments.count > 0) {
                    var newAttachments = []
                    for (var i = 0; i < attachments.count; i++) {
                        var attachment = []
                        var item = attachments.get(i)
                        attachment.push(item.name)
                        attachment.push(item.contentType)
                        attachment.push(item.filePath)
                        newAttachments.push(attachment)
                    }
                    chatManager.sendMMS(participants, textEntry.text, newAttachments, messages.accountId)
                    textEntry.text = ""
                    attachments.clear()
                    return
                }

                chatManager.sendMessage(participants, textEntry.text, messages.accountId)
                textEntry.text = ""
            }
        }
    }

    KeyboardRectangle {
        id: keyboard
    }

    Scrollbar {
        flickableItem: messageList
        align: Qt.AlignTrailing
    }
}
