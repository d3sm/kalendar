Pod::Spec.new do |s|
  s.name           = 'Kalendar'
  s.version        = '0.1.0'
  s.summary        = 'Native SwiftUI calendar for React Native — fully styleable.'
  s.description    = 'A custom SwiftUI month grid bridged to React Native. Every color, shape, and font is a prop.'
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
