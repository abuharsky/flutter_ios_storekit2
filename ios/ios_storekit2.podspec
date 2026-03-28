#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint ios_storekit2.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'ios_storekit2'
  s.version          = '0.0.2'
  s.summary          = 'Flutter plugin for iOS in-app purchases using StoreKit 2.'
  s.description      = <<-DESC
Flutter plugin for iOS in-app purchases using StoreKit 2.
                       DESC
  s.homepage         = 'https://github.com/abuharsky/flutter_ios_storekit2'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'abuharsky' => 'noreply@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'ios_storekit2_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
