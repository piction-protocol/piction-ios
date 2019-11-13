//
//  Date+Extension.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/12.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation
import Mapper

extension Date {
    var millisecondsSince1970:Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
}
