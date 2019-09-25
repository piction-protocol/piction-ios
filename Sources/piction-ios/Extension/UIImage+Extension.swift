//
//  UIImage+Extension.swift
//  PictionView
//
//  Created by jhseo on 04/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

extension UIImage {
    func imageWithColor(color: UIColor, size: CGSize=CGSize(width: 1, height: 1)) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(CGRect(origin: CGPoint.zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
