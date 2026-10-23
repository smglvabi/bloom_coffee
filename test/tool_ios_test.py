"""Exercise launcher safety/selection without claiming a native iOS build.

Run: python3 -m unittest discover -s test -p 'tool_ios_test.py' -v
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = "com.apple.CoreSimulator.SimRuntime.iOS-18-2"
SIM_ID = "SIM-IPHONE16-PRO"
PHONE_ID = "PHYSICAL-IPHONE"


class IosLauncherTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.bin = self.path / "bin"
        self.bin.mkdir()
        stub = "#!" + sys.executable + r'''
import json, os, pathlib, sys
command = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['MOCK_LOG'], 'a') as f:
    f.write(json.dumps([command] + args) + '\n')
if command == 'uname':
    print(os.environ.get('MOCK_OS', 'Darwin'))
elif command == 'xcode-select':
    print('/Applications/Xcode.app/Contents/Developer')
elif command == 'xcodebuild':
    print('Xcode 16.2')
elif command == 'flutter':
    if args == ['devices', '--machine']:
        print(os.environ['MOCK_PHONES'])
    elif args[:2] == ['pub', 'get']:
        sys.exit(int(os.environ.get('MOCK_PUB_EXIT', '0')))
elif command == 'xcrun':
    if args == ['simctl', 'list', '--json']:
        print(os.environ['MOCK_SIMS'])
    elif args[:2] == ['simctl', 'create']:
        print('NEW-SIM-ID')
'''
        for command in ["uname", "xcode-select", "xcodebuild", "flutter", "xcrun", "open"]:
            target = self.bin / command
            target.write_text(stub)
            target.chmod(0o755)
        self.env = dict(os.environ)
        self.env.update(
            PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
            MOCK_LOG=str(self.path / "commands.jsonl"),
            MOCK_PHONES=json.dumps([
                {"id": SIM_ID, "name": "iPhone 16 Pro", "targetPlatform": "ios", "emulator": True},
                {"id": PHONE_ID, "name": "Мой iPhone", "targetPlatform": "ios", "emulator": False},
                {"id": "ANDROID", "name": "Android", "targetPlatform": "android-arm64", "emulator": False},
            ]),
            MOCK_SIMS=json.dumps({
                "runtimes": [{"identifier": RUNTIME, "version": "18.2", "isAvailable": True}],
                "devices": {RUNTIME: [{"udid": SIM_ID, "name": "iPhone 16 Pro", "isAvailable": True, "state": "Booted"}]},
                "devicetypes": [{"identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro"}],
            }),
        )
        self.env.pop("BLOOM_FLUTTER", None)

    def run_launcher(self, *args):
        return subprocess.run(
            ["bash", str(ROOT / "tool/ios.sh"), *args],
            env=self.env, capture_output=True, text=True, timeout=15,
        )

    def commands(self):
        path = self.path / "commands.jsonl"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_check_can_run_on_linux_and_uses_locked_dependencies(self):
        self.env["MOCK_OS"] = "Linux"
        result = self.run_launcher("check")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.commands(), [
            ["flutter", "pub", "get", "--enforce-lockfile"],
            ["flutter", "analyze"], ["flutter", "test"],
        ])

    def test_dependency_failure_preserves_status_and_stops_checks(self):
        self.env["MOCK_PUB_EXIT"] = "42"
        result = self.run_launcher("check")
        self.assertEqual(result.returncode, 42)
        self.assertEqual(self.commands(), [["flutter", "pub", "get", "--enforce-lockfile"]])

    def test_prepare_checks_platform_before_installing(self):
        self.env["MOCK_OS"] = "Linux"
        result = self.run_launcher("prepare")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Mac", result.stderr)
        self.assertFalse(any(command[0] == "flutter" for command in self.commands()))

    def test_device_chooses_only_physical_ios_and_runs_release(self):
        result = self.run_launcher("device")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(["flutter", "pub", "get", "--enforce-lockfile"], self.commands())
        self.assertEqual(self.commands()[-1], ["flutter", "run", "--release", "-d", PHONE_ID])

    def test_device_rejects_simulator_udid_before_preparing(self):
        result = self.run_launcher("device", SIM_ID)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Физический iPhone не найден", result.stderr)
        self.assertNotIn(["flutter", "precache", "--ios"], self.commands())

    def test_multiple_physical_phones_require_explicit_choice(self):
        phones = json.loads(self.env["MOCK_PHONES"])
        phones.append({"id": "OTHER-PHONE", "name": "Другой iPhone", "targetPlatform": "ios", "emulator": False})
        self.env["MOCK_PHONES"] = json.dumps(phones)
        result = self.run_launcher("device")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("несколько iPhone", result.stderr)
        self.assertNotIn(["flutter", "precache", "--ios"], self.commands())

    def test_simulator_reuses_booted_iphone(self):
        result = self.run_launcher("simulator")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(["xcrun", "simctl", "boot", SIM_ID], self.commands())
        self.assertIn(["xcrun", "simctl", "bootstatus", SIM_ID, "-b"], self.commands())
        self.assertEqual(self.commands()[-1], ["flutter", "run", "-d", SIM_ID])

    def test_simulator_creates_device_on_latest_available_runtime(self):
        sims = json.loads(self.env["MOCK_SIMS"])
        sims["devices"] = {}
        sims["runtimes"].insert(0, {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-17-0", "version": "17.0", "isAvailable": True})
        sims["runtimes"].append({"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-19-0", "version": "19.0", "isAvailable": False})
        self.env["MOCK_SIMS"] = json.dumps(sims)
        result = self.run_launcher("simulator")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(["xcrun", "simctl", "create", "iPhone 16 Pro", "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro", RUNTIME], self.commands())
        self.assertEqual(self.commands()[-1], ["flutter", "run", "-d", "NEW-SIM-ID"])

    def test_missing_runtime_is_actionable_and_does_not_prepare(self):
        self.env["MOCK_SIMS"] = json.dumps({"runtimes": [], "devices": {}})
        result = self.run_launcher("simulator")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Components", result.stderr)
        self.assertNotIn(["flutter", "precache", "--ios"], self.commands())


if __name__ == "__main__":
    unittest.main()
