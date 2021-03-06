//
//  DynamicInputView.swift
//  PictionSDK
//
//  Created by jhseo on 12/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

protocol DynamicInputViewDelegate: class {
    func returnKeyAction(_ textField: UITextField)
}

@IBDesignable
class DynamicInputView: UIView {

    private var contentView: UIView!

    @IBOutlet weak var outlineView: UIView!
    @IBOutlet weak var innerShadowView: UIView! {
        didSet {
            innerShadowView.addInnerShadow(onSide: .top, shadowColor: UIColor(r: 0, g: 0, b: 0, a: 0.5), shadowSize: 3, cornerRadius: 8, shadowOpacity: 1)
        }
    }
    @IBOutlet weak var inputContainerView: UIView!
    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var titleLabel: UILabel!

    @IBOutlet weak var secureButton: UIButton!
    @IBOutlet weak var errorContainerView: UIView!
    @IBOutlet weak var errorLabel: UILabel!

    @IBOutlet weak var titleLabelCenterYConstraint: NSLayoutConstraint!
    @IBOutlet weak var textFieldCenterYConstraint: NSLayoutConstraint!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!

    private var defaultPlaceHolder: String = ""

    weak var delegate: DynamicInputViewDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInitialization()
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInitialization()
        configure()
    }

    @IBInspectable
    var title: String = "" {
        didSet {
            titleLabel.text = title
        }
    }

    @IBInspectable
    var errorPlaceHolder: String = "" {
        didSet {
            defaultPlaceHolder = errorPlaceHolder
            errorLabel.text = errorPlaceHolder
            errorContainerView.isHidden = errorPlaceHolder == ""
        }
    }

    @IBInspectable
    var isSecureText: Bool = false {
        didSet {
            secureButton.isHidden = !isSecureText
            if isSecureText {
                toggleSecureText()
            }
        }
    }

    @IBInspectable
    var returnKeyType: Int = UIReturnKeyType.done.rawValue {
        didSet {
            inputTextField.returnKeyType = UIReturnKeyType(rawValue: returnKeyType)!
        }
    }

    private func commonInitialization() {
        contentView = Bundle.main.loadNibNamed("DynamicInputView", owner: self, options: nil)!.first as? UIView
        addSubview(contentView)
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        contentView.frame = self.bounds
    }

    private func configure() {
        titleLabel.text = title
        defaultPlaceHolder = errorPlaceHolder
        errorLabel.text = errorPlaceHolder
        errorContainerView.isHidden = errorPlaceHolder == ""
        inputTextField.returnKeyType = UIReturnKeyType(rawValue: returnKeyType)!
        secureButton.isHidden = !isSecureText

        if isSecureText {
            toggleSecureText()
        }
        layoutSubviews()
    }

    private func toggleSecureText() {
        self.inputTextField.isSecureTextEntry = !self.inputTextField.isSecureTextEntry
        self.secureButton.setImage(self.inputTextField.isSecureTextEntry ? #imageLiteral(resourceName: "icVisibilityOn") : #imageLiteral(resourceName: "icVisibilityOff"), for: .normal)
        let letterSpacing = self.inputTextField.isSecureTextEntry ? 5 : 0.2
         self.inputTextField.defaultTextAttributes.updateValue(letterSpacing,
            forKey: NSAttributedString.Key.kern)
        self.inputTextField.font = self.inputTextField.isSecureTextEntry ? UIFont.systemFont(ofSize: 18, weight: .bold) : UIFont.systemFont(ofSize: 14, weight: .regular)
    }

    func showError(_ error: String) {
        inputTextField.resignFirstResponder()
        outlineView.layer.borderWidth = 0
        titleLabel.textColor = .pictionRed
        inputContainerView.layer.borderColor = UIColor.pictionRed.cgColor
        inputContainerView.backgroundColor = UIColor.pictionRed.withAlphaComponent(0.05)
        errorLabel.text = error
        errorLabel.textColor = .pictionRed
        errorContainerView.isHidden = false
        innerShadowView.isHidden = false

        layoutSubviews()
    }

    @IBAction func secureBtnDidTap(_ sender: Any) {
        toggleSecureText()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if errorContainerView.isHidden {
            frame.size.height = 65
            contentView.frame.size.height = 65
            heightConstraint.constant = 65
        } else {
            frame.size.height = 86
            contentView.frame.size.height = 86
            heightConstraint.constant = 86
        }
    }
}

extension DynamicInputView {
    static func getView() -> DynamicInputView {
        let view = Bundle.main.loadNibNamed("DynamicInputView", owner: self, options: nil)!.first as! DynamicInputView
        return view
    }
}

extension DynamicInputView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.delegate?.returnKeyAction(textField)

        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.innerShadowView.isHidden = true
        self.inputContainerView.backgroundColor = .clear
        self.outlineView.layer.borderWidth = 4
        self.errorContainerView.isHidden = defaultPlaceHolder == ""
        self.errorLabel.text = defaultPlaceHolder
        self.errorLabel.textColor = .pictionGray

        if defaultPlaceHolder == "" {
            heightConstraint.constant = 65
        }
        UIView.animate(withDuration: 0.5) {
            self.inputContainerView.layer.borderColor = UIColor.pictionBlue.cgColor
            self.titleLabel.textColor = .pictionBlue
            self.titleLabel.font = UIFont.systemFont(ofSize: 12)
            self.titleLabelCenterYConstraint.constant = -10
            self.textFieldCenterYConstraint.constant = 10
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        self.outlineView.layer.borderWidth = 0
        self.inputContainerView.layer.borderColor = UIColor.pictionLightGray.cgColor
        self.inputContainerView.backgroundColor = .clear
        self.errorContainerView.isHidden = defaultPlaceHolder == ""
        if textField.text == "" {
            UIView.animate(withDuration: 0.5) {
                self.titleLabel.textColor = .pictionGray
                self.titleLabel.font = UIFont.systemFont(ofSize: 14)
                self.titleLabelCenterYConstraint.constant = 0
                self.textFieldCenterYConstraint.constant = 0
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
