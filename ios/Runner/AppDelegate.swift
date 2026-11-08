import CoreLocation
import Flutter
import GoogleMaps
import native_geofence
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CLLocationManagerDelegate {
  /// Significant location changes (2026-11-08): iOS relaunches the app in
  /// the background after it was closed (swiped away) once the phone moved
  /// about 500 m, so tracking starts again without opening the app.
  private let relaunchManager = CLLocationManager()

  /// Headless engine running `iosRelaunchMain` (tracking_service.dart)
  /// while the app was relaunched in the background and not opened.
  private var relaunchEngine: FlutterEngine?
  private var relaunchChannel: FlutterMethodChannel?
  private var appEngineStarted = false

  private let relaunchKey = "wpcRelaunchEnabled"
  private let onDutyKey = "wpcTrackingOnDuty"
  private let stoppedNoticeId = "wpcTrackingStopped"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Attendance geofences can wake the app in the background (native_geofence).
    NativeGeofencePlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // Google Maps key from Info.plist (GMSApiKey).
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String {
      GMSServices.provideAPIKey(key)
    }
    // Running again: the "stopped sharing" notice is no longer true.
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [stoppedNoticeId])
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [stoppedNoticeId])
    relaunchManager.delegate = self
    if UserDefaults.standard.bool(forKey: relaunchKey) {
      // Keeps the service on (and receives its events) after a relaunch.
      relaunchManager.startMonitoringSignificantLocationChanges()
      if launchOptions?[.location] != nil {
        startRelaunchEngine()
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    appEngineStarted = true
    let channel = FlutterMethodChannel(
      name: "wpc/ios_tracking", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleTracking(call, result: result)
    }
  }

  private func handleTracking(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "enableRelaunch":
      UserDefaults.standard.set(true, forKey: relaunchKey)
      relaunchManager.startMonitoringSignificantLocationChanges()
      result(nil)
    case "disableRelaunch":
      UserDefaults.standard.set(false, forKey: relaunchKey)
      UserDefaults.standard.set(false, forKey: onDutyKey)
      relaunchManager.stopMonitoringSignificantLocationChanges()
      result(nil)
    case "setOnDuty":
      UserDefaults.standard.set(call.arguments as? Bool ?? false, forKey: onDutyKey)
      result(nil)
    case "takeOver":
      // The app was opened: its own tracker takes over from the relaunch one.
      stopRelaunchEngine { result(nil) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startRelaunchEngine() {
    guard relaunchEngine == nil, !appEngineStarted else { return }
    let engine = FlutterEngine(name: "wpcRelaunch", project: nil, allowHeadlessExecution: true)
    engine.run(
      withEntrypoint: "iosRelaunchMain",
      libraryURI: "package:wpc_crm/features/tracking/tracking_service.dart")
    GeneratedPluginRegistrant.register(with: engine)
    let channel = FlutterMethodChannel(name: "wpc/ios_relaunch", binaryMessenger: engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "setOnDuty" {
        UserDefaults.standard.set(call.arguments as? Bool ?? false, forKey: self?.onDutyKey ?? "")
      }
      result(nil)
    }
    // The relaunch engine's Dart side uses this channel name too (disableRelaunch).
    let tracking = FlutterMethodChannel(name: "wpc/ios_tracking", binaryMessenger: engine.binaryMessenger)
    tracking.setMethodCallHandler { [weak self] call, result in
      self?.handleTracking(call, result: result)
    }
    relaunchEngine = engine
    relaunchChannel = channel
  }

  private func stopRelaunchEngine(_ done: @escaping () -> Void) {
    guard let engine = relaunchEngine, let channel = relaunchChannel else {
      done()
      return
    }
    relaunchEngine = nil
    relaunchChannel = nil
    channel.invokeMethod("stop", arguments: nil) { _ in
      engine.destroyContext()
      done()
    }
  }

  // Events arrive here; the tracker in Dart takes its own fixes.
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

  /// Swiped away while sharing: iOS stops the location until the app runs
  /// again, so the person is asked to open it (EN + AR).
  override func applicationWillTerminate(_ application: UIApplication) {
    if UserDefaults.standard.bool(forKey: relaunchKey) && UserDefaults.standard.bool(forKey: onDutyKey) {
      let content = UNMutableNotificationContent()
      content.title = "WPC CRM"
      content.body =
        "Location sharing stopped – tap to open the app.\nتوقفت مشاركة الموقع – اضغط لفتح التطبيق."
      content.sound = .default
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
      UNUserNotificationCenter.current().add(
        UNNotificationRequest(identifier: stoppedNoticeId, content: content, trigger: trigger))
      // Gives the request a moment to reach the system before the process ends.
      Thread.sleep(forTimeInterval: 0.5)
    }
    super.applicationWillTerminate(application)
  }
}
