//
//  Double+Extension.swift
//  piction-ios
//
//  Created by jhseo on 15/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation

extension Optional where Wrapped == Double {
    internal var commaRepresentation: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.roundingMode = .down
        formatter.maximumFractionDigits = 2

        return formatter.string(from: NSNumber(value: self ?? 0)) ?? "0"
    }
}

extension Double {
    internal var commaRepresentation: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.roundingMode = .down
        formatter.maximumFractionDigits = 2

        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }
}
