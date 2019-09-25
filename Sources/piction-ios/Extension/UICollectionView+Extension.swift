//
//  UICollectionView+Extension.swift
//  PictionSDK
//
//  Created by jhseo on 21/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

enum CollectionViewReusableType: String {
    case header
    case footer

    var typeName: String {
        switch self {
        case .header:
            return UICollectionView.elementKindSectionHeader
        case .footer:
            return UICollectionView.elementKindSectionFooter
        }
    }
}

class ReuseCollectionViewCell: UICollectionViewCell {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
}

class ReuseCollectionReusableView: UICollectionReusableView {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
}

extension UICollectionView {
    func registerXib<T>(_: T.Type) where T: ReuseCollectionViewCell {
        let nib = UINib(nibName: T.reuseIdentifier, bundle: nil)
        register(nib, forCellWithReuseIdentifier: T.reuseIdentifier)
    }

    func registerReusableView<T>(_: T.Type, kind: CollectionViewReusableType) where T: ReuseCollectionReusableView {
        let nib = UINib(nibName: T.reuseIdentifier, bundle: nil)
        register(nib, forSupplementaryViewOfKind: kind.typeName, withReuseIdentifier: T.reuseIdentifier)
    }

    func dequeueReusableCell<T>(forIndexPath indexPath: IndexPath) -> T where T: ReuseCollectionViewCell {
        guard let cell = self.dequeueReusableCell(withReuseIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            fatalError("Could not dequeue cell with identifier: \(T.reuseIdentifier)")
        }
        return cell
    }

    func dequeueReusableView<T>(_: T.Type, indexPath: IndexPath, kind: CollectionViewReusableType) -> T where T: ReuseCollectionReusableView {
        guard let reusableView = dequeueReusableSupplementaryView(ofKind: kind.typeName, withReuseIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            fatalError("Could not dequeue reusableView with identifier: \(T.reuseIdentifier)")
        }
        return reusableView
    }
}
