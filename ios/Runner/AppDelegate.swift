import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Registers all plugins, including just_audio / audio_service, which
    // publish the lock screen / Dynamic Island "Now Playing" card and handle
    // its play / pause / next / previous buttons.
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
