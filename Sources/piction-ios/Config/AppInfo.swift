//
//  AppInfo.swift
//  PictionView
//
//  Created by jhseo on 20/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

let BUNDLEID = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? ""

var SCREEN_W: CGFloat {
    return UIScreen.main.bounds.size.width
}
var SCREEN_H: CGFloat {
    return UIScreen.main.bounds.size.height
}
let DEFAULT_NAVIGATION_HEIGHT: CGFloat = 44
let STATUS_HEIGHT: CGFloat = UIApplication.shared.statusBarFrame.size.height
let FEATURE_EDITOR = false

final class AppInfo {
    static var isStaging: Bool {
        let infoDictionary: [AnyHashable: Any] = Bundle.main.infoDictionary!
        guard let appID: String = infoDictionary["CFBundleIdentifier"] as? String else { return false }
        return appID == "com.pictionnetwork.piction-test"
    }

    static var urlScheme: String {
        if isStaging {
            return "piction-test"
        } else {
            return "piction"
        }
    }
    
    static var urlDomain: String {
        if isStaging {
            return "staging.piction.network"
        } else {
            return "piction.network"
        }
    }
}
