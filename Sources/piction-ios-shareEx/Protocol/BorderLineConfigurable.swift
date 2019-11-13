//
//  BorderLineConfigurable.swift
//  PictionSDK
//
//  Created by jhseo on 21/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

protocol BorderLineConfigurable {
    var borderColor: UIColor { get set }
    var borderWidth: CGFloat { get set }
    var cornerRadius: CGFloat { get set }
}
