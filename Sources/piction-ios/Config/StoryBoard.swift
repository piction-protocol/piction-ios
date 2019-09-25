//
//  StoryBoard.swift
//  PictionView
//
//  Created by jhseo on 18/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//


import UIKit

public enum Storyboard: String {
    case Explorer
    case SignIn
    case SignUp
    case SignUpComplete
    case MyPage
    case UserInfo
    case MyProject
    case ChangeMyInfo
    case ChangePassword
    case SubscriptionList
    case TransactionHistory
    case TransactionDetail
    case Project
    case SeriesPost
    case ProjectInfo
    case Post
    case PostHeader
    case PostFooter
    case SearchProject
    case CreateProject
    case CreatePost
    case SponsorshipList
    case SponsorshipHistory
    case SearchSponsor
    case SendDonation
    case ConfirmDonation
    case CustomEmptyView
    case Deposit
    case CheckPincode
    case RegisterPincode
    case ConfirmPincode
    case QRCodeScanner

    public func instantiate<VC: UIViewController>(_ viewController: VC.Type) -> VC {
        guard
            let vc = UIStoryboard(name: self.rawValue, bundle: nil)
                .instantiateViewController(withIdentifier: VC.storyboardIdentifier) as? VC
            else { fatalError("Couldn't instantiate \(VC.storyboardIdentifier) from \(self.rawValue)") }

        return vc
    }
}
