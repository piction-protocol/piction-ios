//
//  Updater.swift
//  PictionView
//
//  Created by jhseo on 27/06/2019.
//  Copyright © 2018 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa

protocol UpdaterProtocol {
    var refreshContent: PublishSubject<Void> { get }
    var refreshSession: PublishSubject<Void> { get }
    var refreshAmount: PublishSubject<Void> { get }
}

final class Updater: UpdaterProtocol {
    let refreshContent = PublishSubject<Void>()
    let refreshSession = PublishSubject<Void>()
    let refreshAmount = PublishSubject<Void>()

    private let disposeBag = DisposeBag()

    init() {}
}

