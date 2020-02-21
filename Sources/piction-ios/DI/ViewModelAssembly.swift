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
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!)
            )
        }

        container.register(ExploreViewModel.self) { resolver in
            return ExploreViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!)
            )
        }

        container.register(CategoryListViewModel.self) { resolver in
            return CategoryListViewModel(dependency: (
                resolver.resolve(UpdaterProtocol.self)!)
            )
        }

        container.register(CategorizedProjectViewModel.self) { (resolver, categoryId: Int) in
            return CategorizedProjectViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                categoryId: categoryId)
            )
        }

        container.register(SignInViewModel.self) { resolver in
            return SignInViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                resolver.resolve(KeyboardManagerProtocol.self)!,
                resolver.resolve(KeychainManagerProtocol.self)!)
            )
        }

        container.register(SignUpViewModel.self) { resolver in
            return SignUpViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                resolver.resolve(KeyboardManagerProtocol.self)!,
                resolver.resolve(KeychainManagerProtocol.self)!)
            )
        }

        container.register(SignUpCompleteViewModel.self) { (resolver, loginId: String) in
            return SignUpCompleteViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(KeychainManagerProtocol.self)!,
                loginId: loginId)
            )
        }

        container.register(MyPageViewModel.self) { resolver in
            return MyPageViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                resolver.resolve(KeychainManagerProtocol.self)!)
            )
        }

        container.register(MyProjectViewModel.self) { resolver in
            return MyProjectViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!)
            )
        }

        container.register(UserInfoViewModel.self) { resolver in
            return UserInfoViewModel(dependency: (
                resolver.resolve(UpdaterProtocol.self)!)
            )
        }

        container.register(ChangeMyInfoViewModel.self) { resolver in
            return ChangeMyInfoViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                resolver.resolve(KeyboardManagerProtocol.self)!)
            )
        }

        container.register(ChangePasswordViewModel.self) { resolver in
            return ChangePasswordViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(KeyboardManagerProtocol.self)!)
            )
        }

        container.register(SubscriptionListViewModel.self) { resolver in
            return SubscriptionListViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!)
            )
        }

        container.register(TransactionHistoryViewModel.self) { resolver in
            return TransactionHistoryViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!)
            )
        }

        container.register(ProjectViewModel.self) { (resolver, uri: String) in
            return ProjectViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                uri: uri)
            )
        }

        container.register(ProjectInfoViewModel.self) { (resolver, uri: String) in
            return ProjectInfoViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                uri: uri)
            )
        }

        container.register(PostViewModel.self) { (resolver, uri: String, postId: Int) in
            return PostViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                uri: uri,
                postId: postId)
            )
        }

        container.register(PostHeaderViewModel.self) { (resolver, postItem: PostModel, userInfo: UserModel) in
            return PostHeaderViewModel(dependency: (
                resolver.resolve(UpdaterProtocol.self)!,
                postItem: postItem,
                userInfo: userInfo)
            )
        }

        container.register(PostFooterViewModel.self) { (resolver, uri: String, postItem: PostModel) in
            return PostFooterViewModel(dependency: (
                resolver.resolve(UpdaterProtocol.self)!,
                uri: uri,
                postItem: postItem)
            )
        }

        container.register(SearchViewModel.self) { resolver in
            return SearchViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!)
            )
        }

        container.register(CreateProjectViewModel.self) { (resolver, uri: String) in
            return CreateProjectViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                resolver.resolve(KeyboardManagerProtocol.self)!,
                uri: uri)
            )
        }

        container.register(CreatePostViewModel.self) { (resolver, uri: String, postId: Int) in
            return CreatePostViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                resolver.resolve(KeyboardManagerProtocol.self)!,
                uri: uri,
                postId: postId)
            )
        }

        container.register(CustomEmptyViewModel.self) { (resolver, style: CustomEmptyViewStyle) in
            return CustomEmptyViewModel(style: style)
        }

        container.register(DepositViewModel.self) { resolver in
            return DepositViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!)
            )
        }

        container.register(CheckPincodeViewModel.self) { (resolver, style) in
            return CheckPincodeViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(KeychainManagerProtocol.self)!,
                style: style)
            )
        }

        container.register(RegisterPincodeViewModel.self) { resolver in
            return RegisterPincodeViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!)
            )
        }

        container.register(ConfirmPincodeViewModel.self) { (resolver, inputPincode) in
            return ConfirmPincodeViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                resolver.resolve(KeychainManagerProtocol.self)!,
                inputPincode: inputPincode)
            )
        }

        container.register(TransactionDetailViewModel.self) { (resolver, transaction: TransactionModel) in
            return TransactionDetailViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                transaction: transaction)
            )
        }

        container.register(SeriesPostViewModel.self) { (resolver, uri: String, seriesId: Int) in
            return SeriesPostViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                uri: uri,
                seriesId: seriesId)
            )
        }

        container.register(TaggingProjectViewModel.self) { (resolver, tag: String) in
            return TaggingProjectViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                tag: tag)
            )
        }

        container.register(ManageSeriesViewModel.self) { (resolver, uri: String, seriesId: Int?) in
            return ManageSeriesViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                uri: uri,
                seriesId: seriesId)
            )
        }

        container.register(SubscriptionUserViewModel.self) { (resolver, uri: String) in
            return SubscriptionUserViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                uri: uri)
            )
        }

        container.register(MembershipListViewModel.self) { (resolver, uri: String, postId: Int?) in
            return MembershipListViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                uri: uri,
                postId: postId)
            )
        }

        container.register(PurchaseMembershipViewModel.self) { (resolver, uri: String, selectedMembership: MembershipModel) in
            return PurchaseMembershipViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                resolver.resolve(KeychainManagerProtocol.self)!,
                uri: uri,
                selectedMembership: selectedMembership)
            )
        }

        container.register(ManageMembershipViewModel.self) { (resolver, uri: String, membershipId: Int?) in
            return ManageMembershipViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                uri: uri,
                membershipId: membershipId)
            )
        }

        container.register(CreateMembershipViewModel.self) { (resolver, uri: String, membership: MembershipModel?) in
            return CreateMembershipViewModel(dependency: (
                resolver.resolve(FirebaseManagerProtocol.self)!,
                resolver.resolve(UpdaterProtocol.self)!,
                uri: uri,
                membership: membership)
            )
        }
    }
}
