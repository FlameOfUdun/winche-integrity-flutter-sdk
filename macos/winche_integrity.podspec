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
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
