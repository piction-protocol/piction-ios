//
//  UIViewController.Container+Extension.swift
//  piction-ios-test-shareEx
//
//  Created by jhseo on 2019/11/06.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Swinject
import UIKit
import PictionSDK

extension CreatePostViewController {
    static func make(context: NSExtensionContext?) -> CreatePostViewController {
        return Container.shared.resolve(CreatePostViewController.self, argument: context)!
    }
}

extension ManageSeriesViewController {
    static func make(uri: String) -> ManageSeriesViewController {
        return Container.shared.resolve(ManageSeriesViewController.self, argument: uri)!
    }
}

extension EmptyViewController {
    static func make(style: EmptyViewStyle) -> EmptyViewController {
        return Container.shared.resolve(EmptyViewController.self, argument: style)!
    }
}

extension CheckPincodeViewController {
    static func make() -> CheckPincodeViewController {
        return Container.shared.resolve(CheckPincodeViewController.self)!
    }
}

extension ProjectListViewController {
    static func make(projects: [ProjectModel]) -> ProjectListViewController {
        return Container.shared.resolve(ProjectListViewController.self, argument: projects)!
    }
}
