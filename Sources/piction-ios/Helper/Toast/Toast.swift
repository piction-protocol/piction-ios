//
//  Toast.swift
//  PictionView
//
//  Created by jhseo on 20/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import Toast_Swift

class Toast {
    class func showToast(_ message: String) {
        if let window = UIApplication.shared.keyWindow {

            let toastView = UIView(frame: CGRect(x: 0, y: SCREEN_H - 100, width: SCREEN_W, height: 50))

            if toastView.superview == nil {
                window.addSubview(toastView)
            }
            ToastManager.shared.isTapToDismissEnabled = true

            toastView.makeToast(message, duration: 2.0, position: .bottom, title: nil, image: nil, style: ToastStyle(), completion: { _ in

                if toastView.subviews.count <= 1 {
                    toastView.removeFromSuperview()
                }
            })
        }
    }
}
