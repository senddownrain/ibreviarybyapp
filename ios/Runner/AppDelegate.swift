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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
