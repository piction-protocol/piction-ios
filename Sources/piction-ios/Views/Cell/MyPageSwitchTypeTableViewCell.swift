//
//  MyPageSwitchTypeTableViewCell.swift
//  PictionSDK
//
//  Created by jhseo on 27/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import LocalAuthentication

final class MyPageSwitchTypeTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var switchButton: UISwitch!

    typealias Model = String

    var key = ""

    func configure(with model: Model, key: String) {
        let (title) = (model)

        titleLabel.text = title

        let isOn = UserDefaults(suiteName: "group.\(BUNDLEID)")?.bool(forKey: key) ?? false
        switchButton.setOn(isOn, animated: false)
        self.key = key
    }
    @IBAction func switchBtnDidTap(_ sender: UISwitch) {

        if key == "isEnabledAuthBio" {
            let authContext = LAContext()
            if authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                var description = ""
                switch authContext.biometryType {
                case .faceID:
                    description = LocalizationKey.str_authenticate_by_face_id.localized()
                case .touchID:
                    description = LocalizationKey.str_authenticate_by_touch_id.localized()
                case .none:
                    break
                @unknown default:
                    break
                }

                authContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: description) { [weak self] (success, error) in
                    guard let `self` = self else { return }
                    DispatchQueue.main.async {
                        if success {
                            print("인증 성공")
                            UserDefaults(suiteName: "group.\(BUNDLEID)")?.set(sender.isOn, forKey: self.key)
                        } else {
                            print("인증 실패")
                            self.switchButton.setOn(!sender.isOn, animated: false)
                            if let error = error {
                                print(error.localizedDescription)
                            }
                        }
                    }
                }
            }
        }


    }
}
