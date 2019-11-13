//
//  UIViewController+Extension.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/07.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

extension UIViewController {
    public static var storyboardIdentifier: String {
        return self.description().components(separatedBy: ".").dropFirst().joined(separator: ".")
    }
}

extension UIViewController {
    func embed(_ childViewController: UIViewController, to view: UIView) {
        childViewController.view.frame = view.bounds
        view.addSubview(childViewController.view)
        addChild(childViewController)
        childViewController.didMove(toParent: self)
    }

    func remove(_ childViewController: UIViewController) {
        childViewController.willMove(toParent: nil)
        childViewController.view.removeFromSuperview()
        childViewController.removeFromParent()
    }
}
