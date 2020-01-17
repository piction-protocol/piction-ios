//
//  UtilityAssembly.swift
//  PictionView
//
//  Created by jhseo on 20/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Swinject

final class UtilityAssembly: Assembly {
    func assemble(container: Container) {

        container.register(UpdaterProtocol.self) { resolver in
            return Updater()
            }
            .inObjectScope(.container)

        container.register(KeyboardManager.self) { resolver in
            return KeyboardManager()
            }
            .inObjectScope(.container)
    }
}

