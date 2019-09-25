//
//  Date+Extension.swift
//  PictionSDK
//
//  Created by jhseo on 22/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation
import Mapper

extension Date {
    func toString(format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }

    var millisecondsSince1970:Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }

    init(milliseconds:Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
