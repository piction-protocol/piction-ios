//
//  UIApplication+Extension.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

extension UIApplication {
    class func topViewController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {

        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController, !(presented is UISearchController) {
            return topViewController(controller: presented)
        }
        return controller
    }

    class func dismissAllPresentedController(_ completion: (() -> Swift.Void)? = nil) {
        if let window = UIApplication.shared.keyWindow,
            let rootView = window.rootViewController as? TabBarController,
            let selectedView = rootView.selectedViewController?.children.last,
            let controller = selectedView.presentedViewController {

            controller.dismiss(animated: false, completion: completion)
        } else {
            completion?()
        }
    }
}
