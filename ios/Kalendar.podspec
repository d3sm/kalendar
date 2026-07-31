Pod::Spec.new do |s|
  s.name           = 'Kalendar'
  s.version        = '0.1.2'
  s.summary        = 'Native SwiftUI calendar for React Native.'
  s.description    = 'A custom SwiftUI month grid bridged to React Native.'
  s.author         = 'd3sm'
  s.homepage       = 'https://github.com/d3sm/kalendar'
  s.platforms      = {
    :ios => '16.4',
    :tvos => '16.4'
  }
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  # Swift/Objective-C compatibility
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
end
