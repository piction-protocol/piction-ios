//
//  Container+Extension.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
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
