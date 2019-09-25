//
//  Int+Extension.swift
//  PictionSDK
//
//  Created by jhseo on 21/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation

extension Optional where Wrapped == Int {
    internal var commaRepresentation: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        return formatter.string(from: NSNumber(value: self ?? 0)) ?? "0"
    }
}

extension Int {
    internal var commaRepresentation: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }
}
