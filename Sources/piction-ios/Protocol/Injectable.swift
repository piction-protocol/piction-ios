//
//  Injectable.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

protocol Injectable {
    associatedtype Dependency
    init(dependency: Dependency)
}
