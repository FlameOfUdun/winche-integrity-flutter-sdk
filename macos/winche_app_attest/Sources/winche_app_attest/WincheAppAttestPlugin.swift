import CryptoKit
import DeviceCheck
import Foundation
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

/// Apple's App Attest for Winche Integrity: a key in the Secure Enclave, its attestation (once) and assertions with it,
/// each for SHA-256 of a challenge from the project. The key's id is kept in UserDefaults (it isn't a secret: the key
/// never leaves the device).
public class WincheAppAttestPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "winche_app_attest", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(WincheAppAttestPlugin(), channel: channel)
  }

  private let defaults = UserDefaults.standard
  private static let prefix = "winche.appAttest."

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "isSupported":
      result(Self.service?.isSupported ?? false)
    case "load":
      result(defaults.string(forKey: Self.prefix + (args["name"] as? String ?? "")))
    case "save":
      defaults.set(args["value"] as? String, forKey: Self.prefix + (args["name"] as? String ?? ""))
      result(nil)
    case "remove":
      defaults.removeObject(forKey: Self.prefix + (args["name"] as? String ?? ""))
      result(nil)
    case "generateKey":
      guard let service = Self.supported(result) else { return }
      service.generateKey { keyId, error in
        Self.answer(result, keyId, error)
      }
    case "attestKey":
      guard let service = Self.supported(result), let keyId = args["keyId"] as? String, let challenge = args["challenge"] as? String else {
        return Self.badArguments(result)
      }
      service.attestKey(keyId, clientDataHash: Self.hash(challenge)) { attestation, error in
        Self.answer(result, attestation?.base64EncodedString(), error)
      }
    case "generateAssertion":
      guard let service = Self.supported(result), let keyId = args["keyId"] as? String, let challenge = args["challenge"] as? String else {
        return Self.badArguments(result)
      }
      service.generateAssertion(keyId, clientDataHash: Self.hash(challenge)) { assertion, error in
        Self.answer(result, assertion?.base64EncodedString(), error)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static var service: DCAppAttestService? {
    if #available(iOS 14.0, macOS 11.0, *) { return DCAppAttestService.shared }
    return nil
  }

  private static func supported(_ result: FlutterResult) -> DCAppAttestService? {
    guard let service = service, service.isSupported else {
      result(FlutterError(code: "unsupported", message: "App Attest isn't available on this device (simulators don't have it): use a debug token there.", details: nil))
      return nil
    }
    return service
  }

  private static func badArguments(_ result: FlutterResult) {
    result(FlutterError(code: "arguments", message: "keyId and challenge are needed.", details: nil))
  }

  /// SHA-256 of the challenge's UTF-8, as the project hashes it.
  private static func hash(_ challenge: String) -> Data { Data(SHA256.hash(data: Data(challenge.utf8))) }

  /// The value, or the App Attest error as invalidKey, invalidInput, serverUnavailable, featureUnsupported or unknown.
  private static func answer(_ result: @escaping FlutterResult, _ value: String?, _ error: Error?) {
    DispatchQueue.main.async {
      if let error = error {
        let code: String
        switch (error as NSError).code {
        case DCError.Code.invalidKey.rawValue: code = "invalidKey"
        case DCError.Code.invalidInput.rawValue: code = "invalidInput"
        case DCError.Code.serverUnavailable.rawValue: code = "serverUnavailable"
        case DCError.Code.featureUnsupported.rawValue: code = "unsupported"
        default: code = "unknown"
        }
        result(FlutterError(code: code, message: error.localizedDescription, details: nil))
      } else {
        result(value)
      }
    }
  }
}
