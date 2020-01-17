//
//  ViewModelAssembly.swift
//  PictionView
//
//  Created by jhseo on 17/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import Swinject
import PictionSDK

final class ViewModelAssembly: Assembly {
    func assemble(container: Container) {
        container.register(HomeViewModel.self) { resolver in
            return HomeViewModel(dependency: (
                resolver.resolve(Updater.self)!)
            )
        }

        container.register(ExploreViewModel.self) { resolver in
            return ExploreViewModel(dependency: (
                resolver.resolve(Updater.self)!)
            )
        }

        container.register(CategoryListViewModel.self) { resolver in
            return CategoryListViewModel(dependency: (
                resolver.resolve(Updater.self)!)
            )
        }

        container.register(CategorizedProjectViewModel.self) { (resolver, categoryId: Int) in
            return CategorizedProjectViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                categoryId: categoryId)
            )
        }

        container.register(SignInViewModel.self) { resolver in
            return SignInViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                resolver.resolve(KeyboardManager.self)!)
            )
        }

        container.register(SignUpViewModel.self) { resolver in
            return SignUpViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                resolver.resolve(KeyboardManager.self)!)
            )
        }

        container.register(SignUpCompleteViewModel.self) { (resolver, loginId: String) in
            return SignUpCompleteViewModel(
                loginId: loginId
            )
        }

        container.register(MyPageViewModel.self) { resolver in
            return MyPageViewModel(dependency: (
                resolver.resolve(Updater.self)!)
            )
        }

        container.register(MyProjectViewModel.self) { resolver in
            return MyProjectViewModel(dependency: (
                resolver.resolve(Updater.self)!)
            )
        }

        container.register(UserInfoViewModel.self) { resolver in
            return UserInfoViewModel(dependency: (
                resolver.resolve(Updater.self)!)
            )
        }

        container.register(ChangeMyInfoViewModel.self) { resolver in
            return ChangeMyInfoViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                resolver.resolve(KeyboardManager.self)!)
            )
        }

        container.register(ChangePasswordViewModel.self) { resolver in
            return ChangePasswordViewModel(dependency: (
                resolver.resolve(KeyboardManager.self)!)
            )
        }

        container.register(SubscriptionListViewModel.self) { resolver in
            return SubscriptionListViewModel(dependency: (
                resolver.resolve(Updater.self)!)
            )
        }

        container.register(TransactionHistoryViewModel.self) { resolver in
            return TransactionHistoryViewModel()
        }

        container.register(ProjectViewModel.self) { (resolver, uri: String) in
            return ProjectViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                uri: uri)
            )
        }

        container.register(ProjectInfoViewModel.self) { (resolver, uri: String) in
            return ProjectInfoViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                uri: uri)
            )
        }

        container.register(PostViewModel.self) { (resolver, uri: String, postId: Int) in
            return PostViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                uri: uri,
                postId: postId)
            )
        }

        container.register(PostHeaderViewModel.self) { (resolver, postItem: PostModel, userInfo: UserModel) in
            return PostHeaderViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                postItem: postItem,
                userInfo: userInfo)
            )
        }

        container.register(PostFooterViewModel.self) { (resolver, uri: String, postItem: PostModel) in
            return PostFooterViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                uri: uri,
                postItem: postItem)
            )
        }

        container.register(SearchViewModel.self) { resolver in
            return SearchViewModel()
        }

        container.register(CreateProjectViewModel.self) { (resolver, uri: String) in
            return CreateProjectViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                resolver.resolve(KeyboardManager.self)!,
                uri: uri)
            )
        }

        container.register(CreatePostViewModel.self) { (resolver, uri: String, postId: Int) in
            return CreatePostViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                uri: uri,
                postId: postId)
            )
        }

        container.register(CustomEmptyViewModel.self) { (resolver, style: CustomEmptyViewStyle) in
            return CustomEmptyViewModel(style: style)
        }

        container.register(DepositViewModel.self) { resolver in
            return DepositViewModel()
        }

        container.register(CheckPincodeViewModel.self) { (resolver, style) in
            return CheckPincodeViewModel(style: style)
        }

        container.register(RegisterPincodeViewModel.self) { resolver in
            return RegisterPincodeViewModel()
        }

        container.register(ConfirmPincodeViewModel.self) { (resolver, inputPincode) in
            return ConfirmPincodeViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                inputPincode: inputPincode)
            )
        }

        container.register(TransactionDetailViewModel.self) { (resolver, transaction: TransactionModel) in
            return TransactionDetailViewModel(transaction: transaction)
        }

        container.register(SeriesPostViewModel.self) { (resolver, uri: String, seriesId: Int) in
            return SeriesPostViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                uri: uri,
                seriesId: seriesId)
            )
        }

        container.register(TaggingProjectViewModel.self) { (resolver, tag: String) in
            return TaggingProjectViewModel(tag: tag)
        }

        container.register(ManageSeriesViewModel.self) { (resolver, uri: String, seriesId: Int?) in
            return ManageSeriesViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                uri: uri,
                seriesId: seriesId)
            )
        }

        container.register(SubscriptionUserViewModel.self) { (resolver, uri: String) in
            return SubscriptionUserViewModel(uri: uri)
        }

        container.register(FanPassListViewModel.self) { (resolver, uri: String, postId: Int?) in
            return FanPassListViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                uri: uri,
                postId: postId)
            )
        }

        container.register(SubscribeFanPassViewModel.self) { (resolver, uri: String, selectedFanPass: FanPassModel) in
            return SubscribeFanPassViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                uri: uri,
                selectedFanPass: selectedFanPass)
            )
        }

        container.register(ManageFanPassViewModel.self) { (resolver, uri: String, fanPassId: Int?) in
            return ManageFanPassViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                uri: uri,
                fanPassId: fanPassId)
            )
        }

        container.register(CreateFanPassViewModel.self) { (resolver, uri: String, fanPass: FanPassModel?) in
            return CreateFanPassViewModel(dependency: (
                resolver.resolve(Updater.self)!,
                uri: uri,
                fanPass: fanPass)
            )
        }
    }
}
