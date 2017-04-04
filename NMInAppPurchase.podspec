Pod::Spec.new do |s|
  s.name             = 'NMInAppPurchase'
  s.version          = '0.0.3'
  s.summary          = 'Manage In App Purchase with ease'
  s.description      = <<-DESC
Manage In App Purchase with ease. Verify Receipt for Subscription
                       DESC

  s.homepage         = 'https://github.com/NicolasMahe/NMInAppPurchase'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Nicolas Mahé' => 'nicolas@mahe.me' }
  s.source           = { :git => 'https://github.com/NicolasMahe/NMInAppPurchase.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'

  s.source_files = 'NMInAppPurchase/**/*.swift'

  s.frameworks = 'UIKit', 'StoreKit'

  s.dependency 'SwiftyStoreKit', '~> 0.8.2'
  s.dependency 'NMLocalize'
end
