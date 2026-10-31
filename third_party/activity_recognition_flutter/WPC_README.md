activity_recognition_flutter 6.1.0 from pub.dev with two changes:
- `ios/activity_recognition_flutter.podspec` (added): the package ships iOS
  only as a Swift package and this app builds iOS with CocoaPods.
- Android `ActivityRecognitionFlutterPlugin.kt`: an engine removes the
  activity updates only if it asked for them (`tracking` flag). The UI engine
  and the tracking-service engine share one PendingIntent; without this,
  closing the app's screen stopped the service's updates.
Drop this copy once the app moves to Swift Package Manager and the package
fixes the second point.
