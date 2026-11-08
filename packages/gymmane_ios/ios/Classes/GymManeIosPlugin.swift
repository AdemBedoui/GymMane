import AVFoundation
import AudioToolbox
import Flutter
import Photos
import UIKit

/// iOS side of the channels that the Android app implements in Kotlin.
public class GymManeIosPlugin: NSObject, FlutterPlugin, AVSpeechSynthesizerDelegate {
  private static var instance: GymManeIosPlugin?

  private let synthesizer = AVSpeechSynthesizer()
  private var pendingSpeech: FlutterResult?
  private var savedBrightness: CGFloat?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = GymManeIosPlugin()
    plugin.synthesizer.delegate = plugin
    instance = plugin
    let messenger = registrar.messenger()

    FlutterMethodChannel(name: "gymmane/screen", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in plugin.screen(call, result) }
    FlutterMethodChannel(name: "gymmane/haptics", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "buzz" else { return result(FlutterMethodNotImplemented) }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        result(nil)
      }
    FlutterMethodChannel(name: "gymmane/gallery", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in plugin.gallery(call, result) }
    FlutterMethodChannel(name: "gymmane/voice", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in plugin.voice(call, result) }

    installNotificationSound(key: registrar.lookupKey(forAsset: "assets/audio/rest_over.wav"))
  }

  /// iOS only plays notification sounds from the app bundle or Library/Sounds.
  private static func installNotificationSound(key: String) {
    guard let source = Bundle.main.path(forResource: key, ofType: nil),
      let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
    else { return }
    let folder = library.appendingPathComponent("Sounds", isDirectory: true)
    let target = folder.appendingPathComponent("rest_over.wav")
    guard !FileManager.default.fileExists(atPath: target.path) else { return }
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try? FileManager.default.copyItem(atPath: source, toPath: target.path)
  }

  private func screen(_ call: FlutterMethodCall, _ result: FlutterResult) {
    let on = (call.arguments as? [String: Any])?["on"] as? Bool ?? false
    switch call.method {
    case "keepOn":
      UIApplication.shared.isIdleTimerDisabled = on
    case "bright":
      setBrightness(on ? 1.0 : nil)
    case "dim":
      setBrightness(on ? 0.02 : nil)
    default:
      return result(FlutterMethodNotImplemented)
    }
    result(nil)
  }

  private func setBrightness(_ value: CGFloat?) {
    if let value = value {
      if savedBrightness == nil { savedBrightness = UIScreen.main.brightness }
      UIScreen.main.brightness = value
    } else if let saved = savedBrightness {
      UIScreen.main.brightness = saved
      savedBrightness = nil
    }
  }

  private func gallery(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard call.method == "savePng" else { return result(FlutterMethodNotImplemented) }
    guard let bytes = ((call.arguments as? [String: Any])?["bytes"] as? FlutterStandardTypedData)?.data else {
      return result(false)
    }
    let finish: (Bool) -> Void = { ok in DispatchQueue.main.async { result(ok) } }
    let save = {
      PHPhotoLibrary.shared().performChanges({
        PHAssetCreationRequest.forAsset().addResource(with: .photo, data: bytes, options: nil)
      }) { ok, _ in finish(ok) }
    }
    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        if status == .authorized || status == .limited { save() } else { finish(false) }
      }
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        if status == .authorized { save() } else { finish(false) }
      }
    }
  }

  private func voice(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let text = args?["text"] as? String ?? ""
    let lang = args?["lang"] as? String ?? ""
    switch call.method {
    case "say":
      finishSpeech()
      if !text.isEmpty { speak(text, lang) }
      result(true)
    case "sayWait":
      finishSpeech()
      guard !text.isEmpty else { return result(false) }
      pendingSpeech = result
      speak(text, lang)
    case "stop":
      finishSpeech()
      synthesizer.stopSpeaking(at: .immediate)
      result(true)
    case "check":
      result(lang.isEmpty || speechVoice(lang) != nil ? "ok" : "noLang")
    case "settings":
      if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func speechVoice(_ lang: String) -> AVSpeechSynthesisVoice? {
    if let exact = AVSpeechSynthesisVoice(language: lang) { return exact }
    let wanted = lang.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? ""
    return AVSpeechSynthesisVoice.speechVoices().first {
      $0.language.lowercased().split(separator: "-").first.map(String.init) == wanted
    }
  }

  private func speak(_ text: String, _ lang: String) {
    try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
    try? AVAudioSession.sharedInstance().setActive(true)
    synthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: text)
    if !lang.isEmpty { utterance.voice = speechVoice(lang) }
    synthesizer.speak(utterance)
  }

  private func finishSpeech() {
    pendingSpeech?(true)
    pendingSpeech = nil
  }

  public func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { finishSpeech() }
  public func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { finishSpeech() }
}
