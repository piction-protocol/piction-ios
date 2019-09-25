//
//  UINavigationController+Extension.swift
//  PictionView
//
//  Created by jhseo on 04/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

extension UINavigationController {

    public func showTransparentNavigationBar() {
        if #available(iOS 13.0, *) {
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithOpaqueBackground()
            navBarAppearance.backgroundColor = .clear
            navBarAppearance.shadowImage = nil
            navBarAppearance.shadowColor = nil
            navigationBar.scrollEdgeAppearance = navBarAppearance
            navigationBar.standardAppearance = navBarAppearance
        } else {
            navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        }
    }

    public func hideTransparentNavigationBar() {
        if #available(iOS 13.0, *) {
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithOpaqueBackground()
            navBarAppearance.backgroundColor = .systemBackground
            navigationBar.scrollEdgeAppearance = navBarAppearance
            navigationBar.standardAppearance = navBarAppearance
        } else {
            navigationBar.setBackgroundImage(UIImage().imageWithColor(color: .white), for: UIBarMetrics.default)
        }
    }

    public func disableNavigationBar() {
        navigationBar.tintColor = UIColor.init(r: 170, g: 0, b: 255, a: 0.3)
        navigationBar.isUserInteractionEnabled = false
    }

    public func enableNavigationBar() {
        navigationBar.tintColor = UIView().tintColor
        navigationBar.isUserInteractionEnabled = true
    }

    public func setNavigationBarLine(_ show: Bool) {
        if show {
            navigationBar.setValue(false, forKey: "hidesShadow")
            navigationBar.shadowImage = UINavigationBar.appearance().shadowImage
        } else {
            navigationBar.setValue(true, forKey: "hidesShadow")
            navigationBar.shadowImage = UIImage()
        }
    }
}

