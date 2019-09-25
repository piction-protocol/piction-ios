//
//  UITableView+Extension.swift
//  PictionView
//
//  Created by jhseo on 20/06/2019.
//  Copyright © 2018 Piction Network. All rights reserved.
//

import UIKit

class ReuseTableViewCell: UITableViewCell {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
}

class ReuseTableHeaderFooterView: UITableViewHeaderFooterView {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
}

extension UITableView {
    func registerXib<T>(_: T.Type) where T: ReuseTableViewCell {
        let nib = UINib(nibName: T.reuseIdentifier, bundle: nil)
        register(nib, forCellReuseIdentifier: T.reuseIdentifier)
    }

    func registerReusableView<T>(_: T.Type) where T: ReuseTableHeaderFooterView {
        let nib = UINib(nibName: T.reuseIdentifier, bundle: nil)
        register(nib, forHeaderFooterViewReuseIdentifier: T.reuseIdentifier)
    }

    func dequeueReusableCell<T>(forIndexPath indexPath: IndexPath) -> T where T: ReuseTableViewCell {
        guard let cell = self.dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            fatalError("Could not dequeue cell with identifier: \(T.reuseIdentifier)")
        }
        return cell
    }

    func dequeResuableView<T>(_: T.Type) -> T where T: ReuseTableHeaderFooterView {
        guard let reusableView = self.dequeueReusableHeaderFooterView(withIdentifier: T.reuseIdentifier) as? T else {
            fatalError("Could not dequeue reusableView with identifier: \(T.reuseIdentifier)")
        }
        return reusableView
    }
}

