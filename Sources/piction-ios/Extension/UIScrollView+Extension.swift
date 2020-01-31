//
//  UIScrollView+Extension.swift
//  piction-ios
//
//  Created by jhseo on 2020/01/31.
//  Copyright © 2020 Piction Network. All rights reserved.
//

import UIKit

extension UIScrollView {
    func setInfiniteScrollStyle() {
        if #available(iOS 12.0, *) {
            if self.traitCollection.userInterfaceStyle == .dark {
                self.infiniteScrollIndicatorStyle = .white
            } else {
                self.infiniteScrollIndicatorStyle = .gray
            }
        }
    }
}
