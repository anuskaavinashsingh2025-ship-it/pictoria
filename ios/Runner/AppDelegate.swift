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
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerPlatformChannel(engineBridge)
  }

  /// Small bridge for facts plugins don't expose (see platform_info.dart).
  private func registerPlatformChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PictoraPlatform") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "pictora/platform", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "deviceStorage":
        // The same figures the Settings app uses: total capacity of the
        // device volume and space available for important data.
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
          .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys),
          let total = values.volumeTotalCapacity,
          let available = values.volumeAvailableCapacityForImportantUsage
        else {
          result(nil)
          return
        }
        result(["totalBytes": Int64(total), "availableBytes": available])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
