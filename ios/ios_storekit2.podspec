#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint ios_storekit2.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'ios_storekit2'
  s.version          = '0.0.7'
  s.summary          = 'Flutter plugin for iOS in-app purchases using StoreKit 2.'
  s.description      = <<-DESC
Flutter plugin for iOS in-app purchases using StoreKit 2.
                       DESC
  s.homepage         = 'https://github.com/abuharsky/flutter_ios_storekit2'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'abuharsky' => 'noreply@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'ios_storekit2/Sources/ios_storekit2/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {'ios_storekit2_privacy' => ['ios_storekit2/Sources/ios_storekit2/PrivacyInfo.xcprivacy']}
end
