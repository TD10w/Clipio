import CryptoKit
import Foundation

// Public data only: archive path, embedded public key, detached signature.
do {
  guard CommandLine.arguments.count == 4,
        let publicKey = Data(base64Encoded: CommandLine.arguments[2]),
        let signature = Data(base64Encoded: CommandLine.arguments[3]) else {
    throw NSError(domain: "ClipioUpdate", code: 1,
                  userInfo: [NSLocalizedDescriptionKey: "Expected archive, public key and signature"])
  }
  let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
  let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]), options: .mappedIfSafe)
  guard key.isValidSignature(signature, for: archive) else {
    throw NSError(domain: "ClipioUpdate", code: 2,
                  userInfo: [NSLocalizedDescriptionKey: "Update signature does not match the app's public key"])
  }
  print("Update signature verified against embedded public key")
} catch {
  fputs("Error: \(error.localizedDescription)\n", stderr)
  exit(1)
}
