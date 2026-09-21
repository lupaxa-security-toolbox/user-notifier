from __future__ import annotations

import os
import stat
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tests.support import load_script

notify = load_script("user_notify", "src/user-notify")


class ColorTests(unittest.TestCase):
    def test_open_is_danger(self):
        self.assertEqual(notify.notify_color("open"), "danger")

    def test_close_is_good(self):
        self.assertEqual(notify.notify_color("close"), "good")


class ConfigTests(unittest.TestCase):
    def test_defaults_when_missing(self):
        cfg = notify.load_config("/no/such/notifier.conf")
        self.assertEqual(cfg["hooks_dir"], notify.DEFAULT_HOOKS_DIR)
        self.assertEqual(cfg["webhook_url"], "")
        self.assertEqual(cfg["channel"], "audit")
        self.assertEqual(cfg["username"], "AuditBot")

    def test_reads_ini(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "notifier.conf"
            path.write_text(
                "[notify]\n"
                "hooks_dir = /tmp/hooks\n"
                "[slack]\n"
                "webhook_url = https://hooks.example/xxx\n"
                "channel = ops\n"
                "username = WatchBot\n",
                encoding="utf-8",
            )
            cfg = notify.load_config(str(path))
            self.assertEqual(cfg["hooks_dir"], "/tmp/hooks")
            self.assertEqual(cfg["webhook_url"], "https://hooks.example/xxx")
            self.assertEqual(cfg["channel"], "ops")
            self.assertEqual(cfg["username"], "WatchBot")


class EnvTests(unittest.TestCase):
    def test_exports_contract(self):
        cfg = {
            "hooks_dir": "/etc/user-notifier/hooks.d",
            "webhook_url": "https://hooks.example/xxx",
            "channel": "audit",
            "username": "AuditBot",
        }
        env = notify.hook_environment("ssh", "testhost", "wolf logged on", "open", cfg)
        self.assertEqual(env["NOTIFY_TYPE"], "ssh")
        self.assertEqual(env["NOTIFY_HOST"], "testhost")
        self.assertEqual(env["NOTIFY_DETAILS"], "wolf logged on")
        self.assertEqual(env["NOTIFY_STATE"], "open")
        self.assertEqual(env["NOTIFY_COLOR"], "danger")
        self.assertEqual(env["SLACK_WEBHOOK_URL"], "https://hooks.example/xxx")
        self.assertEqual(env["SLACK_CHANNEL"], "audit")
        self.assertEqual(env["SLACK_USERNAME"], "AuditBot")
        self.assertEqual(env["NOTIFY_HOOKS_DIR"], "/etc/user-notifier/hooks.d")


class HookListTests(unittest.TestCase):
    def test_skips_readme_dot_and_example(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            keep = d / "50-slack"
            keep.write_text("#!/bin/sh\n", encoding="utf-8")
            keep.chmod(keep.stat().st_mode | stat.S_IXUSR)
            (d / "README").write_text("nope\n", encoding="utf-8")
            (d / ".hidden").write_text("#!/bin/sh\n", encoding="utf-8")
            (d / ".hidden").chmod(0o755)
            (d / "99-mail.example").write_text("#!/bin/sh\n", encoding="utf-8")
            (d / "99-mail.example").chmod(0o755)
            skip = d / "not-exec"
            skip.write_text("#!/bin/sh\n", encoding="utf-8")
            hooks = notify.list_hooks(d)
            self.assertEqual([p.name for p in hooks], ["50-slack"])


class RunHooksTests(unittest.TestCase):
    def test_runs_both_and_continues_after_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            one = d / "10-one"
            two = d / "20-two"
            one.write_text(
                '#!/bin/sh\nprintf \'%s\' "$NOTIFY_TYPE" > "$(dirname "$0")/one.out"\nexit 1\n',
                encoding="utf-8",
            )
            two.write_text(
                '#!/bin/sh\nprintf \'%s\' "$NOTIFY_HOST" > "$(dirname "$0")/two.out"\n',
                encoding="utf-8",
            )
            one.chmod(0o755)
            two.chmod(0o755)
            env = os.environ.copy()
            env["NOTIFY_TYPE"] = "ssh"
            env["NOTIFY_HOST"] = "testhost"
            notify.run_hooks([one, two], env, ["ssh", "testhost", "details", "open"])
            self.assertEqual((d / "one.out").read_text(encoding="utf-8"), "ssh")
            self.assertEqual((d / "two.out").read_text(encoding="utf-8"), "testhost")

    def test_main_exits_zero_after_hooks(self):
        with tempfile.TemporaryDirectory() as tmp:
            hooks = Path(tmp) / "hooks"
            hooks.mkdir()
            conf = Path(tmp) / "notifier.conf"
            conf.write_text(f"[notify]\nhooks_dir = {hooks}\n", encoding="utf-8")
            marker = hooks / "ok"
            hook = hooks / "10-ok"
            hook.write_text(
                f"#!/bin/sh\nprintf done > '{marker}'\nexit 2\n",
                encoding="utf-8",
            )
            hook.chmod(0o755)
            old = os.environ.get("USER_NOTIFIER_CONFIG")
            os.environ["USER_NOTIFIER_CONFIG"] = str(conf)
            try:
                rc = notify.main(["ssh", "testhost", "wolf has logged on", "open"])
            finally:
                if old is None:
                    os.environ.pop("USER_NOTIFIER_CONFIG", None)
                else:
                    os.environ["USER_NOTIFIER_CONFIG"] = old
            self.assertEqual(rc, 0)
            self.assertEqual(marker.read_text(encoding="utf-8"), "done")

    def test_usage_without_pam_is_nonzero(self):
        self.assertEqual(notify.main([]), 1)


class MainDispatchTests(unittest.TestCase):
    def test_main_returns_zero_when_load_config_raises(self):
        with patch.object(notify, "load_config", side_effect=OSError("config unreadable")):
            self.assertEqual(notify.main(["ssh", "h", "d", "open"]), 0)

    def test_main_returns_zero_when_list_hooks_raises(self):
        config = {
            "hooks_dir": "/tmp/hooks",
            "webhook_url": "",
            "channel": "audit",
            "username": "AuditBot",
        }
        with (
            patch.object(notify, "load_config", return_value=config),
            patch.object(notify, "list_hooks", side_effect=OSError("hooks unreadable")),
        ):
            self.assertEqual(notify.main(["ssh", "h", "d", "open"]), 0)


if __name__ == "__main__":
    unittest.main()
