#!/usr/bin/env python3
"""Configure a pre-signing bundle and prepare (never upload) a Sparkle release."""
import argparse
import base64
import binascii
from html import escape
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
from urllib.parse import quote, urlsplit
import xml.etree.ElementTree as ET

SPARKLE = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'


def validate_config(feed, key):
    url = urlsplit(feed)
    if (url.scheme != 'https' or not url.hostname or url.username is not None
            or url.password is not None or url.fragment or url.query or any(c.isspace() for c in feed)):
        raise ValueError('CLIPIO_UPDATE_FEED_URL must be an HTTPS URL without credentials, query or fragment')
    try:
        decoded = base64.b64decode(key, validate=True)
    except (ValueError, binascii.Error) as error:
        raise ValueError('CLIPIO_UPDATE_PUBLIC_KEY must be a base64 Ed25519 public key') from error
    if len(decoded) != 32:
        raise ValueError('CLIPIO_UPDATE_PUBLIC_KEY must decode to 32 bytes')


def configure(path):
    feed = os.environ.get('CLIPIO_UPDATE_FEED_URL', '')
    key = os.environ.get('CLIPIO_UPDATE_PUBLIC_KEY', '')
    if feed or key:
        validate_config(feed, key)
    info = plistlib.loads(path.read_bytes())
    # Clear values from an earlier incremental build when updates aren't requested.
    for name in ['SUFeedURL', 'SUPublicEDKey']:
        info.pop(name, None)
    if feed:
        info.update(SUFeedURL=feed, SUPublicEDKey=key)
    info.update(SUEnableAutomaticChecks=True, SUAllowsAutomaticUpdates=False,
                SUAutomaticallyUpdate=False, SUEnableSystemProfiling=False)
    path.write_bytes(plistlib.dumps(info))
    print('Clipio updates configured' if feed else 'Clipio updates disabled (no feed/key supplied)')


def release_entitlements(app, source, output):
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    bundle_id = info['CFBundleIdentifier']
    entitlements = plistlib.loads(source.read_bytes())
    service_key = 'com.apple.security.temporary-exception.mach-lookup.global-name'
    entitlements[service_key] = [
        value.replace('$(PRODUCT_BUNDLE_IDENTIFIER)', bundle_id)
        for value in entitlements.get(service_key, [])
    ]
    if any('$(' in value for value in entitlements[service_key]):
        raise ValueError('Unresolved release entitlement variable')
    output.write_bytes(plistlib.dumps(entitlements))


def run(*arguments):
    subprocess.run([str(arg) for arg in arguments], check=True)


def validate_appcast(feed, archive, version, download_prefix):
    items = ET.parse(feed).findall('./channel/item')
    if len(items) != 1 or len(items[0].findall('enclosure')) != 1:
        raise ValueError('Expected exactly one release in the staged appcast')
    release = items[0]
    item = release.find('enclosure')
    expected_url = download_prefix + quote(archive.name)
    if (release.findtext(SPARKLE + 'version') != version or item.get('url') != expected_url
            or item.get('length') != str(archive.stat().st_size)):
        raise ValueError('Appcast version, download URL or archive length does not match the release')
    signature = item.get(SPARKLE + 'edSignature', '')
    try:
        if len(base64.b64decode(signature, validate=True)) != 64:
            raise ValueError('Missing or invalid Ed25519 update signature')
    except binascii.Error as error:
        raise ValueError('Invalid Ed25519 signature encoding') from error
    return signature


def prepare(app, output, sparkle_bin, notes):
    if output.exists():
        raise ValueError('Refusing to overwrite existing update output')
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    feed, key = info.get('SUFeedURL', ''), info.get('SUPublicEDKey', '')
    validate_config(feed, key)
    if info.get('CFBundleIdentifier') != 'com.clipio.app':
        raise ValueError('Only com.clipio.app may be published on the Clipio feed')
    version = str(info['CFBundleVersion'])
    if not version.isascii() or not version.isdigit():
        raise ValueError('Clipio build number must be an increasing integer')
    if info.get('SUAllowsAutomaticUpdates') is not False:
        raise ValueError('Clipio updates must require user-approved installation')
    tool = sparkle_bin / 'generate_appcast'
    if not tool.is_file():
        raise ValueError('Sparkle generate_appcast tool not found')
    # Validate the exact app that will go in the update archive.
    run(Path(__file__).with_name('release-beta.sh'), '--validate-only', app)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.clipio-update-', dir=output.parent) as temporary:
        stage = Path(temporary)
        archive = stage / f'Clipio-{version}.zip'
        run('/usr/bin/ditto', '-c', '-k', '--keepParent', app, archive)
        if notes:
            # Embed escaped plain text; no additional notes URL or executable HTML.
            (stage / f'Clipio-{version}.html').write_text('<pre>' + escape(notes.read_text()) + '</pre>')
        download_prefix = feed.rsplit('/', 1)[0] + '/'
        run(tool, '--account', 'com.clipio.app.updates', '--download-url-prefix', download_prefix,
            '--maximum-deltas', '0', '--embed-release-notes', '-o', stage / 'appcast.xml', stage)
        signature = validate_appcast(stage / 'appcast.xml', archive, version, download_prefix)
        # Independently verify against the key embedded in the app, not merely the Keychain key.
        run('/usr/bin/swift', Path(__file__).with_name('verify-update.swift'), archive, key, signature)
        # Only the two assets needed by the feed are delivered. No cache or signing material.
        for extra in stage.iterdir():
            if extra.name not in {archive.name, 'appcast.xml'}:
                if extra.is_dir():
                    shutil.rmtree(extra)
                else:
                    extra.unlink()
        # Never merge into another invocation's output.
        if output.exists():
            raise ValueError('Update output became occupied during preparation')
        stage.rename(output)
    print(f'Prepared verified update assets: {output}. No files were uploaded.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    config = commands.add_parser('configure', help='Apply environment configuration before signing')
    config.add_argument('--plist', required=True, type=Path)
    entitlements = commands.add_parser('entitlements', help='Expand Sparkle service names before signing')
    entitlements.add_argument('--app', required=True, type=Path)
    entitlements.add_argument('--source', required=True, type=Path)
    entitlements.add_argument('--output', required=True, type=Path)
    prep = commands.add_parser('prepare', help='Validate notarized app and prepare signed update assets locally')
    prep.add_argument('--app', required=True, type=Path)
    prep.add_argument('--output', required=True, type=Path)
    prep.add_argument('--sparkle-bin', required=True, type=Path)
    prep.add_argument('--notes', required=True, type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'configure':
            configure(args.plist)
        elif args.command == 'entitlements':
            release_entitlements(args.app, args.source, args.output)
        else:
            prepare(args.app.resolve(), args.output.absolute(), args.sparkle_bin.resolve(), args.notes)
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError, ET.ParseError) as error:
        parser.exit(1, f'Error: {error}\n')


if __name__ == '__main__':
    main()
