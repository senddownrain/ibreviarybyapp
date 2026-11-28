import DeviceCheck
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "MyBrevAppAttestSupport") {
      let channel = FlutterMethodChannel(
        name: "by.mybrev/app_attest",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "isSupported" else {
          result(FlutterMethodNotImplemented)
          return
        }
        if #available(iOS 14.0, *) {
          result(DCAppAttestService.shared.isSupported)
        } else {
          result(false)
        }
      }
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "mybrev/protected-catalog", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { call, result in
          guard call.method == "directory" else { result(FlutterMethodNotImplemented); return }
          do {
            let manager = FileManager.default
            let support = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                          appropriateFor: nil, create: true)
            var directory = support.appendingPathComponent("protected-prayers-v1", isDirectory: true)
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            var attributes = URLResourceValues()
            attributes.isExcludedFromBackup = true
            try directory.setResourceValues(attributes)
            result(directory.path)
          } catch {
            result(FlutterError(code: "STORAGE", message: nil, details: nil))
          }
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
