Pod::Spec.new do |s|
  s.name                = "FIRManager"
  s.version             = "1.0"
  s.summary             = "FIRManager is library for help to use Firebase Firestore"
  s.homepage            = "https://codecanyon.net/user/witworkapp/portfolio"
  s.license             = 'MIT'
  s.author              = { "Witwork App" => "witwork.digital@gmail.com" }
  s.source              = { :git => "https://github.com/witwork/FIRManager.git" }
  s.social_media_url    = 'https://codecanyon.net/user/witworkapp/portfolio'

  s.platform            = :ios, '13.0'
  s.requires_arc        = true
  s.source_files        = 'FIRManager/**/*.{h,m,swift}'
  s.frameworks          = 'AVFoundation', 'Foundation'
  s.public_header_files = "FIRManager/**/*.h"
  s.subspec 'Core' do |cs|
     cs.dependency 'GoogleSignIn'
     cs.dependency 'Firebase/Core'
     cs.dependency 'Firebase/Firestore'
     cs.dependency 'Firebase/Auth'
     cs.dependency 'Firebase/Crashlytics'
     cs.dependency 'Firebase/Analytics'
     cs.dependency 'GBDeviceInfo', '~> 6.0'
end
end
