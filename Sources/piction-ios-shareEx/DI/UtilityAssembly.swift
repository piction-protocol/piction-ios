//
//  UtilityAssembly.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/11.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Swinject

final class UtilityAssembly: Assembly {
    func assemble(container: Container) {

        container.register(Updater.self) { resolver in
            return Updater()
            }
            .inObjectScope(.container)
    }
}

