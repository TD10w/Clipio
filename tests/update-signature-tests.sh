#!/bin/zsh
set -euo pipefail
project_dir=${0:A:h:h}
test_dir=$(mktemp -d /tmp/clipio-update-signature.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
cat > "$test_dir/fixture.swift" <<'SWIFT'
import CryptoKit
import Foundation
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let key = Curve25519.Signing.PrivateKey()
let other = Curve25519.Signing.PrivateKey()
let archive = Data("synthetic Clipio archive".utf8)
try archive.write(to: directory.appendingPathComponent("archive.zip"))
try JSONSerialization.data(withJSONObject: [
  "key": key.publicKey.rawRepresentation.base64EncodedString(),
  "otherKey": other.publicKey.rawRepresentation.base64EncodedString(),
  "signature": try key.signature(for: archive).base64EncodedString()
]).write(to: directory.appendingPathComponent("fixture.json"))
SWIFT
swift "$test_dir/fixture.swift" "$test_dir"
python3 - "$project_dir" "$test_dir" <<'PY'
import json
from pathlib import Path
import subprocess
import sys
project, directory = map(Path, sys.argv[1:])
data = json.loads((directory / 'fixture.json').read_text())
verifier = ['/usr/bin/swift', str(project / 'scripts/verify-update.swift'), str(directory / 'archive.zip')]
def verify(key):
    return subprocess.run(verifier + [key, data['signature']], capture_output=True, text=True)
result = verify(data['key'])
assert result.returncode == 0, result.stderr
result = verify(data['otherKey'])
assert result.returncode != 0 and 'does not match' in result.stderr, result
(directory / 'archive.zip').write_bytes(b'tampered update')
result = verify(data['key'])
assert result.returncode != 0 and 'does not match' in result.stderr, result
print('Real Ed25519 signature tests passed: valid, wrong key, tampered archive')
PY
