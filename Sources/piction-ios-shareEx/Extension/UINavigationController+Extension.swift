//
//  UINavigationController+Extension.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/07.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

extension UINavigationController {
    public func configureNavigationBar(transparent: Bool, shadow: Bool) {
        if #available(iOS 13.0, *) {
            let navBarAppearance = UINavigationBarAppearance()
            if transparent {
                navBarAppearance.configureWithTransparentBackground()
            } else {
                navBarAppearance.configureWithOpaqueBackground()
            }
            if !shadow {
                navBarAppearance.shadowImage = nil
                navBarAppearance.shadowColor = nil
            }
            navBarAppearance.largeTitleTextAttributes = [
                NSAttributedString.Key.foregroundColor: .pictionDarkGray,
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 34)
            ]
            navigationBar.scrollEdgeAppearance = navBarAppearance
            navigationBar.standardAppearance = navBarAppearance
        } else {
            navigationBar.isTranslucent = true
            if transparent {
                navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
            } else {
                navigationBar.setBackgroundImage(UIImage().imageWithColor(color: .white), for: UIBarMetrics.default)
            }
            if shadow {
                navigationBar.setValue(false, forKey: "hidesShadow")
                navigationBar.shadowImage = UINavigationBar.appearance().shadowImage
            } else {
                navigationBar.setValue(true, forKey: "hidesShadow")
                navigationBar.shadowImage = UIImage()
            }
        }
    }
}

