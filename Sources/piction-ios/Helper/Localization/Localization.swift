//
//  Localization.swift
//  piction-ios
//
//  Created by jhseo on 26/09/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

protocol Localization {
    var localized: String { get }
}

extension String: Localization {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    public func localized(with argument: CVarArg = []) -> String {
        return String(format: self.localized, argument)
    }
}

protocol IBLocalizable {
    var localizedId: String? { get set }
}

extension UILabel: IBLocalizable {
    @IBInspectable var localizedId: String? {
        get { return nil }
        set(key) {
            text = key?.localized
        }
    }
}
extension UIButton: IBLocalizable {
    @IBInspectable var localizedId: String? {
        get { return nil }
        set(key) {
            setTitle(key?.localized, for: .normal)
        }
   }
}
extension UIBarItem: IBLocalizable {
    @IBInspectable var localizedId: String? {
        get { return nil }
        set(key) {
            title = key?.localized
        }
   }
}
extension UINavigationItem: IBLocalizable {
    @IBInspectable var localizedId: String? {
        get { return nil }
        set(key) {
            title = key?.localized
        }
   }
}
extension UISearchBar: IBLocalizable {
    @IBInspectable var localizedId: String? {
        get { return nil }
        set(key) {
            placeholder = key?.localized
        }
   }
}
extension UITextField: IBLocalizable {
    @IBInspectable var localizedId: String? {
        get { return nil }
        set(key) {
            placeholder = key?.localized
        }
   }
}
extension UISegmentedControl {
    @IBInspectable var localized: Bool {
        get { return true }
        set {
            for index in 0 ..< numberOfSegments {
                setTitle(titleForSegment(at: index)?.localized ?? "", forSegmentAt: index)
            }
        }
    }
}
extension DynamicInputView {
    @IBInspectable var localizedTitleId: String? {
        get { return nil }
        set(key) {
            title = key?.localized ?? ""
        }
   }
    @IBInspectable var localizedErrorPlaceHolderId: String? {
         get { return nil }
         set(key) {
             errorPlaceHolder = key?.localized ?? ""
         }
    }
}
