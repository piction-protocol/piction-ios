//
//  InjectableViewModel.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

protocol ViewModel {
    associatedtype Input
    associatedtype Output
    func build(input: Input) -> Output
}

typealias InjectableViewModel = ViewModel & Injectable
