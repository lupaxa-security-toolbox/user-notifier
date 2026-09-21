from __future__ import annotations

import json
import os
import unittest
from unittest.mock import MagicMock, patch

from tests.support import load_script

slack = load_script("slack_hook", "src/hooks/50-slack")


class PayloadTests(unittest.TestCase):
    def test_fields_and_color(self):
        payload = slack.build_payload(
            "sudo",
            "testhost",
            "wolf is impersonating root on /dev/pts/0",
            "danger",
            "audit",
            "AuditBot",
        )
        self.assertEqual(payload["channel"], "audit")
        self.assertEqual(payload["username"], "AuditBot")
        att = payload["attachments"][0]
        self.assertEqual(att["color"], "danger")
        self.assertEqual(att["fallback"], "wolf is impersonating root on /dev/pts/0")
        fields = {f["title"]: f["value"] for f in att["fields"]}
        self.assertEqual(fields["Type"], "sudo")
        self.assertEqual(fields["Hostname"], "testhost")
        self.assertEqual(fields["Details"], "wolf is impersonating root on /dev/pts/0")
        shorts = {f["title"]: f["short"] for f in att["fields"]}
        self.assertTrue(shorts["Type"])
        self.assertTrue(shorts["Hostname"])
        self.assertFalse(shorts["Details"])


class MainTests(unittest.TestCase):
    def test_empty_webhook_is_noop(self):
        env = {
            "SLACK_WEBHOOK_URL": "",
            "NOTIFY_TYPE": "ssh",
            "NOTIFY_HOST": "testhost",
            "NOTIFY_DETAILS": "wolf has logged on",
            "NOTIFY_COLOR": "danger",
            "SLACK_CHANNEL": "audit",
            "SLACK_USERNAME": "AuditBot",
        }
        with (
            patch.dict(os.environ, env, clear=False),
            patch.object(slack, "post_webhook") as post,
        ):
            self.assertEqual(slack.main(), 0)
            post.assert_not_called()

    def test_posts_payload(self):
        env = {
            "SLACK_WEBHOOK_URL": "https://hooks.example/xxx",
            "NOTIFY_TYPE": "ssh",
            "NOTIFY_HOST": "testhost",
            "NOTIFY_DETAILS": "wolf has logged on",
            "NOTIFY_COLOR": "danger",
            "SLACK_CHANNEL": "audit",
            "SLACK_USERNAME": "AuditBot",
        }
        with (
            patch.dict(os.environ, env, clear=False),
            patch.object(slack, "post_webhook") as post,
        ):
            self.assertEqual(slack.main(), 0)
            post.assert_called_once()
            url, payload = post.call_args.args
            self.assertEqual(url, "https://hooks.example/xxx")
            self.assertEqual(payload["attachments"][0]["color"], "danger")

    def test_argv_fallback_and_open_state_color(self):
        env = {"SLACK_WEBHOOK_URL": "https://hooks.example/xxx"}
        argv = ["50-slack", "ssh", "testhost", "wolf has logged on", "open"]
        with (
            patch.dict(os.environ, env, clear=True),
            patch.object(slack, "post_webhook") as post,
            patch.object(slack.sys, "argv", argv),
        ):
            self.assertEqual(slack.main(), 0)
            post.assert_called_once()
            _, payload = post.call_args.args
            att = payload["attachments"][0]
            self.assertEqual(att["color"], "danger")
            fields = {f["title"]: f["value"] for f in att["fields"]}
            self.assertEqual(fields["Type"], "ssh")
            self.assertEqual(fields["Hostname"], "testhost")
            self.assertEqual(fields["Details"], "wolf has logged on")

    def test_network_error_is_nonzero_and_hides_url(self):
        env = {
            "SLACK_WEBHOOK_URL": "https://hooks.example/secret",
            "NOTIFY_TYPE": "ssh",
            "NOTIFY_HOST": "testhost",
            "NOTIFY_DETAILS": "wolf has logged on",
            "NOTIFY_COLOR": "good",
            "SLACK_CHANNEL": "audit",
            "SLACK_USERNAME": "AuditBot",
        }
        with (
            patch.dict(os.environ, env, clear=False),
            patch.object(slack, "post_webhook", side_effect=OSError("boom")),
            patch.object(slack, "_log") as log,
        ):
            self.assertEqual(slack.main(), 1)
            logged = " ".join(str(c) for c in log.call_args.args)
            self.assertNotIn("hooks.example/secret", logged)

    def test_urlopen_timeout_is_15(self):
        payload = {"channel": "audit"}
        mock_resp = MagicMock()
        mock_resp.read.return_value = b"ok"
        mock_resp.__enter__.return_value = mock_resp
        with patch("urllib.request.urlopen", return_value=mock_resp) as urlopen:
            slack.post_webhook("https://hooks.example/xxx", payload)
            self.assertEqual(urlopen.call_args.kwargs["timeout"], 15)
            req = urlopen.call_args.args[0]
            body = json.loads(req.data.decode("utf-8"))
            self.assertEqual(body, payload)


if __name__ == "__main__":
    unittest.main()
