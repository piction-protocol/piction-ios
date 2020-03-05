//
//  ShareEntryViewController.swift
//  ShareViewController
//
//  Created by jhseo on 2019/11/06.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

@objc(ShareEntryViewController)

// 현재 사용하지 않는 화면입니다. (에디터 기능 지원안함)

class ShareEntryViewController: UINavigationController {

    init() {
        let pincode = KeychainManager.get(key: .pincode)

        if pincode == "" {
            let vc = CreatePostViewController.make(context: nil)
            super.init(rootViewController: vc)
        } else {
            let vc = CheckPincodeViewController.make()
            super.init(rootViewController: vc)
        }
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.view.transform = CGAffineTransform(translationX: 0, y: self.view.frame.size.height)

        UIView.animate(withDuration: 0.25, animations: { () -> Void in
            self.view.transform = CGAffineTransform.identity
        })
    }
}

