//
//  Container+Extension.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/07.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Swinject

extension Container {
    static let shared = assembler.resolver

    private static let assembler = Assembler([
        ViewControllerAssembly(),
        ViewModelAssembly(),
        UtilityAssembly()
    ])
}

