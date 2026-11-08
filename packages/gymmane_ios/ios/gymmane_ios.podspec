Pod::Spec.new do |s|
  s.name             = 'gymmane_ios'
  s.version          = '1.0.0'
  s.summary          = "iOS implementations of GymMane's native channels."
  s.description      = "Screen, haptics, gallery and voice support for GymMane on iOS."
  s.homepage         = 'https://github.com/InlitX/GymMane'
  s.license          = { :type => 'GPL-3.0-only' }
  s.author           = { 'GymMane' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
end
