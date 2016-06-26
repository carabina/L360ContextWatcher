#
# Be sure to run `pod lib lint L360ContextWatcher.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'L360ContextWatcher'
  s.version          = '0.1.0'
  s.summary          = 'The easiest way to observe Core Data changes'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
L360ContextWatcher provides a block based API to listen to changes in your core data model. No more NSFetchedResultsController boiler plate! You can even respond to changes before they propogate to your persistant store. It was built for the Life360 and is used on millions of devices.
                       DESC

  s.homepage         = 'https://github.com/life360/L360ContextWatcher'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Yusuf Sobh' => 'yusuf@life360.com' }
  s.source           = { :git => 'https://github.com/life360/L360ContextWatcher.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/life360'

  s.ios.deployment_target = '8.0'

  s.source_files = 'L360ContextWatcher/Classes/**/*'
  
  # s.resource_bundles = {
  #   'L360ContextWatcher' => ['L360ContextWatcher/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'CoreData'
end
