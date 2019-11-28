//
//  UIColor+Extension.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/07.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

extension UIColor {
    static let pictionDarkGrayDM = UIColor(named: "PictionDarkGray") ?? UIColor(r: 51, g: 51, b: 51)
    static let pictionDarkGray = UIColor(r: 51, g: 51, b: 51)
    static let pictionBlue = UIColor(r: 26, g: 146, b: 255)
    static let pictionGray = UIColor(r: 191, g: 191, b: 191)
    static let pictionLightGray = UIColor(r: 242, g: 242, b: 242)
    static let pictionRed = UIColor(r: 213, g: 19, b: 21)
    static var placeHolderColor: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.placeholderText
        } else {
            return UIColor(r: 60, g: 60, b: 60, a: 0.3)
        }
    }

    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")

        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }

    convenience init(rgb: Int, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF),
            green: CGFloat((rgb >> 8) & 0xFF),
            blue: CGFloat(rgb & 0xFF),
            alpha: alpha
        )
    }

    convenience init(r: Int, g: Int, b: Int, a: CGFloat = 1.0) {
        let red = CGFloat(r) / 255
        let green = CGFloat(g) / 255
        let blue = CGFloat(b) / 255

        self.init(red: red, green: green, blue: blue, alpha: a)
    }

    convenience init?(_ hexaDecimalString: String, alpha: CGFloat) {
        let r, g, b: CGFloat

        if hexaDecimalString.hasPrefix("#") {
            let start = hexaDecimalString.index(hexaDecimalString.startIndex, offsetBy: 1)
            let hexColor = String(hexaDecimalString[start...])

            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    self.init(red: r, green: g, blue: b, alpha: alpha)
                    return
                }
            }
        }
        return nil
    }

    var hexString: String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        let multiplier = CGFloat(255.999999)

        guard self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        if alpha == 1.0 {
            return String(
                format: "#%02lX%02lX%02lX",
                Int(red * multiplier),
                Int(green * multiplier),
                Int(blue * multiplier)
            )
        }
        else {
            return String(
                format: "#%02lX%02lX%02lX%02lX",
                Int(red * multiplier),
                Int(green * multiplier),
                Int(blue * multiplier),
                Int(alpha * multiplier)
            )
        }
    }
}
