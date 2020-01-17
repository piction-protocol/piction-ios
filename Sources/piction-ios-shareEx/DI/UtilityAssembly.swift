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

        container.register(UpdaterProtocol.self) { resolver in
            return Updater()
            }
            .inObjectScope(.container)

        container.register(KeyboardManagerProtocol.self) { resolver in
            return KeyboardManager()
            }
            .inObjectScope(.container)
    }
}

