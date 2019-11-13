//
//  Updater.swift
//  piction-ios-shareEx
//
//  Created by jhseo on 2019/11/11.
//  Copyright © 2018 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa

protocol UpdaterProtocol {
    var refreshContent: PublishSubject<Void> { get }
}

final class Updater: UpdaterProtocol {
    let refreshContent = PublishSubject<Void>()

    private let disposeBag = DisposeBag()

    init() {}
}

