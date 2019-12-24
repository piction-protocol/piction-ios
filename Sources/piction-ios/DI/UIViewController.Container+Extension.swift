//
//  UIViewController.Container+Extension.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Swinject
import UIKit
import PictionSDK

extension HomeViewController {
    static func make() -> HomeViewController {
        return Container.shared.resolve(HomeViewController.self)!
    }
}

extension ExploreViewController {
    static func make() -> ExploreViewController {
        return Container.shared.resolve(ExploreViewController.self)!
    }
}

extension SignInViewController {
    static func make() -> SignInViewController {
        return Container.shared.resolve(SignInViewController.self)!
    }
}

extension SignUpViewController {
    static func make() -> SignUpViewController {
        return Container.shared.resolve(SignUpViewController.self)!
    }
}

extension SignUpCompleteViewController {
    static func make(loginId: String) -> SignUpCompleteViewController {
        return Container.shared.resolve(SignUpCompleteViewController.self, argument: loginId)!
    }
}

extension MyPageViewController {
    static func make() -> MyPageViewController {
        return Container.shared.resolve(MyPageViewController.self)!
    }
}

extension UserInfoViewController {
    static func make() -> UserInfoViewController {
        return Container.shared.resolve(UserInfoViewController.self)!
    }
}

extension MyProjectViewController {
    static func make() -> MyProjectViewController {
        return Container.shared.resolve(MyProjectViewController.self)!
    }
}

extension ChangeMyInfoViewController {
    static func make() -> ChangeMyInfoViewController {
        return Container.shared.resolve(ChangeMyInfoViewController.self)!
    }
}

extension ChangePasswordViewController {
    static func make() -> ChangePasswordViewController {
        return Container.shared.resolve(ChangePasswordViewController.self)!
    }
}

extension SubscriptionListViewController {
    static func make() -> SubscriptionListViewController {
        return Container.shared.resolve(SubscriptionListViewController.self)!
    }
}

extension TransactionHistoryViewController {
    static func make() -> TransactionHistoryViewController {
        return Container.shared.resolve(TransactionHistoryViewController.self)!
    }
}

extension ProjectViewController {
    static func make(uri: String) -> ProjectViewController {
        return Container.shared.resolve(ProjectViewController.self, argument: uri)!
    }
}

extension ProjectInfoViewController {
    static func make(uri: String) -> ProjectInfoViewController {
        return Container.shared.resolve(ProjectInfoViewController.self, argument: uri)!
    }
}

extension PostViewController {
    static func make(uri: String, postId: Int) -> PostViewController {
        return Container.shared.resolve(PostViewController.self, arguments: uri, postId)!
    }
}

extension PostHeaderViewController {
    static func make(postItem: PostModel, userInfo: UserModel) -> PostHeaderViewController {
        return Container.shared.resolve(PostHeaderViewController.self, arguments: postItem, userInfo)!
    }
}

extension PostFooterViewController {
    static func make(uri: String, postItem: PostModel) -> PostFooterViewController {
        return Container.shared.resolve(PostFooterViewController.self, arguments: uri, postItem)!
    }
}

extension SearchViewController {
    static func make() -> SearchViewController {
        return Container.shared.resolve(SearchViewController.self)!
    }
}

extension CreateProjectViewController {
    static func make(uri: String) -> CreateProjectViewController {
        return Container.shared.resolve(CreateProjectViewController.self, argument: uri)!
    }
}

extension CreatePostViewController {
    static func make(uri: String, postId: Int) -> CreatePostViewController {
        return Container.shared.resolve(CreatePostViewController.self, arguments: uri, postId)!
    }
}

extension CustomEmptyViewController {
    static func make(style: CustomEmptyViewStyle) -> CustomEmptyViewController {
        return Container.shared.resolve(CustomEmptyViewController.self, argument: style)!
    }
}

extension DepositViewController {
    static func make() -> DepositViewController {
        return Container.shared.resolve(DepositViewController.self)!
    }
}

extension CheckPincodeViewController {
    static func make(style: CheckPincodeStyle) -> CheckPincodeViewController {
        return Container.shared.resolve(CheckPincodeViewController.self, argument: style)!
    }
}

extension RegisterPincodeViewController {
    static func make() -> RegisterPincodeViewController {
        return Container.shared.resolve(RegisterPincodeViewController.self)!
    }
}

extension ConfirmPincodeViewController {
    static func make(inputPincode: String) -> ConfirmPincodeViewController {
        return Container.shared.resolve(ConfirmPincodeViewController.self, argument: inputPincode)!
    }
}

extension TransactionDetailViewController {
    static func make(transaction: TransactionModel) -> TransactionDetailViewController {
        return Container.shared.resolve(TransactionDetailViewController.self, argument: transaction)!
    }
}

extension SeriesPostViewController {
    static func make(uri: String, seriesId: Int) -> SeriesPostViewController {
        return Container.shared.resolve(SeriesPostViewController.self, arguments: uri, seriesId)!
    }
}

extension TagResultProjectViewController {
    static func make(tag: String) -> TagResultProjectViewController {
        return Container.shared.resolve(TagResultProjectViewController.self, argument: tag)!
    }
}

extension ManageSeriesViewController {
    static func make(uri: String, seriesId: Int?) -> ManageSeriesViewController {
        return Container.shared.resolve(ManageSeriesViewController.self, arguments: uri, seriesId)!
    }
}

extension SubscriptionUserViewController {
    static func make(uri: String) -> SubscriptionUserViewController {
        return Container.shared.resolve(SubscriptionUserViewController.self, argument: uri)!
    }
}

extension FanPassListViewController {
    static func make(uri: String, postId: Int? = nil) -> FanPassListViewController {
        return Container.shared.resolve(FanPassListViewController.self, arguments: uri, postId)!
    }
}

extension SubscribeFanPassViewController {
    static func make(uri: String, selectedFanPass: FanPassModel) -> SubscribeFanPassViewController {
        return Container.shared.resolve(SubscribeFanPassViewController.self, arguments: uri, selectedFanPass)!
    }
}

extension ManageFanPassViewController {
    static func make(uri: String, fanPassId: Int? = nil) -> ManageFanPassViewController {
        return Container.shared.resolve(ManageFanPassViewController.self, arguments: uri, fanPassId)!
    }
}

extension CreateFanPassViewController {
    static func make(uri: String, fanPass: FanPassModel? = nil) -> CreateFanPassViewController {
        return Container.shared.resolve(CreateFanPassViewController.self, arguments: uri, fanPass)!
    }
}
