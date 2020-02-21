//
//  ViewControllerAssembly.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Swinject
import UIKit
import PictionSDK

final class ViewControllerAssembly: Assembly {
    func assemble(container: Container) {

        container.register(HomeViewController.self) { resolver in
            let vc = Storyboard.Home.instantiate(HomeViewController.self)
            vc.viewModel = resolver.resolve(HomeViewModel.self)!
            return vc
        }

        container.register(ExploreViewController.self) { resolver in
            let vc = Storyboard.Explore.instantiate(ExploreViewController.self)
            vc.viewModel = resolver.resolve(ExploreViewModel.self)!
            return vc
        }

        container.register(CategoryListViewController.self) { resolver in
            let vc = Storyboard.CategoryList.instantiate(CategoryListViewController.self)
            vc.viewModel = resolver.resolve(CategoryListViewModel.self)!
            return vc
        }

        container.register(CategorizedProjectViewController.self) { (resolver, categoryId: Int) in
            let vc = Storyboard.CategorizedProject.instantiate(CategorizedProjectViewController.self)
            vc.viewModel = resolver.resolve(CategorizedProjectViewModel.self, argument: categoryId)!
            return vc
        }

        container.register(SignInViewController.self) { resolver in
            let vc = Storyboard.SignIn.instantiate(SignInViewController.self)
            vc.viewModel = resolver.resolve(SignInViewModel.self)!
            return vc
        }

        container.register(SignUpViewController.self) { resolver in
            let vc = Storyboard.SignUp.instantiate(SignUpViewController.self)
            vc.viewModel = resolver.resolve(SignUpViewModel.self)!
            return vc
        }

        container.register(SignUpCompleteViewController.self) { (resolver, loginId: String) in
            let vc = Storyboard.SignUpComplete.instantiate(SignUpCompleteViewController.self)
            vc.viewModel = resolver.resolve(SignUpCompleteViewModel.self, argument: loginId)!
            return vc
        }

        container.register(MyPageViewController.self) { resolver in
            let vc = Storyboard.MyPage.instantiate(MyPageViewController.self)
            vc.viewModel = resolver.resolve(MyPageViewModel.self)!
            return vc
        }

        container.register(UserInfoViewController.self) { resolver in
            let vc = Storyboard.UserInfo.instantiate(UserInfoViewController.self)
            vc.viewModel = resolver.resolve(UserInfoViewModel.self)!
            return vc
        }

        container.register(MyProjectViewController.self) { resolver in
            let vc = Storyboard.MyProject.instantiate(MyProjectViewController.self)
            vc.viewModel = resolver.resolve(MyProjectViewModel.self)!
            return vc
        }

        container.register(ChangeMyInfoViewController.self) { resolver in
            let vc = Storyboard.ChangeMyInfo.instantiate(ChangeMyInfoViewController.self)
            vc.viewModel = resolver.resolve(ChangeMyInfoViewModel.self)!
            return vc
        }

        container.register(ChangePasswordViewController.self) { resolver in
            let vc = Storyboard.ChangePassword.instantiate(ChangePasswordViewController.self)
            vc.viewModel = resolver.resolve(ChangePasswordViewModel.self)!
            return vc
        }

        container.register(SubscriptionListViewController.self) { resolver in
            let vc = Storyboard.SubscriptionList.instantiate(SubscriptionListViewController.self)
            vc.viewModel = resolver.resolve(SubscriptionListViewModel.self)!
            return vc
        }

        container.register(TransactionHistoryViewController.self) { resolver in
            let vc = Storyboard.TransactionHistory.instantiate(TransactionHistoryViewController.self)
            vc.viewModel = resolver.resolve(TransactionHistoryViewModel.self)!
            return vc
        }

        container.register(ProjectViewController.self) { (resolver, uri: String) in
            let vc = Storyboard.Project.instantiate(ProjectViewController.self)
            vc.viewModel = resolver.resolve(ProjectViewModel.self, argument: uri)!
            return vc
        }

        container.register(ProjectInfoViewController.self) { (resolver, uri: String) in
            let vc = Storyboard.ProjectInfo.instantiate(ProjectInfoViewController.self)
            vc.viewModel = resolver.resolve(ProjectInfoViewModel.self, argument: uri)!
            return vc
        }

        container.register(PostViewController.self) { (resolver, uri: String, postId: Int) in
            let vc = Storyboard.Post.instantiate(PostViewController.self)
            vc.viewModel = resolver.resolve(PostViewModel.self, arguments: uri, postId)!
            return vc
        }

        container.register(PostHeaderViewController.self) { (resolver, postItem: PostModel, userInfo: UserModel) in
            let vc = Storyboard.PostHeader.instantiate(PostHeaderViewController.self)
            vc.viewModel = resolver.resolve(PostHeaderViewModel.self, arguments: postItem, userInfo)!
            return vc
        }

        container.register(PostFooterViewController.self) { (resolver, uri: String, postItem: PostModel) in
            let vc = Storyboard.PostFooter.instantiate(PostFooterViewController.self)
            vc.viewModel = resolver.resolve(PostFooterViewModel.self, arguments: uri, postItem)!
            return vc
        }

        container.register(SearchViewController.self) { resolver in
            let vc = Storyboard.Search.instantiate(SearchViewController.self)
            vc.viewModel = resolver.resolve(SearchViewModel.self)!
            return vc
        }

        container.register(CreateProjectViewController.self) { (resolver, uri: String) in
            let vc = Storyboard.CreateProject.instantiate(CreateProjectViewController.self)
            vc.viewModel = resolver.resolve(CreateProjectViewModel.self, argument: uri)!
            return vc
        }

        container.register(CreatePostViewController.self) { (resolver, uri: String, postId: Int) in
            let vc = Storyboard.CreatePost.instantiate(CreatePostViewController.self)
            vc.viewModel = resolver.resolve(CreatePostViewModel.self, arguments: uri, postId)!
            return vc
        }

        container.register(CustomEmptyViewController.self) { (resolver, style: CustomEmptyViewStyle) in
            let vc = Storyboard.CustomEmptyView.instantiate(CustomEmptyViewController.self)
            vc.viewModel = resolver.resolve(CustomEmptyViewModel.self, argument: style)!
            return vc
        }

        container.register(DepositViewController.self) { resolver in
            let vc = Storyboard.Deposit.instantiate(DepositViewController.self)
            vc.viewModel = resolver.resolve(DepositViewModel.self)!
            return vc
        }

        container.register(CheckPincodeViewController.self) { (resolver, style: CheckPincodeStyle) in
            let vc = Storyboard.CheckPincode.instantiate(CheckPincodeViewController.self)
            vc.viewModel = resolver.resolve(CheckPincodeViewModel.self, argument: style)!
            return vc
        }

        container.register(RegisterPincodeViewController.self) { resolver in
            let vc = Storyboard.RegisterPincode.instantiate(RegisterPincodeViewController.self)
            vc.viewModel = resolver.resolve(RegisterPincodeViewModel.self)!
            return vc
        }

        container.register(ConfirmPincodeViewController.self) { (resolver, inputPincode: String) in
            let vc = Storyboard.ConfirmPincode.instantiate(ConfirmPincodeViewController.self)
            vc.viewModel = resolver.resolve(ConfirmPincodeViewModel.self, argument: inputPincode)!
            return vc
        }

        container.register(TransactionDetailViewController.self) { (resolver, transaction: TransactionModel) in
            let vc = Storyboard.TransactionDetail.instantiate(TransactionDetailViewController.self)
            vc.viewModel = resolver.resolve(TransactionDetailViewModel.self, argument: transaction)!
            return vc
        }

        container.register(SeriesPostViewController.self) { (resolver, uri: String, seriesId: Int) in
            let vc = Storyboard.SeriesPost.instantiate(SeriesPostViewController.self)
            vc.viewModel = resolver.resolve(SeriesPostViewModel.self, arguments: uri, seriesId)!
            return vc
        }

        container.register(TaggingProjectViewController.self) { (resolver, tag: String) in
            let vc = Storyboard.TaggingProject.instantiate(TaggingProjectViewController.self)
            vc.viewModel = resolver.resolve(TaggingProjectViewModel.self, argument: tag)!
            return vc
        }

        container.register(ManageSeriesViewController.self) { (resolver, uri: String, seriesId: Int?) in
            let vc = Storyboard.ManageSeries.instantiate(ManageSeriesViewController.self)
            vc.viewModel = resolver.resolve(ManageSeriesViewModel.self, arguments: uri, seriesId)!
            return vc
        }

        container.register(SubscriptionUserViewController.self) { (resolver, uri: String) in
            let vc = Storyboard.SubscriptionUser.instantiate(SubscriptionUserViewController.self)
            vc.viewModel = resolver.resolve(SubscriptionUserViewModel.self, argument: uri)!
            return vc
        }

        container.register(MembershipListViewController.self) { (resolver, uri: String, postId: Int?) in
            let vc = Storyboard.MembershipList.instantiate(MembershipListViewController.self)
            vc.viewModel = resolver.resolve(MembershipListViewModel.self, arguments: uri, postId)!
            return vc
        }

        container.register(PurchaseMembershipViewController.self) { (resolver, uri: String, selectedMembership: MembershipModel) in
            let vc = Storyboard.PurchaseMembership.instantiate(PurchaseMembershipViewController.self)
            vc.viewModel = resolver.resolve(PurchaseMembershipViewModel.self, arguments: uri, selectedMembership)!
            return vc
        }

        container.register(ManageMembershipViewController.self) { (resolver, uri: String, membershipId: Int?) in
            let vc = Storyboard.ManageMembership.instantiate(ManageMembershipViewController.self)
            vc.viewModel = resolver.resolve(ManageMembershipViewModel.self, arguments: uri, membershipId)!
            return vc
        }

        container.register(CreateMembershipViewController.self) { (resolver, uri: String, membership: MembershipModel?) in
            let vc = Storyboard.CreateMembership.instantiate(CreateMembershipViewController.self)
            vc.viewModel = resolver.resolve(CreateMembershipViewModel.self, arguments: uri, membership)!
            return vc
        }
    }
}
