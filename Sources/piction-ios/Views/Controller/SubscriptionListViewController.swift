//
//  SubscriptionListViewController.swift
//  PictionView
//
//  Created by jhseo on 25/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import UIScrollView_InfiniteScroll
import PictionSDK

// MARK: - UIViewController
final class SubscriptionListViewController: UIViewController {
    var disposeBag = DisposeBag()

    var emptyView = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_W, height: 0))
    private var refreshControl = UIRefreshControl()

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            // 로그인이 되어 있지 않으면 scroll되지 않도록 함
            collectionView.isScrollEnabled = false
            // pull to refresh 추가
            collectionView.refreshControl = refreshControl
            // collectionView footer 추가
            collectionView.registerReusableView(ReuseCollectionReusableView.self, kind: .footer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // emptyView의 height를 보여지는 화면의 height로 설정
        emptyView.frame.size.height = visibleHeight
    }

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension SubscriptionListViewController: ViewModelBindable {
    typealias ViewModel = SubscriptionListViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        // infiniteScroll이 동작할 때
        collectionView.addInfiniteScroll { [weak self] tableView in
            self?.viewModel?.loadNextTrigger.onNext(())
        }
        // infiniteScroll이 동작하는 조건
        collectionView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = SubscriptionListViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewWillLayoutSubviews: rx.viewWillLayoutSubviews.asDriver(), // subview의 layout이 갱신되기 전에
            traitCollectionDidChange: rx.traitCollectionDidChange.asDriver(), // 일반/다크모드 전환 시
            selectedIndexPath: collectionView.rx.itemSelected.asDriver(), // collectionView의 item을 눌렀을 때
            refreshControlDidRefresh: refreshControl.rx.controlEvent(.valueChanged).asDriver() // pull to refresh 액션 시
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar, infiniteScroll 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: false)
                self?.collectionView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // subview의 layout이 갱신되기 전에
        output
            .viewWillLayoutSubviews
            .drive(onNext: { [weak self] in
                self?.changeLayoutSubviews()
            })
            .disposed(by: disposeBag)

        // 일반/다크모드 전환 시 Infinite scroll 색 변경
        output
            .traitCollectionDidChange
            .drive(onNext: { [weak self] in
                self?.collectionView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // 구독중인 project의 데이터를 collectionView에 출력
        output
            .subscriptionList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
            })
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // 구독중인 project의 테이터를 출력 후 infiniteScroll 로딩 해제
        output
            .subscriptionList
            .drive(onNext: { [weak self] subscriptions in
                self?.collectionView.isScrollEnabled = true
                self?.collectionView.layoutIfNeeded()
                self?.collectionView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        // emptyView 출력
        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                self.collectionView.isScrollEnabled = style != .defaultLogin
                Toast.loadingActivity(false)
                self.collectionView.contentOffset = CGPoint(x: 0, y: -self.statusHeight-self.largeTitleNavigationHeight)
                self.embedCustomEmptyViewController(style: style)
            })
            .disposed(by: disposeBag)

        // collectionView의 item을 선택하면 project 화면으로 push
        output
            .selectedIndexPath
            .map { dataSource[$0].uri }
            .flatMap(Driver.from)
            .map { .project(uri: $0) } // project 화면으로 push
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
            .disposed(by: disposeBag)

        // pull to refresh 로딩 및 해제
        output
            .isFetching
            .drive(refreshControl.rx.isRefreshing)
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        // 네트워크 오류 시 에러 팝업 출력
        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                self?.collectionView.finishInfiniteScroll() // infiniteScroll 로딩 중이면 로딩 해제
                Toast.loadingActivity(false) // 로딩 뷰 로딩 중이면 로딩 해제
                self?.showPopup(
                    title: LocalizationKey.popup_title_network_error.localized(),
                    message: LocalizationKey.msg_api_internal_server_error.localized(),
                    action: [LocalizationKey.retry.localized(), LocalizationKey.cancel.localized()]) { [weak self] in
                        // 다시 로딩
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)

        // session이 변경되면 모든 뷰를 pop (root로 이동)
        output
            .refreshSession
            .drive(onNext: { [weak self] in
                self?.navigationController?.popToRootViewController(animated: false)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension SubscriptionListViewController: UICollectionViewDelegateFlowLayout {
    // footer size 설정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        if self.emptyView.subviews.count > 0 {
            return CGSize(width: SCREEN_W, height: emptyView.frame.size.height)
        } else {
            return CGSize.zero
        }
    }

    // 각 section의 padding 설정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if self.emptyView.subviews.count > 0 {
            return UIEdgeInsets.zero
        } else {
            return UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        }
    }
}

// MARK: - DataSource
extension SubscriptionListViewController {
    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(
            // cell 설정
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: SubscriptionListCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            },
            // header, footer 설정
            configureSupplementaryView: { [weak self] (dataSource, collectionView, kind, indexPath) in
                guard let `self` = self else { return UICollectionReusableView() }
                if (kind == UICollectionView.elementKindSectionFooter) {
                    let reusableView = collectionView.dequeueReusableView(ReuseCollectionReusableView.self, indexPath: indexPath, kind: .footer)

                    // subview를 모두 제거 하고 emptyView를 add
                    _ = reusableView.subviews.map { $0.removeFromSuperview() }
                    reusableView.addSubview(self.emptyView)
                    return reusableView
                }
                return UICollectionReusableView()
            })
    }
}

// MARK: - Private Method
extension SubscriptionListViewController {
    // Pad에서 가로/세로모드 변경 시 cell size 변경 (pad 가로모드에서는 한줄에 4개의 cell을 보여주도록 함)
    private func changeLayoutSubviews() {
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let cellCount: CGFloat = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad && view.frame.size.width == UIScreen.main.bounds.size.width ? 4 : 2
            let width = (view.frame.size.width - 40 - (cellCount - 1) * 7) / cellCount
            let height = width + 44
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
        }
        emptyView.frame.size.width = view.frame.size.width
        emptyView.frame.size.height = visibleHeight
    }

    // emptyView를 embed
    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
        self.collectionView.reloadData()
    }
}
