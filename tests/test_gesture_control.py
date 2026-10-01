import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "bin" / "gesture-control"


class GestureControlTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary_directory.name)
        self.config = self.directory / "input.lua"
        self.original = "-- existing Hyprland input configuration\n"
        self.config.write_text(self.original, encoding="utf-8")
        self.config.chmod(0o640)

        self.bin_directory = self.directory / "bin"
        self.bin_directory.mkdir()
        hyprctl = self.bin_directory / "hyprctl"
        hyprctl.write_text(
            "#!/usr/bin/env bash\n"
            "if [[ $1 == reload && ${HYPRCTL_RELOAD_FAIL:-0} == 1 ]]; then\n"
            "  echo 'reload failed' >&2\n"
            "  exit 1\n"
            "fi\n"
            "if [[ $1 == configerrors && -n ${HYPRCTL_CONFIG_ERRORS:-} ]]; then\n"
            "  printf '%s\\n' \"$HYPRCTL_CONFIG_ERRORS\"\n"
            "fi\n",
            encoding="utf-8",
        )
        hyprctl.chmod(0o755)

        self.environment = os.environ.copy()
        self.environment["OMARCHY_GESTURE_CONFIG"] = str(self.config)
        self.environment["PATH"] = str(self.bin_directory) + os.pathsep + self.environment["PATH"]

    def tearDown(self):
        self.temporary_directory.cleanup()

    def run_helper(self, *arguments, environment=None, timeout=5):
        return subprocess.run(
            [str(HELPER), *arguments],
            text=True,
            capture_output=True,
            env=environment or self.environment,
            timeout=timeout,
        )

    def enable(self):
        result = self.run_helper("set", "enabled", "true")
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def assert_no_temporary_files(self):
        self.assertEqual(list(self.directory.glob(".input.lua.workspace-gesture-switcher.*.tmp")), [])

    def test_status_returns_defaults_without_modifying_file(self):
        result = self.run_helper("status")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout),
            {
                "enabled": False,
                "distance": 80,
                "cancelRatio": 0.2,
                "minSpeed": 10,
                "createNew": True,
                "forever": False,
                "configured": False,
            },
        )
        self.assertEqual(self.config.read_text(encoding="utf-8"), self.original)

    def test_first_enable_creates_backup_and_atomic_configuration(self):
        original_inode = self.config.stat().st_ino

        settings = self.enable()

        contents = self.config.read_text(encoding="utf-8")
        self.assertTrue(settings["configured"])
        self.assertTrue(settings["enabled"])
        self.assertIn("hl.gesture({ fingers = 3", contents)
        self.assertEqual(
            (self.directory / "input.lua.backup-workspace-gesture-switcher").read_text(encoding="utf-8"),
            self.original,
        )
        self.assertNotEqual(self.config.stat().st_ino, original_inode)
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o640)
        self.assert_no_temporary_files()

    def test_all_settings_can_still_be_changed_and_read(self):
        self.enable()
        changes = (
            ("distance", "140"),
            ("cancelRatio", "0.35"),
            ("minSpeed", "25"),
            ("createNew", "false"),
            ("forever", "true"),
            ("enabled", "false"),
        )
        for key, value in changes:
            result = self.run_helper("set", key, value)
            self.assertEqual(result.returncode, 0, f"{key}: {result.stderr}")

        result = self.run_helper("status")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout),
            {
                "enabled": False,
                "distance": 140,
                "cancelRatio": 0.35,
                "minSpeed": 25,
                "createNew": False,
                "forever": True,
                "configured": True,
            },
        )
        self.assert_no_temporary_files()

    def test_config_error_restores_original_file_atomically(self):
        self.enable()
        before = self.config.read_bytes()
        environment = self.environment.copy()
        environment["HYPRCTL_CONFIG_ERRORS"] = "invalid gesture setting"

        result = self.run_helper("set", "distance", "150", environment=environment)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid gesture setting", result.stderr)
        self.assertEqual(self.config.read_bytes(), before)
        self.assert_no_temporary_files()

    def test_reload_failure_restores_original_file(self):
        self.enable()
        before = self.config.read_bytes()
        environment = self.environment.copy()
        environment["HYPRCTL_RELOAD_FAIL"] = "1"

        result = self.run_helper("set", "distance", "150", environment=environment)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("reload failed", result.stderr)
        self.assertEqual(self.config.read_bytes(), before)
        self.assert_no_temporary_files()

    def test_symbolic_link_is_rejected_without_touching_target(self):
        target = self.directory / "target.lua"
        target.write_text("do not change\n", encoding="utf-8")
        self.config.unlink()
        self.config.symlink_to(target)

        result = self.run_helper("status")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("symbolic link", result.stderr)
        self.assertEqual(target.read_text(encoding="utf-8"), "do not change\n")

    def test_fifo_is_rejected_without_blocking(self):
        self.config.unlink()
        os.mkfifo(self.config)

        result = self.run_helper("status", timeout=2)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not a regular file", result.stderr)

    def test_oversized_configuration_is_rejected(self):
        with self.config.open("wb") as config_file:
            config_file.truncate(4 * 1024 * 1024 + 1)

        result = self.run_helper("status")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("safety limit", result.stderr)

    def test_non_regular_backup_is_rejected(self):
        backup = self.directory / "input.lua.backup-workspace-gesture-switcher"
        backup.symlink_to(self.directory / "somewhere-else")

        result = self.run_helper("set", "enabled", "true")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("non-regular backup", result.stderr)
        self.assertEqual(self.config.read_text(encoding="utf-8"), self.original)


if __name__ == "__main__":
    unittest.main()
