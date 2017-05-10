#
# Be sure to run `pod lib lint OAuth1.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'OAuth1'
  s.version          = '0.2'
  s.summary          = 'OAuth1 for iOS'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = "It's a library on iOS which is suitable for OAuth1."

  s.homepage         = 'https://github.com/trongdth/OAuth1-for-iOS'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'trongdth' => 'trongdth@gmail.com' }
  s.source           = { :git => 'https://github.com/trongdth/OAuth1-for-iOS.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/trongdth'

  s.ios.deployment_target = '8.0'
  s.requires_arc = true

  `echo "2.3" > .swift-version`

  s.source_files = 'OAuth1/Classes/**/*.{h,m}'
  
  # s.resource_bundles = {
  #   'OAuth1' => ['OAuth1/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit', 'QuartzCore', 'SystemConfiguration'
  # s.dependency 'AFNetworking', '~> 2.3'
end
