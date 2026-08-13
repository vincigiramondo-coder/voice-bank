import importlib.util
import os
import stat
import sys
import tempfile
import time
import types
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]


def load_client_module():
    if "requests" not in sys.modules:
        requests_stub = types.ModuleType("requests")
        requests_stub.exceptions = types.SimpleNamespace(RequestException=Exception)
        sys.modules["requests"] = requests_stub
    spec = importlib.util.spec_from_file_location("voice_bank_test_client", ROOT / "air_voice_client.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class PrivacyInvariantTests(unittest.TestCase):
    def test_private_recordings_are_unique_and_owner_only(self):
        client = load_client_module()
        first_dir, first_audio = client.create_secure_recording_path()
        second_dir, second_audio = client.create_secure_recording_path()
        self.addCleanup(lambda: client.shutil.rmtree(first_dir, ignore_errors=True))
        self.addCleanup(lambda: client.shutil.rmtree(second_dir, ignore_errors=True))

        self.assertNotEqual(first_dir, second_dir)
        self.assertEqual(first_audio.name, "recording.wav")
        self.assertEqual(second_audio.name, "recording.wav")
        self.assertEqual(stat.S_IMODE(first_dir.stat().st_mode), 0o700)

    def test_stale_cleanup_ignores_recent_and_unrelated_paths(self):
        client = load_client_module()
        with tempfile.TemporaryDirectory() as root:
            root_path = Path(root)
            stale = root_path / f"{client.TEMP_RECORDING_PREFIX}stale"
            recent = root_path / f"{client.TEMP_RECORDING_PREFIX}recent"
            unrelated = root_path / "another-app"
            stale.mkdir()
            recent.mkdir()
            unrelated.mkdir()
            old = time.time() - client.STALE_RECORDING_SECONDS - 60
            os.utime(stale, (old, old))

            with mock.patch.object(client.tempfile, "gettempdir", return_value=root):
                client.cleanup_stale_recordings()

            self.assertFalse(stale.exists())
            self.assertTrue(recent.exists())
            self.assertTrue(unrelated.exists())

    def test_history_is_opt_in(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            client = load_client_module()
        self.assertFalse(client.SAVE_LOCAL_HISTORY)

    def test_removed_sensitive_runtime_patterns_do_not_return(self):
        sources = "\n".join(
            path.read_text(encoding="utf-8")
            for path in [
                ROOT / "air_voice_client.py",
                ROOT / "menu_bar" / "VoiceInputClient.swift",
                ROOT / "menu_bar" / "VoiceBankMenuBar.swift",
                ROOT / "menu_bar" / "HotkeyService.swift",
            ]
        )
        self.assertNotIn("voicebank-air-client.log", sources)
        self.assertNotIn("voicebank-app.log", sources)
        self.assertNotIn("air_recording.wav", sources)
        self.assertNotIn("keyCode == 58", sources)

    def test_server_defaults_to_loopback_and_requires_lan_auth(self):
        source = (ROOT / "server" / "voice_input_server.py").read_text(encoding="utf-8")
        self.assertIn('"127.0.0.1"', source)
        self.assertIn("Non-loopback mode requires VOICE_BANK_API_TOKEN", source)
        self.assertIn("save_upload_limited", source)
        self.assertNotIn('"runtime_python":', source)
        self.assertNotIn('"memory_dir":', source)


if __name__ == "__main__":
    unittest.main()
