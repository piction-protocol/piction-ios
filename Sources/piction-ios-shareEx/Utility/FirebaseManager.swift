//
//  FirebaseManager.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/13.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation
import FirebaseAnalytics

protocol FirebaseManagerProtocol {
    func screenName(_ screenName: String)
    func logEvent(category: String, action: String?, label: String?)
}

class FirebaseManager: FirebaseManagerProtocol {
    init() {}

    func screenName(_ screenName: String) {
        Analytics.setScreenName(screenName, screenClass: nil)
    }

    func logEvent(category: String, action: String?, label: String?) {
        Analytics.logEvent(category, parameters: [
            "action": action ?? "",
            "label": label ?? ""
            ])
    }
}
