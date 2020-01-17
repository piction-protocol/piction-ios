//
//  ViewModelAssembly.swift
//  piction-ios-test-shareEx
//
//  Created by jhseo on 2019/11/06.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Swinject
import PictionSDK

final class ViewModelAssembly: Assembly {
    func assemble(container: Container) {
        container.register(CreatePostViewModel.self) { (resolver, context: NSExtensionContext?) in
            return CreatePostViewModel(dependency:
                resolver.resolve(KeyboardManager.self)!,
                context: context)
        }

        container.register(ManageSeriesViewModel.self) { (resolver, uri: String) in
            return ManageSeriesViewModel(dependency: (
                resolver.resolve(UpdaterProtocol.self)!,
                uri: uri)
            )
        }

        container.register(EmptyViewModel.self) { (resolver, style: EmptyViewStyle) in
            return EmptyViewModel(style: style)
        }

        container.register(CheckPincodeViewModel.self) { resolver in
            return CheckPincodeViewModel()
        }

        container.register(ProjectListViewModel.self) { (resolver, projects: [ProjectModel]) in
            return ProjectListViewModel(projects: projects)
        }
    }
}
