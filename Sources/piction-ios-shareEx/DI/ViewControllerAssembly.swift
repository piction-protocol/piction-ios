//
//  ViewControllerAssembly.swift
//  piction-ios-test-shareEx
//
//  Created by jhseo on 2019/11/06.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Swinject
import UIKit
import PictionSDK

final class ViewControllerAssembly: Assembly {
    func assemble(container: Container) {
        container.register(CreatePostViewController.self) { (resolver, context: NSExtensionContext?) in
            let vc = Storyboard.CreatePost.instantiate(CreatePostViewController.self)
            vc.viewModel = resolver.resolve(CreatePostViewModel.self, argument: context)!
            return vc
        }

        container.register(SeriesListViewController.self) { (resolver, uri: String) in
            let vc = Storyboard.SeriesList.instantiate(SeriesListViewController.self)
            vc.viewModel = resolver.resolve(SeriesListViewModel.self, argument: uri)!
            return vc
        }

        container.register(EmptyViewController.self) { (resolver, style: EmptyViewStyle) in
            let vc = Storyboard.EmptyView.instantiate(EmptyViewController.self)
            vc.viewModel = resolver.resolve(EmptyViewModel.self, argument: style)!
            return vc
        }

        container.register(CheckPincodeViewController.self) { resolver in
            let vc = Storyboard.CheckPincode.instantiate(CheckPincodeViewController.self)
            vc.viewModel = resolver.resolve(CheckPincodeViewModel.self)!
            return vc
        }

        container.register(ProjectListViewController.self) { (resolver, projects: [ProjectModel]) in
            let vc = Storyboard.ProjectList.instantiate(ProjectListViewController.self)
            vc.viewModel = resolver.resolve(ProjectListViewModel.self, argument: projects)!
            return vc
        }
    }
}
