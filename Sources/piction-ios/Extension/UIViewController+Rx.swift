//
//  UIViewController+Rx.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

extension Reactive where Base: UIViewController {
    private func controlEvent(for selector: Selector) -> ControlEvent<Void> {
        return ControlEvent(events: sentMessage(selector).map { _ in })
    }

    var viewDidLoad: ControlEvent<Void> {
        return controlEvent(for: #selector(Base.viewDidLoad))
    }

    var viewWillAppear: ControlEvent<Void> {
        return controlEvent(for: #selector(Base.viewWillAppear))
    }

    var viewDidAppear: ControlEvent<Void> {
        return controlEvent(for: #selector(Base.viewDidAppear))
    }

    var viewWillDisappear: ControlEvent<Void> {
        return controlEvent(for: #selector(Base.viewWillDisappear))
    }

    var viewDidDisappear: ControlEvent<Void> {
        return controlEvent(for: #selector(Base.viewDidDisappear))
    }

    var viewWillLayoutSubviews: ControlEvent<Void> {
        return controlEvent(for: #selector(Base.viewWillLayoutSubviews))
    }

    var viewDidLayoutSubviews: ControlEvent<Void> {
        return controlEvent(for: #selector(Base.viewDidLayoutSubviews))
    }

    var traitCollectionDidChange: ControlEvent<Void> {
        return controlEvent(for: #selector(Base.traitCollectionDidChange))
    }
}
