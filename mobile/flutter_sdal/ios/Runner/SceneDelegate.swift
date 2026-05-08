import Flutter
import FirebaseAuth
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var photoEditorCaptureChannel: FlutterMethodChannel?
  private var watchBridgeChannel: FlutterMethodChannel?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    configurePhotoEditorCaptureChannel()
    configureWatchBridgeChannel()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    configurePhotoEditorCaptureChannel()
    configureWatchBridgeChannel()
    WatchBridge.shared.resendSessionIfAvailable()
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      if Auth.auth().canHandle(context.url) {
        return
      }
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  private func configurePhotoEditorCaptureChannel() {
    guard photoEditorCaptureChannel == nil,
          let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "sdal/photo_editor_capture",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "capture_delegate_missing",
            message: "Scene delegate artik mevcut degil.",
            details: nil
          )
        )
        return
      }

      guard call.method == "captureRegion" else {
        result(FlutterMethodNotImplemented)
        return
      }

      self.handleCaptureRegion(call: call, result: result)
    }
    photoEditorCaptureChannel = channel
  }

  private func configureWatchBridgeChannel() {
    guard watchBridgeChannel == nil,
          let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.sdal/watch",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "pushSession":
        if let args = call.arguments as? [String: Any],
           let cookie = args["cookie"] as? String,
           let baseUrl = args["baseUrl"] as? String {
          let userId = args["userId"] as? Int ?? 0
          let userPhoto = args["userPhoto"] as? String ?? ""
          WatchBridge.shared.pushSession(
            cookie: cookie,
            baseUrl: baseUrl,
            userId: userId,
            userPhoto: userPhoto
          )
        }
        result(nil)
      case "clearSession":
        WatchBridge.shared.clearSession()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    watchBridgeChannel = channel
  }

  private func handleCaptureRegion(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let x = arguments["x"] as? Double,
          let y = arguments["y"] as? Double,
          let width = arguments["width"] as? Double,
          let height = arguments["height"] as? Double else {
      result(
        FlutterError(
          code: "capture_bad_args",
          message: "Capture koordinatlari eksik veya gecersiz.",
          details: call.arguments
        )
      )
      return
    }

    DispatchQueue.main.async { [weak self] in
      guard let self else {
        result(
          FlutterError(
            code: "capture_delegate_missing",
            message: "Scene delegate artik mevcut degil.",
            details: nil
          )
        )
        return
      }

      let targetRect = CGRect(x: x, y: y, width: width, height: height).integral
      do {
        let pngData = try self.captureWindowRegion(rect: targetRect)
        result(FlutterStandardTypedData(bytes: pngData))
      } catch {
        result(
          FlutterError(
            code: "capture_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  private func captureWindowRegion(rect: CGRect) throws -> Data {
    guard let window = window ?? activeWindow() else {
      throw NSError(
        domain: "photo_editor_capture",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Aktif pencere bulunamadi."]
      )
    }

    let boundedRect = rect.intersection(window.bounds).integral
    guard !boundedRect.isNull, !boundedRect.isEmpty else {
      throw NSError(
        domain: "photo_editor_capture",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Capture alani gorunur degil."]
      )
    }

    let format = UIGraphicsImageRendererFormat.default()
    format.scale = window.screen.scale
    format.opaque = false

    let renderer = UIGraphicsImageRenderer(size: boundedRect.size, format: format)
    let image = renderer.image { context in
      let shiftedBounds = window.bounds.offsetBy(dx: -boundedRect.minX, dy: -boundedRect.minY)
      if !window.drawHierarchy(in: shiftedBounds, afterScreenUpdates: true) {
        context.cgContext.saveGState()
        context.cgContext.translateBy(x: -boundedRect.minX, y: -boundedRect.minY)
        window.layer.render(in: context.cgContext)
        context.cgContext.restoreGState()
      }
    }

    guard let data = image.pngData(), !data.isEmpty else {
      throw NSError(
        domain: "photo_editor_capture",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Capture PNG verisi olusturulamadi."]
      )
    }
    return data
  }

  private func activeWindow() -> UIWindow? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
    for scene in scenes {
      if let keyWindow = scene.windows.first(where: \.isKeyWindow) {
        return keyWindow
      }
    }
    return scenes.first?.windows.first
  }
}
