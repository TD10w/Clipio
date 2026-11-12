import base64
import importlib.util
import os
from pathlib import Path
import plistlib
import sys
sys.dont_write_bytecode = True
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

SPEC = importlib.util.spec_from_file_location('update_release', Path(__file__).resolve().parents[1] / 'scripts/update-release.py')
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)

class UpdateReleaseTests(unittest.TestCase):
    def setUp(self):
        self.key = base64.b64encode(bytes(range(32))).decode()
        self.feed = 'https://github.com/TD10w/Clipio/releases/download/clipio-updates/appcast.xml'

    def test_complete_configuration(self):
        module.validate_config(self.feed, self.key)

    def test_rejects_invalid_configuration(self):
        for feed in ['', 'http://example.com/feed', 'https:///feed', 'https://user:pass@example.com/feed', 'https://example.com/feed#fragment', 'https://example.com/feed?token=x', 'https://example.com/a b']:
            with self.subTest(feed=feed), self.assertRaises(ValueError):
                module.validate_config(feed, self.key)
        for key in ['', 'bad', base64.b64encode(bytes(31)).decode()]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                module.validate_config(self.feed, key)

    def test_partial_environment_cannot_change_plist(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'Info.plist'
            original = plistlib.dumps({'CFBundleIdentifier': 'com.clipio.app'})
            path.write_bytes(original)
            with patch.dict(os.environ, {'CLIPIO_UPDATE_FEED_URL': self.feed, 'CLIPIO_UPDATE_PUBLIC_KEY': ''}):
                with self.assertRaises(ValueError):
                    module.configure(path)
            self.assertEqual(path.read_bytes(), original)

    def test_configure_and_clear_stale_configuration(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'Info.plist'
            path.write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.clipio.app'}))
            with patch.dict(os.environ, {'CLIPIO_UPDATE_FEED_URL': self.feed, 'CLIPIO_UPDATE_PUBLIC_KEY': self.key}):
                module.configure(path)
            info = plistlib.loads(path.read_bytes())
            self.assertEqual(info['SUFeedURL'], self.feed)
            self.assertEqual(info['SUPublicEDKey'], self.key)
            self.assertFalse(info['SUAllowsAutomaticUpdates'])
            with patch.dict(os.environ, {'CLIPIO_UPDATE_FEED_URL': '', 'CLIPIO_UPDATE_PUBLIC_KEY': ''}):
                module.configure(path)
            info = plistlib.loads(path.read_bytes())
            self.assertNotIn('SUFeedURL', info)
            self.assertNotIn('SUPublicEDKey', info)

    def test_appcast_requires_matching_signed_archive(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / 'Clipio-68.zip'
            archive.write_bytes(b'archive')
            feed = root / 'appcast.xml'
            signature = base64.b64encode(bytes(64)).decode()
            def write(version='68', url='https://example.com/Clipio-68.zip', length='7', sig=signature):
                feed.write_text(f'<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item><sparkle:version>{version}</sparkle:version><enclosure url="{url}" length="{length}" sparkle:edSignature="{sig}" /></item></channel></rss>')
            write()
            self.assertEqual(module.validate_appcast(feed, archive, '68', 'https://example.com/'), signature)
            for changes in [{'version': '67'}, {'length': '1'}, {'url': 'https://evil.example/Clipio-68.zip'}, {'sig': ''}]:
                write(**changes)
                with self.assertRaises(ValueError):
                    module.validate_appcast(feed, archive, '68', 'https://example.com/')

    def test_prepare_refuses_existing_output_before_external_commands(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(module, 'run') as run:
            with self.assertRaises(ValueError):
                module.prepare(Path('/missing.app'), Path(tmp), Path('/missing-tools'), None)
            run.assert_not_called()

if __name__ == '__main__':
    unittest.main()
