//
//  KeyboardManager.swift
//  PictionView
//
//  Created by jhseo on 16/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//
import UIKit

typealias KeyboardManagerDelegate = KeyboardManagerDelegateRequired & KeyboardManagerDelegateOptional

protocol KeyboardManagerDelegateRequired: class {
    func keyboardManager(_ keyboardManager: KeyboardManager, keyboardWillChangeFrame endFrame: CGRect?, duration: TimeInterval, animationCurve: UIView.AnimationOptions)
}

@objc protocol KeyboardManagerDelegateOptional {
    @objc optional func keyboardWillHide(userInfo: [AnyHashable: Any])
}

class KeyboardManager {

    static let shared = KeyboardManager()

    weak var delegate: KeyboardManagerDelegate?


    init() {
        beginMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    func beginMonitoring() {
        NotificationCenter.default.addObserver(self, selector: #selector(KeyboardManager.keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(KeyboardManager.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        let duration: TimeInterval = ((userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25)
        let animationCurveRawNSN = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
        let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIView.AnimationOptions.curveEaseOut.rawValue
        let animationCurve: UIView.AnimationOptions = UIView.AnimationOptions(rawValue: animationCurveRaw)
        delegate?.keyboardManager(self, keyboardWillChangeFrame: endFrame, duration: duration, animationCurve: animationCurve)
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        delegate?.keyboardWillHide?(userInfo: userInfo)
    }
}
