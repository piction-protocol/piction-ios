//
//  InputAppliable.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

protocol InputAppliable {
    associatedtype Input
    func apply(input: Input)
}

extension InputAppliable {
    func applied(input: Input) -> Self {
        apply(input: input)
        return self
    }
}
