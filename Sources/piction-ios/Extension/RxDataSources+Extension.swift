//
//  RxDataSources+Extension.swift
//  piction-ios
//
//  Created by jhseo on 2019/11/15.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Foundation
import RxDataSources

enum SectionType<T> {
    case Section(title: String, items: [T])
}

extension SectionType: SectionModelType {
    typealias Item = T

    var items: [T] {
        switch self {
        case .Section(_, items: let items):
            return items.map { $0 }
        }
    }

    init(original: SectionType, items: [Item]) {
        switch original {
        case .Section(title: let title, _):
            self = .Section(title: title, items: items)
        }
    }
}
