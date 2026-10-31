# Added by WPC CRM (2026-10-31): the published plugin (6.1.0) ships its iOS
# code only as a Swift package, and this app builds iOS with CocoaPods.
Pod::Spec.new do |s|
  s.name             = 'activity_recognition_flutter'
  s.version          = '6.1.0'
  s.summary          = 'Activity recognition (CMMotionActivityManager).'
  s.homepage         = 'https://pub.dev/packages/activity_recognition_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CARP' => 'cph.cachet@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'activity_recognition_flutter/Sources/activity_recognition_flutter/**/*.swift'
  s.dependency 'Flutter'
  s.frameworks       = 'CoreMotion'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
