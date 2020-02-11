# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

def ui_pods
  pod 'SDWebImage/WebP'
  pod 'CropViewController'
  pod 'WordPress-Aztec-iOS'
  pod 'Toast-Swift'
  pod 'UIScrollView-InfiniteScroll'
  pod 'GSKStretchyHeaderView'
  pod 'Gridicons'
  pod 'WSTagsField'
end

def rx_pods
  pod 'RxDataSources'
  pod 'RxGesture'
end

def util_pods
  pod 'Swinject'
  pod 'Kanna'
  pod 'Firebase/Analytics'
  pod 'Firebase/Messaging'
  pod 'Firebase/RemoteConfig'
  pod 'Firebase/Crashlytics'
  pod 'ViewModelBindable', :git => 'https://github.com/jhseo/ViewModelBindable.git', :commit => '82811d20fd9a802605c38009e356878f251b0124'
end

def sdk_pods
  pod 'PictionSDK/RxSwift'
end

target 'piction-ios' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for piction-ios
  ui_pods
  rx_pods
  util_pods
  sdk_pods

#  target 'piction-ios-shareEx' do
#   inherit! :search_paths
#  end
end

target 'piction-ios-test' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for piction-ios-test
  ui_pods
  rx_pods
  util_pods
  sdk_pods

#  target 'piction-ios-test-shareEx' do
#    inherit! :search_paths
#  end
end

