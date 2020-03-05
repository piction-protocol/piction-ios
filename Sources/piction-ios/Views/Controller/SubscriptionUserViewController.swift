//
//  SubscriptionUserViewController.swift
//  piction-ios
//
//  Created by jhseo on 2019/10/28.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

// MARK: - UIViewController
final class SubscriptionUserViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var emptyView: UIView!
    private var refreshControl = UIRefreshControl()

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            // pull to refresh 추가
            tableView.refreshControl = refreshControl
        }
    }
    @IBOutlet weak var closeButton: UIBarButtonItem!

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension SubscriptionUserViewController: ViewModelBindable {
    typealias ViewModel = SubscriptionUserViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        // infiniteScroll이 동작할 때
        tableView.addInfiniteScroll { [weak self] _ in
            self?.viewModel?.loadTrigger.onNext(())
        }
        // infiniteScroll이 동작하는 조건
        tableView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = SubscriptionUserViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            traitCollectionDidChange: rx.traitCollectionDidChange.asDriver(), // 일반/다크모드 전환 시
            refreshControlDidRefresh: refreshControl.rx.controlEvent(.valueChanged).asDriver(), // pull to refresh 액션 시
            closeBtnDidTap: closeButton.rx.tap.asDriver() // 닫기 버튼 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self?.tableView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // 일반/다크모드 전환 시 Infinite scroll 색 변경
        output
            .traitCollectionDidChange
            .drive(onNext: { [weak self] in
                self?.tableView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // 구독중인 유저의 데이터를 tableView에 출력
        output
            .subscriptionUserList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [SectionModel(model: "subscriptionUser", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // 구독중인 유저의 테이터를 출력 후 infiniteScroll 로딩 해제
        output
            .subscriptionUserList
            .drive(onNext: { [weak self] subscriptionUserList in
                self?.navigationItem.title = "\(LocalizationKey.str_subscription_user_list.localized()) (\(subscriptionUserList.count))"
                self?.tableView.layoutIfNeeded()
                self?.tableView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        // emptyView 출력
        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] in
                self?.embedCustomEmptyViewController(style: $0)
            })
            .disposed(by: disposeBag)

        // 화면을 닫음
        output
            .dismissViewController
            .drive(onNext: { [weak self] in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)

        // pull to refresh 로딩 및 해제
        output
            .isFetching
            .drive(refreshControl.rx.isRefreshing)
            .disposed(by: disposeBag)
    }
}

// MARK: - DataSource
extension SubscriptionUserViewController {
    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, SponsorModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, SponsorModel>>(
            // cell 설정
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: SubscriptionUserTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }
}

// MARK: - Private Method
extension SubscriptionUserViewController {
    // emptyView를 embed
    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = visibleHeight
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }
}
