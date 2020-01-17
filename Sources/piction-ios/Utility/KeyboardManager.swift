//
//  KeyboardManager.swift
//  PictionView
//
//  Created by jhseo on 16/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa

protocol KeyboardManagerProtocol {
    var keyboardWillChangeFrame: PublishSubject<ChangedKeyboardFrame> { get }
    var keyboardWillHide: PublishSubject<[AnyHashable: Any?]> { get }
    func beginMonitoring()
    func stopMonitoring()
}

typealias ChangedKeyboardFrame = (endFrame: CGRect?, duration: TimeInterval, animationCurve: UIView.AnimationOptions)

class KeyboardManager: KeyboardManagerProtocol {
    var keyboardWillChangeFrame = PublishSubject<ChangedKeyboardFrame>()
    var keyboardWillHide = PublishSubject<[AnyHashable: Any?]>()

    init() {}

    func beginMonitoring() {
        NotificationCenter.default.addObserver(self, selector: #selector(KeyboardManager.keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(KeyboardManager.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

extension KeyboardManager {
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        let duration: TimeInterval = ((userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25)
        let animationCurveRawNSN = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
        let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIView.AnimationOptions.curveEaseOut.rawValue
        let animationCurve: UIView.AnimationOptions = UIView.AnimationOptions(rawValue: animationCurveRaw)
        let changedFrame = ChangedKeyboardFrame(endFrame: endFrame, duration: duration, animationCurve: animationCurve)
        keyboardWillChangeFrame.onNext(changedFrame)
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        keyboardWillHide.onNext(userInfo)
    }
}
