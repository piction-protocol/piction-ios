//
//  String+Extension.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/13.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation

extension String {
    var parseSpecialStrToHtmlStr: String {
        var returnStr: String = self

        returnStr = returnStr.replacingOccurrences(of: "&", with: "&amp;")
        returnStr = returnStr.replacingOccurrences(of: "\"", with: "&quot;")
        returnStr = returnStr.replacingOccurrences(of: "'", with: "&#39;")
        returnStr = returnStr.replacingOccurrences(of: "<", with: "&lt;")
        returnStr = returnStr.replacingOccurrences(of: ">", with: "&gt;")
        return returnStr
    }
}
