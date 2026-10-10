import AVFoundation
import Flutter
import PhotosUI
import UIKit
import UniformTypeIdentifiers

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MusicallyMediaTools") {
      MediaToolsPlugin.register(with: registrar)
    }
  }
}

/// Native helpers used by the Dart `MediaTools` class:
/// - merge: video-only MP4 + M4A -> MP4 (passthrough, no re-encode)
/// - probe: duration / size / metadata + JPEG thumbnail
/// - pickPhotos / pickFiles: import videos (and audio from Files)
final class MediaToolsPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private var pendingPick: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "musically/media", binaryMessenger: registrar.messenger())
    let instance = MediaToolsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "merge":
      guard let video = args["video"] as? String,
            let audio = args["audio"] as? String,
            let output = args["output"] as? String else {
        result(FlutterError(code: "bad_args", message: "video, audio and output are required", details: nil))
        return
      }
      merge(video: video, audio: audio, output: output, result: result)
    case "probe":
      guard let path = args["path"] as? String else {
        result(FlutterError(code: "bad_args", message: "path is required", details: nil))
        return
      }
      probe(path: path, thumbnail: args["thumbnail"] as? String, result: result)
    case "pickPhotos":
      pickPhotos(result: result)
    case "pickFiles":
      pickFiles(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Merge

  private func merge(video: String, audio: String, output: String, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let videoAsset = AVURLAsset(url: URL(fileURLWithPath: video))
      let audioAsset = AVURLAsset(url: URL(fileURLWithPath: audio))
      guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
        DispatchQueue.main.async {
          result(FlutterError(code: "no_video", message: "The video part has no video track", details: nil))
        }
        return
      }
      let composition = AVMutableComposition()
      do {
        let duration = videoAsset.duration
        let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try compVideo?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
        compVideo?.preferredTransform = videoTrack.preferredTransform
        if let audioTrack = audioAsset.tracks(withMediaType: .audio).first {
          let audioDuration = CMTimeMinimum(audioAsset.duration, duration)
          let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
          try compAudio?.insertTimeRange(CMTimeRange(start: .zero, duration: audioDuration), of: audioTrack, at: .zero)
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "compose_failed", message: error.localizedDescription, details: nil))
        }
        return
      }

      guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
        DispatchQueue.main.async {
          result(FlutterError(code: "export_unavailable", message: "Cannot create an export session", details: nil))
        }
        return
      }
      let outURL = URL(fileURLWithPath: output)
      try? FileManager.default.removeItem(at: outURL)
      export.outputURL = outURL
      export.outputFileType = export.supportedFileTypes.contains(.mp4) ? .mp4 : .mov
      export.shouldOptimizeForNetworkUse = true
      export.exportAsynchronously {
        let status = export.status
        let message = export.error?.localizedDescription
        DispatchQueue.main.async {
          if status == .completed {
            result(output)
          } else {
            result(FlutterError(code: "export_failed", message: message ?? "Export failed", details: nil))
          }
        }
      }
    }
  }

  // MARK: - Probe

  private func probe(path: String, thumbnail: String?, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let asset = AVURLAsset(url: URL(fileURLWithPath: path))
      let seconds = CMTimeGetSeconds(asset.duration)
      var info: [String: Any] = [:]
      if seconds.isFinite && seconds > 0 {
        info["durationMs"] = Int(seconds * 1000)
      }
      for item in asset.commonMetadata {
        if item.commonKey == .commonKeyTitle, let s = item.stringValue, !s.isEmpty {
          info["title"] = s
        } else if item.commonKey == .commonKeyArtist, let s = item.stringValue, !s.isEmpty {
          info["artist"] = s
        }
      }
      if let track = asset.tracks(withMediaType: .video).first {
        info["hasVideo"] = true
        let size = track.naturalSize.applying(track.preferredTransform)
        info["width"] = Int(abs(size.width))
        info["height"] = Int(abs(size.height))
        if let thumbnail = thumbnail {
          let generator = AVAssetImageGenerator(asset: asset)
          generator.appliesPreferredTrackTransform = true
          generator.maximumSize = CGSize(width: 720, height: 720)
          let at = seconds.isFinite && seconds > 3 ? 1.5 : 0
          if let cg = try? generator.copyCGImage(at: CMTime(seconds: at, preferredTimescale: 600), actualTime: nil),
             let data = UIImage(cgImage: cg).jpegData(compressionQuality: 0.85),
             (try? data.write(to: URL(fileURLWithPath: thumbnail))) != nil {
            info["thumbnail"] = thumbnail
          }
        }
      } else if let thumbnail = thumbnail {
        for item in asset.commonMetadata where item.commonKey == .commonKeyArtwork {
          if let data = item.dataValue, (try? data.write(to: URL(fileURLWithPath: thumbnail))) != nil {
            info["thumbnail"] = thumbnail
            break
          }
        }
      }
      DispatchQueue.main.async { result(info) }
    }
  }

  // MARK: - Pickers

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  private func beginPick(_ result: @escaping FlutterResult) -> UIViewController? {
    if pendingPick != nil {
      result(FlutterError(code: "busy", message: "A picker is already open", details: nil))
      return nil
    }
    guard let top = topViewController() else {
      result(FlutterError(code: "no_ui", message: "No view controller to present from", details: nil))
      return nil
    }
    pendingPick = result
    return top
  }

  private func finishPick(_ paths: [String]) {
    let callback = pendingPick
    pendingPick = nil
    callback?(paths)
  }

  private func pickPhotos(result: @escaping FlutterResult) {
    guard #available(iOS 14.0, *) else {
      pickFiles(result: result)
      return
    }
    guard let top = beginPick(result) else { return }
    var config = PHPickerConfiguration()
    config.filter = .videos
    config.selectionLimit = 0
    config.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = self
    top.present(picker, animated: true)
  }

  private func pickFiles(result: @escaping FlutterResult) {
    guard let top = beginPick(result) else { return }
    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie, .audio], asCopy: true)
    } else {
      picker = UIDocumentPickerViewController(documentTypes: ["public.movie", "public.audio"], in: .import)
    }
    picker.allowsMultipleSelection = true
    picker.delegate = self
    top.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finishPick(urls.map { $0.path })
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishPick([])
  }
}

@available(iOS 14.0, *)
extension MediaToolsPlugin: PHPickerViewControllerDelegate {
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    if results.isEmpty {
      finishPick([])
      return
    }
    let group = DispatchGroup()
    let lock = NSLock()
    var paths: [String] = []
    let movie = UTType.movie.identifier
    for item in results {
      let provider = item.itemProvider
      guard provider.hasItemConformingToTypeIdentifier(movie) else { continue }
      group.enter()
      provider.loadFileRepresentation(forTypeIdentifier: movie) { url, _ in
        defer { group.leave() }
        guard let url = url else { return }
        let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
        let name = url.deletingPathExtension().lastPathComponent
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let dest = dir.appendingPathComponent("\(name).\(ext)")
        do {
          try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
          try FileManager.default.copyItem(at: url, to: dest)
          lock.lock()
          paths.append(dest.path)
          lock.unlock()
        } catch {
          // Skip files that could not be copied.
        }
      }
    }
    group.notify(queue: .main) { [weak self] in
      self?.finishPick(paths)
    }
  }
}
