# -*- Mode: Python; coding: utf-8; indent-tabs-mode: nil; tab-width: 4 -*-
# Copyright 2012 Canonical
#
# This file is part of messaging-app.
#
# messaging-app is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.

"""Tests for the Messaging App using ofono-phonesim"""

from __future__ import absolute_import

import subprocess
import os
import time

from autopilot.matchers import Eventually
from testtools.matchers import Equals
from testtools import skipUnless

from messaging_app.tests import MessagingAppTestCase

# determine whether we are running with phonesim
try:
    out = subprocess.check_output(["/usr/share/ofono/scripts/list-modems"],
                                  stderr=subprocess.PIPE)
    have_phonesim = out.startswith("[ /phonesim ]")
except subprocess.CalledProcessError:
    have_phonesim = False


@skipUnless(have_phonesim,
            "this test needs to run under with-ofono-phonesim")
class TestMessaging(MessagingAppTestCase):
    """Tests for the communication panel."""

    def setUp(self):
        # provide clean history
        self.history = os.path.expanduser(
            "~/.local/share/history-service/history.sqlite")
        if os.path.exists(self.history):
            os.rename(self.history, self.history + ".orig")
        subprocess.call(["pkill", "history-daemon"])
        subprocess.call(["pkill", "-f", "telephony-service-handler"])

        super(TestMessaging, self).setUp()

        # no initial messages
        self.thread_list = self.app.select_single(objectName="threadList")
        self.assertThat(self.thread_list.visible, Equals(True))
        self.assertThat(self.thread_list.count, Equals(0))

    def tearDown(self):
        super(TestMessaging, self).tearDown()

        # restore history
        try:
            os.unlink(self.history)
        except OSError:
            pass
        if os.path.exists(self.history + ".orig"):
            os.rename(self.history + ".orig", self.history)
        subprocess.call(["pkill", "history-daemon"])
        subprocess.call(["pkill", "-f", "telephony-service-handler"])

    def test_write_new_message(self):
        self.click_new_message_button()

        # type address number
        text_entry = self.main_view.get_newmessage_textfield()
        text_entry.activeFocus.wait_for(True)
        self.keyboard.type("123")
        self.assertThat(text_entry.text, Eventually(Equals("123")))

        # type message
        text_entry = self.main_view.get_newmessage_textarea()
        self.pointing_device.click_object(text_entry)
        text_entry.activeFocus.wait_for(True)
        message = "hello from Ubuntu"
        self.keyboard.type(message)
        self.assertThat(text_entry.text, Eventually(Equals(message)))

        # send
        button = self.main_view.get_send_button()
        self.assertThat(button.enabled, Eventually(Equals(True)))
        self.pointing_device.click_object(button)
        self.assertThat(button.enabled, Eventually(Equals(False)))

        # TODO: verify that we get a bubble with our message

        # switch back to main page with thread list
        self.close_osk()
        self.go_back()
        self.assertThat(self.thread_list.visible, Eventually(Equals(True)))

        # should show our message in the thread list
        self.assertThat(self.thread_list.count, Equals(1))
        # TODO: verify text in the list
        #print self.thread_list
        #for p in self.thread_list.get_properties():
        #    print '  ', p, repr(getattr(self.thread_list, p))
        #for c in self.thread_list.get_children():
        #    print c
        #    for p in c.get_properties():
        #        print '  ', p, repr(getattr(c, p))

    #
    # Helper methods
    #

    def click_new_message_button(self):
        """Click "New message" menu button and wait for "New message" page"""

        self.main_view.open_toolbar()
        toolbar = self.main_view.get_toolbar()
        toolbar.click_button("newMessageButton")
        self.assertThat(self.main_view.get_pagestack().depth,
                        Eventually(Equals(2)))
        self.assertThat(self.main_view.get_messages_page().visible,
                        Eventually(Equals(True)))
        self.assertThat(self.thread_list.visible, Equals(False))

    def close_osk(self):
        """Swipe down to close on-screen keyboard"""

        # TODO: hack! this belongs into the Ubuntu UI toolkit emulator,
        # LP#1239753
        x1, y1, x2, y2 = self.main_view.globalRect
        mid_x = (x2 - x1) // 2
        mid_y = (y2 - y1) * 7 // 10
        self.pointing_device.drag(mid_x, mid_y, mid_x, y2)
        time.sleep(1)

    def go_back(self):
        """Click back button from toolbar"""

        # will fail with i18n; this belongs into the Ubuntu UI toolkit
        # emulator, LP#1239751
        self.main_view.open_toolbar()
        toolbar = self.main_view.get_toolbar()
        back_button = toolbar.select_single("ActionItem", text=u"Back")
        self.assertNotEqual(back_button, None)
        self.pointing_device.click_object(back_button)
