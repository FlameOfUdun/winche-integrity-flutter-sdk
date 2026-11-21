#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint winche_integrity.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'winche_integrity'
  s.version          = '0.1.0'
  s.summary          = "Apple's App Attest for Winche Integrity."
  s.description      = <<-DESC
Proves to a Winche project that requests come from its own app, with Apple's App Attest.
                       DESC
  s.homepage         = 'https://github.com/FlameOfUdun/winche-integrity-flutter-sdk'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Ehsan Rashidi' => 'https://github.com/FlameOfUdun' }

  s.source           = { :path => '.' }
  s.source_files = 'winche_integrity/Sources/winche_integrity/**/*.swift'
  s.resource_bundles = {'winche_integrity_privacy' => ['winche_integrity/Sources/winche_integrity/PrivacyInfo.xcprivacy']}
  s.frameworks = 'DeviceCheck', 'CryptoKit'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'winche_integrity_privacy' => ['winche_integrity/Sources/winche_integrity/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
