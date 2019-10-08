//
//  FirebaseManager.swift
//  piction-ios
//
//  Created by jhseo on 08/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation
import Firebase

class FirebaseManager {
    class func screenName(_ screenName: String) {
        Analytics.setScreenName(screenName, screenClass: nil)
    }

    class func logEvent(category: String, action: String?, label: String?) {
        Analytics.logEvent(category, parameters: [
            "action": action ?? "",
            "label": label ?? ""
            ])
    }
}
