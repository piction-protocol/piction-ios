//
//  StoryBoard.swift
//  PictionView
//
//  Created by jhseo on 18/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//


import UIKit

public enum Storyboard: String {
    case Home
    case Explore
    case CategoryList
    case CategorizedProject
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
    case ProjectDetail
    case SeriesPost
    case ProjectInfo
    case Post
    case PostHeader
    case PostFooter
    case Search
    case CreateProject
    case CreatePost
    case CustomEmptyView
    case Deposit
    case CheckPincode
    case RegisterPincode
    case ConfirmPincode
    case TaggingProject
    case ManageSeries
    case SubscriptionUser
    case MembershipList
    case PurchaseMembership
    case ManageMembership
    case CreateMembership
    case CreatorProfile
    case CreatorProfileHeader

    public func instantiate<VC: UIViewController>(_ viewController: VC.Type) -> VC {
        guard
            let vc = UIStoryboard(name: self.rawValue, bundle: nil)
                .instantiateViewController(withIdentifier: VC.storyboardIdentifier) as? VC
            else { fatalError("Couldn't instantiate \(VC.storyboardIdentifier) from \(self.rawValue)") }

        return vc
    }
}
