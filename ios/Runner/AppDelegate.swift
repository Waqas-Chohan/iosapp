import AVFoundation
import Flutter
import UIKit
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var mediaChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // The implicit engine/window may not be ready yet — retry briefly.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.setupMediaBridge()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
      self?.setupMediaBridge()
    }
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Wires lock-screen / Dynamic Island remote commands to the Flutter side.
  private func setupMediaBridge() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
      try session.setActive(true)
    } catch {
      // Best-effort; app keeps the Flutter audio session init as fallback.
    }

    guard mediaChannel == nil,
          let root = window?.rootViewController,
          let messenger = (root as AnyObject)
            .value(forKeyPath: "binaryMessenger") as? FlutterBinaryMessenger else {
      return // Engine flavor exposes the messenger differently — no-op.
    }

    let channel = FlutterMethodChannel(
      name: "musically/media",
      binaryMessenger: messenger
    )
    mediaChannel = channel

    UIApplication.shared.beginReceivingRemoteControlEvents()

    let center = MPRemoteCommandCenter.shared()
    center.playCommand.isEnabled = true
    center.playCommand.addTarget { [weak channel] _ in
      channel?.invokeMethod("play", arguments: nil)
      return .success
    }
    center.pauseCommand.isEnabled = true
    center.pauseCommand.addTarget { [weak channel] _ in
      channel?.invokeMethod("pause", arguments: nil)
      return .success
    }
    center.nextTrackCommand.isEnabled = true
    center.nextTrackCommand.addTarget { [weak channel] _ in
      channel?.invokeMethod("next", arguments: nil)
      return .success
    }
    center.previousTrackCommand.isEnabled = true
    center.previousTrackCommand.addTarget { [weak channel] _ in
      channel?.invokeMethod("previous", arguments: nil)
      return .success
    }

    channel.setMethodCallHandler { call, result in
      guard call.method == "setNowPlaying" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      var info: [String: Any] = [
        MPMediaItemPropertyTitle: args?["title"] as? String ?? "Musically",
        MPMediaItemPropertyArtist: args?["author"] as? String ?? "",
        MPMediaItemPropertyPlaybackDuration:
          (args?["duration"] as? NSNumber)?.doubleValue ?? 0.0,
        MPNowPlayingInfoPropertyPlaybackRate: 1.0,
      ]
      if let duration = args?["duration"] as? NSNumber, duration.doubleValue > 0 {
        info[MPMediaItemPropertyPlaybackDuration] = duration.doubleValue
      }
      MPNowPlayingInfoCenter.default().nowPlayingInfo = info
      MPNowPlayingInfoCenter.default().playbackState = .playing
      result(nil)
    }
  }
}
