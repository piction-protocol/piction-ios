//
//  SeriesPostViewController.swift
//  PictionSDK
//
//  Created by jhseo on 02/09/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import GSKStretchyHeaderView
import PictionSDK

// MARK: - UIViewController
final class SeriesPostViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            // stretchHeader 생성하고 tableView에 add
            stretchyHeader = SeriesPostHeaderView.getView()
            if let stretchyHeader = stretchyHeader {
                stretchyHeader.stretchDelegate = self
                tableView.addSubview(stretchyHeader)
            }
        }
    }

    private var stretchyHeader: SeriesPostHeaderView?

    @IBOutlet weak var sortImage: UIImageView!
    @IBOutlet weak var sortButton: UIButton!
    @IBOutlet weak var emptyView: UIView!

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension SeriesPostViewController: ViewModelBindable {
    typealias ViewModel = SeriesPostViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        // infiniteScroll이 동작할 때
        tableView.addInfiniteScroll { [weak self] _ in
            self?.viewModel?.loadNextTrigger.onNext(())
        }
        // infiniteScroll이 동작하는 조건
        tableView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = SeriesPostViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewWillDisappear: rx.viewWillDisappear.asDriver(), // 화면이 사라지기 전에
            viewDidLayoutSubviews: rx.viewDidLayoutSubviews.asDriver(), // subview의 layout이 갱신될 때
            traitCollectionDidChange: rx.traitCollectionDidChange.asDriver(), // 일반/다크모드 전환 시
            selectedIndexPath: tableView.rx.itemSelected.asDriver(), // tableView의 row를 눌렀을 때
            sortBtnDidTap: sortButton.rx.tap.asDriver() // 정렬 버튼 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: true, shadow: false)
                self?.navigationController?.navigationBar.barStyle = .black
                self?.navigationController?.navigationBar.tintColor = .white
                self?.tableView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // 화면이 사라지기 전에 navigationBar를 기본값으로 변경
        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                self?.navigationController?.navigationBar.barStyle = .default
                self?.navigationController?.navigationBar.tintColor = UIView().tintColor
            })
            .disposed(by: disposeBag)

        // Pad 가로/세로모드 전환 시 Header size
        output
            .viewDidLayoutSubviews
            .drive(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.stretchyHeader?.frame.size.width = self.view.frame.size.width
            })
            .disposed(by: disposeBag)

        // 일반/다크모드 전환 시 Infinite scroll 색 변경
        output
            .traitCollectionDidChange
            .drive(onNext: { [weak self] in
                self?.tableView.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        // 시리즈 정보를 불러와서 header에 설정
        output
            .seriesInfo
            .drive(onNext: { [weak self] in
                self?.stretchyHeader?.configureSeriesInfo(with: $0)
            })
            .disposed(by: disposeBag)

        // 정렬 버튼 눌렀을 때 정렬 이미지 변경
        output
            .isDescending
            .map { $0 ? #imageLiteral(resourceName: "btnSortDown") : #imageLiteral(resourceName: "btnSortUp") }
            .drive(sortImage.rx.image)
            .disposed(by: disposeBag)

        // series post 목록의 데이터를 tableView에 출력
        output
            .seriesPostList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // series post 목록의 테이터를 출력 후 infiniteScroll 로딩 해제
        output
            .seriesPostList
            .drive(onNext: { [weak self] _ in
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

        // tableView의 row를 선택할 때
        output
            .selectedIndexPath
            .drive(onNext: { [weak self] (uri, indexPath) in
                switch dataSource[indexPath] {
                case .seriesPostList(let post, _, _):
                    guard let postId = post.id else { return }
                    self?.openView(type: .post(uri: uri, postId: postId), openType: .push)
                default:
                    return
                }
            })
            .disposed(by: disposeBag)

        // 네트워크 오류 시 에러 팝업 출력
        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                self?.tableView.finishInfiniteScroll() // infiniteScroll 로딩 중이면 로딩 해제
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

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)
    }
}

// MARK: - GSKStretchyHeaderViewStretchDelegate
extension SeriesPostViewController: GSKStretchyHeaderViewStretchDelegate {
    // stretchHeader의 크기가 변경 될 때
    func stretchyHeaderView(_ headerView: GSKStretchyHeaderView, didChangeStretchFactor stretchFactor: CGFloat) {
        stretchyHeader?.maskImage.isHidden = false
        if stretchFactor > 0.1 {
            stretchyHeader?.maskImage.blurRadius = 0
        } else {
            stretchyHeader?.maskImage.blurRadius = (1 - min(1, stretchFactor) - 0.9) * 50
        }
    }
}

// MARK: - DataSource
extension SeriesPostViewController {
    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionType<ContentsSection>> {
        return RxTableViewSectionedReloadDataSource<SectionType<ContentsSection>>(
            // cell 설정
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .seriesPostList(let post, let subscriptionInfo, let number):
                    let cell: SeriesPostListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: post, subscriptionInfo: subscriptionInfo, number: number)
                    return cell
                default:
                    let cell = UITableViewCell()
                    return cell
                }
            },
            // swipe 액션 사용 (에디터 기능 지원 안함)
            canEditRowAtIndexPath: { [weak self] (_, _) in
                return self?.viewModel?.isWriter ?? false
            })
    }
}

// MARK: - Private Method
extension SeriesPostViewController {
    // emptyView를 embed
    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = 350
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }
}
