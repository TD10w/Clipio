#!/usr/bin/env python3
"""Real Sparkle generation/verification with a temporary key; no app launch or publication.
Only the Developer ID / notarization validation step is bypassed for this unsigned fixture.
"""
import importlib.util
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
from unittest.mock import patch

sys.dont_write_bytecode = True
project = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('update_release', project / 'scripts/update-release.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
source_app, sparkle_bin = map(Path, sys.argv[1:])
with tempfile.TemporaryDirectory(prefix='clipio-synthetic-update-') as temporary:
    directory = Path(temporary)
    app = directory / 'Clipio.app'
    shutil.copytree(source_app, app, symlinks=True)
    fixture = directory / 'fixture.swift'
    fixture.write_text('''import CryptoKit
import Foundation
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let key = Curve25519.Signing.PrivateKey()
try Data(key.rawRepresentation.base64EncodedString().utf8).write(to: directory.appendingPathComponent("private-key"))
try Data(key.publicKey.rawRepresentation.base64EncodedString().utf8).write(to: directory.appendingPathComponent("public-key"))
''')
    subprocess.run(['/usr/bin/swift', str(fixture), str(directory)], check=True)
    secret = directory / 'private-key'
    secret.chmod(0o600)
    plist = app / 'Contents/Info.plist'
    info = plistlib.loads(plist.read_bytes())
    info.update(CFBundleIdentifier='com.clipio.app', CFBundleVersion='999001',
                SUFeedURL='https://example.com/clipio/appcast.xml',
                SUPublicEDKey=(directory / 'public-key').read_text(),
                SUAllowsAutomaticUpdates=False)
    plist.write_bytes(plistlib.dumps(info))
    subprocess.run(['/usr/bin/codesign', '--force', '--deep', '--sign', '-', str(app)], check=True)
    notes = directory / 'notes.txt'
    notes.write_text('Synthetic update: retain clipboard history. <not HTML>')
    original_run = module.run
    validation_count = 0
    def fixture_run(*args):
        global validation_count
        if Path(args[0]).name == 'release-beta.sh':
            validation_count += 1
            return  # Explicit synthetic-only boundary; never skip in production.
        if Path(args[0]).name == 'generate_appcast':
            args = (args[0], '--ed-key-file', secret, *args[1:])
        original_run(*args)
    output = directory / 'output'
    with patch.object(module, 'run', side_effect=fixture_run):
        module.prepare(app, output, sparkle_bin, notes)
    assert validation_count == 1
    assert {p.name for p in output.iterdir()} == {'Clipio-999001.zip', 'appcast.xml'}
    assert 'not HTML' in (output / 'appcast.xml').read_text()
    # A failed signing/generation call must not leave deliverable or staging output.
    def failed_run(*args):
        if Path(args[0]).name == 'generate_appcast':
            raise subprocess.CalledProcessError(1, 'synthetic failed signing')
        fixture_run(*args)
    with patch.object(module, 'run', side_effect=failed_run):
        try:
            module.prepare(app, directory / 'failed-output', sparkle_bin, notes)
            raise AssertionError('Expected signing failure')
        except subprocess.CalledProcessError:
            pass
    assert not (directory / 'failed-output').exists()
    assert not list(directory.glob('.clipio-update-*'))
print('Synthetic release pipeline passed: real Sparkle signing + embedded-key verification; failure cleanup')
