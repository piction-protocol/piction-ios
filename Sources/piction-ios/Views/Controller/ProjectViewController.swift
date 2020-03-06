//
//  ProjectViewController.swift
//  PictionSDK
//
//  Created by jhseo on 24/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import UIScrollView_InfiniteScroll
import GSKStretchyHeaderView
import PictionSDK

enum ManageMenu {
    case project
    case series
    case membership
}

// MARK: - UIViewController
final class ProjectViewController: UIViewController {
    var disposeBag = DisposeBag()

    private var contentOffset: CGPoint?

    @IBOutlet weak var shareBarButton: UIBarButtonItem!
    @IBOutlet weak var infoBarButton: UIBarButtonItem!
    @IBOutlet weak var emptyView: UIView!

    private var stretchyHeader: ProjectHeaderView?
    private var projectDetailView: ProjectDetailViewController?

    private let changeMenu = BehaviorSubject<Int>(value: 0) // 메뉴 변경 시
    private let deletePost = PublishSubject<Int>() // swipe로 post 삭제 시 (에디터 기능 지원 안함)
    private let deleteSeries = PublishSubject<Int>() // swipe로 post 삭제 시 (에디터 기능 지원 안함)
    private let updateSeries = PublishSubject<(String, SeriesModel)>() // swipe로 시리즈 수정 시 (에디터 기능 지원 안함)
    private let manageMenu = PublishSubject<ManageMenu>() // 관리 메뉴 눌렀을 때 (에디터 기능 지원 안함)

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            // stretchHeader 생성하고 tableView에 add
            stretchyHeader = ProjectHeaderView.getView()
            stretchyHeader?.delegate = self
            stretchyHeader?.isHidden = true
            if let stretchyHeader = stretchyHeader {
                stretchyHeader.stretchDelegate = self
                tableView.addSubview(stretchyHeader)
            }
        }
    }

    // tableView의 contentSize 확인
    override var preferredContentSize: CGSize {
        get {
            guard let tableView = self.tableView else { return .zero }
            tableView.layoutIfNeeded()
            return tableView.contentSize
        }
        set {}
    }

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension ProjectViewController: ViewModelBindable {
    typealias ViewModel = ProjectViewModel

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

        let input = ProjectViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewWillDisappear: rx.viewWillDisappear.asDriver(), // 화면이 사라지기 전에
            viewWillLayoutSubviews: rx.viewWillLayoutSubviews.asDriver(), // subview의 layout이 갱신되기 전에
            traitCollectionDidChange: rx.traitCollectionDidChange.asDriver(), // 일반/다크모드 전환 시
            changeMenu: changeMenu.asDriver(onErrorDriveWith: .empty()), // menu를 변경할 때
            infoBtnDidTap: infoBarButton.rx.tap.asDriver(), // 상단의 info버튼을 눌렀을 때
            shareBtnDidTap: shareBarButton.rx.tap.asDriver(), // 상단의 share버튼을 눌렀을 때
            selectedIndexPath: tableView.rx.itemSelected.asDriver(), // tableView의 row를 눌렀을 때
            deletePost: deletePost.asDriver(onErrorDriveWith: .empty()), // 포스트 삭제 액션을 할때 (에디터 기능 지원안함)
            deleteSeries: deleteSeries.asDriver(onErrorDriveWith: .empty()), // 시리즈 삭제 액션을 할때 (에디터 기능 지원안함)
            updateSeries: updateSeries.asDriver(onErrorDriveWith: .empty()) // 시리즈가 업데이트 될 때 (에디터 기능 지원안함)
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
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

        // subview의 layout이 갱신되기 전에
        output
            .viewWillLayoutSubviews
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

        // 프로젝트 정보를 불러와서 header에 설정
        output
            .projectInfo
            .drive(onNext: { [weak self] in
                self?.stretchyHeader?.configure(with: $0)
            })
            .disposed(by: disposeBag)

        // ProjectDetailViewController를 생성
        output
            .embedProjectDetailViewController
            .drive(onNext: { [weak self] in
                self?.embedProjectDetailViewController(uri: $0)
            })
            .disposed(by: disposeBag)

        // tableView의 row를 선택할 때
        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let uri = self?.viewModel?.uri else { return }
                switch dataSource[indexPath] {
                case .postCardTypeList(let post, _, _),
                     .postListTypeList(let post, _, _):
                    self?.openView(type: .post(uri: uri, postId: post.id ?? 0), openType: .push)
                case .seriesList(let series):
                    self?.openView(type: .seriesPost(uri: uri, seriesId: series.id ?? 0), openType: .push)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)

        // post, series의 정보를 tableView에 출력
        output
            .contentList
            .do(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                let footerHeight = SCREEN_H - self.statusHeight - self.navigationHeight - self.tabbarHeight - (self.stretchyHeader?.menuHeight ?? 0)
                self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: footerHeight))
            })
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // post, series의 정보를 출력한 후 footer size를 조정 (row가 적더라도 끝까지 스크롤 되도록)
        output
            .contentList
            .drive(onNext: { [weak self] list in
                guard let `self` = self else { return }
                let footerHeight = SCREEN_H - self.statusHeight - self.navigationHeight - self.tabbarHeight - (self.stretchyHeader?.menuHeight ?? 0)
                let height = self.preferredContentSize.height - (self.tableView.tableFooterView?.frame.size.height ?? 0)
                if height < footerHeight {
                    self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: footerHeight - height))
                } else {
                    self.tableView.tableFooterView = UIView()
                }

                if let footerView = self.tableView.tableFooterView {
                    footerView.isHidden = list.items.count > 0
                }

                self.tableView.layoutIfNeeded()
                self.tableView.finishInfiniteScroll()

                if let contentOffset = self.contentOffset {
                    self.tableView.contentOffset = contentOffset
                }
            })
            .disposed(by: disposeBag)

        // emptyView 출력
        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] in
                self?.embedCustomEmptyViewController(style: $0)
            })
            .disposed(by: disposeBag)

        // 공유 팝업 출력
        output
            .openSharePopup
            .drive(onNext: { [weak self] projectInfo in
                guard
                    let uri = projectInfo.uri,
                    let title = projectInfo.title
                else { return }

                let stagingPath = AppInfo.isStaging ? "staging." : ""

                let url = "\(title) - Piction\nhttps://\(stagingPath)piction.network/project/\(uri)"

                self?.openSharePopup(url: url)
            })
            .disposed(by: disposeBag)

        // 프로젝트 정보 화면으로 push
        output
            .openProjectInfoViewController
            .map { .projectInfo(uri: $0) }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
            .disposed(by: disposeBag)

        // 로딩 뷰
        output
            .activityIndicator
            .loadingActivity()
            .disposed(by: disposeBag)

        // 토스트 메시지 출력
        output
            .toastMessage
            .showToast()
            .disposed(by: disposeBag)
    }
}

// MARK: - GSKStretchyHeaderViewStretchDelegate
extension ProjectViewController: GSKStretchyHeaderViewStretchDelegate {
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

// MARK: - ProjectHeaderViewDelegate
extension ProjectViewController: ProjectHeaderViewDelegate {
    // 메뉴의 post 버튼 눌렀을 때
    func postBtnDidTap() {
        // 버튼 변경
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.stretchyHeader?.controlMenuButton(menu: 0)
            self.changeMenu.onNext(0)
        }
        let menuTopPosition = self.statusHeight + self.navigationHeight + (self.stretchyHeader?.menuHeight ?? 0)

        // 현재 contentOffset 유지
        if tableView.contentOffset.y >= -menuTopPosition {
            contentOffset = CGPoint(x: 0, y: -menuTopPosition)
        } else {
            contentOffset = tableView.contentOffset
        }
    }

    // 메뉴의 series 버튼 눌렀을 때
    func seriesBtnDidTap() {
        // 버튼 변경
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.stretchyHeader?.controlMenuButton(menu: 1)
            self.changeMenu.onNext(1)
        }
        let menuTopPosition = self.statusHeight + self.navigationHeight + (self.stretchyHeader?.menuHeight ?? 0)

        // 현재 contentOffset 유지
        if tableView.contentOffset.y >= -menuTopPosition {
            contentOffset = CGPoint(x: 0, y: -menuTopPosition)
        } else {
            contentOffset = tableView.contentOffset
        }
    }
}

// MARK: - ProjectDetailViewDelegate
extension ProjectViewController: ProjectDetailViewDelegate {
    // projectDetail에서 layout변경이 필요할 때
    func layoutIfNeeded() {
        stretchyHeader?.setMaximumContentHeight(detailHeight: projectDetailView?.view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height ?? 0)
        stretchyHeader?.isHidden = false
    }
}

// MARK: - UITableViewDelegate
extension ProjectViewController: UITableViewDelegate {
    // cell을 swipe하여 수정, 삭제 액션을 추가 (에디터 기능 지원 안함)
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let section = self.viewModel?.sections[indexPath.row] else {
            return UISwipeActionsConfiguration()
        }
        guard let uri = self.viewModel?.uri else {
            return UISwipeActionsConfiguration()
        }

        // 수정
        let editAction = UIContextualAction(style: .normal, title: LocalizationKey.edit.localized(), handler: { [weak self] (action, view, completionHandler) in

            switch section {
            case .postCardTypeList(let post, _, _),
                 .postListTypeList(let post, _, _):
                self?.openView(type: .createPost(uri: uri, postId: post.id ?? 0), openType: .push)
                completionHandler(true)
            case .seriesList(let series):
                self?.openUpdateSeriesPopup(series: series)
                completionHandler(true)
            default:
                completionHandler(false)
            }
        })

        // 삭제
        let deleteAction = UIContextualAction(style: .destructive, title: LocalizationKey.delete.localized(), handler: { [weak self] (action, view, completionHandler) in

            switch section {
            case .postCardTypeList(let post, _, _),
                 .postListTypeList(let post, _, _):
                self?.openDeletePostPopup(postId: post.id ?? 0)
                completionHandler(true)
            case .seriesList(let series):
                self?.openDeleteSeriesPopup(seriesId: series.id ?? 0)
                completionHandler(true)
            default:
                completionHandler(false)
            }
        })

        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }
}

// MARK: - DataSource
extension ProjectViewController {
    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionType<ContentsSection>> {
        return RxTableViewSectionedReloadDataSource<SectionType<ContentsSection>>(
            // cell 설정
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .postCardTypeList(let post, let subscriptionInfo, let isWriter):
                    let cell: ProjectPostCardTypeListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(post: post, subscriptionInfo: subscriptionInfo, isWriter: isWriter)
                    return cell
                case .postListTypeList(let post, let subscriptionInfo, let isWriter):
                    let cell: ProjectPostListTypeListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(post: post, subscriptionInfo: subscriptionInfo, isWriter: isWriter)
                    return cell
                case .seriesList(let series):
                    let cell: ProjectSeriesListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: series)
                    return cell
                default:
                    let cell = UITableViewCell()
                    return cell
                }
            },
            // swipe 액션 사용 (에디터 기능 지원 안함)
            canEditRowAtIndexPath: { [weak self] (_, _) in
                return (self?.viewModel?.isWriter ?? false && FEATURE_EDITOR)
            })
    }
}

// MARK: - Private Method
extension ProjectViewController {
    private func embedProjectDetailViewController(uri: String) {
        let projectDetailView = ProjectDetailViewController.make(uri: uri)
        projectDetailView.delegate = self
        self.projectDetailView = projectDetailView
        if let projectDetailContainerView = stretchyHeader?.projectDetailView {
            self.embed(projectDetailView, to: projectDetailContainerView)
        }
    }

    // emptyView를 embed
    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        let vc = CustomEmptyViewController.make(style: style)
        if let footerView = self.tableView.tableFooterView {
            self.embed(vc, to: footerView)
        }
    }

    // post를 swipe해서 삭제 시 팝업 (에디터 기능 지원 안함)
    private func openDeletePostPopup(postId: Int) {
        let alertController = UIAlertController(title: nil, message: LocalizationKey.popup_title_delete_post.localized(), preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: LocalizationKey.cancel.localized(), style: .cancel)
        let confirmButton = UIAlertAction(title: LocalizationKey.confirm.localized(), style: .default) { [weak self] _ in
            self?.deletePost.onNext(postId)
        }

        alertController.addAction(confirmButton)
        alertController.addAction(cancelButton)

        self.present(alertController, animated: true, completion: nil)
    }

    // series를 swipe해서 삭제 시 팝업 (에디터 기능 지원 안함)
    private func openDeleteSeriesPopup(seriesId: Int) {
        let alertController = UIAlertController(
        title: LocalizationKey.str_delete_series.localized(),
        message: nil,
        preferredStyle: UIAlertController.Style.alert)

        let deleteAction = UIAlertAction(
            title: LocalizationKey.delete.localized(),
            style: UIAlertAction.Style.destructive,
            handler: { [weak self] action in
                self?.deleteSeries.onNext(seriesId)
            })

        let cancelAction = UIAlertAction(
            title: LocalizationKey.cancel.localized(),
            style:UIAlertAction.Style.cancel,
            handler:{ action in
            })

        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    // series를 swipe해서 수정 시 팝업 (에디터 기능 지원 안함)
    private func openUpdateSeriesPopup(series: SeriesModel) {
        let alertController = UIAlertController(
            title: LocalizationKey.str_modify_series.localized(),
            message: nil,
            preferredStyle: UIAlertController.Style.alert)

        alertController.addTextField(configurationHandler: { textField in
            textField.clearButtonMode = UITextField.ViewMode.always
            textField.text = series.name ?? ""
        })

        let insertAction = UIAlertAction(
            title: LocalizationKey.str_modify.localized(),
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                guard let textFields = alertController.textFields else {
                    return
                }
                self?.updateSeries.onNext((textFields[0].text ?? "", series))
            })

        let cancelAction = UIAlertAction(
            title: LocalizationKey.cancel.localized(),
            style: UIAlertAction.Style.cancel,
            handler: { action in
            })

        alertController.addAction(insertAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    // 공유 팝업
    private func openSharePopup(url: String) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: [])

        activityViewController.excludedActivityTypes = [
            UIActivity.ActivityType.print,
            UIActivity.ActivityType.assignToContact,
            UIActivity.ActivityType.saveToCameraRoll,
            UIActivity.ActivityType.addToReadingList,
            UIActivity.ActivityType.postToFlickr,
            UIActivity.ActivityType.postToVimeo,
            UIActivity.ActivityType.openInIBooks
        ]

        if let topController = UIApplication.topViewController() {
            if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad {
                activityViewController.modalPresentationStyle = .popover
                if let popover = activityViewController.popoverPresentationController {
                    popover.permittedArrowDirections = .up
                    popover.sourceView = topController.view
                    popover.sourceRect = CGRect(x: SCREEN_W, y: 64, width: 0, height: 0)
                }
            }
            topController.present(activityViewController, animated: true, completion: nil)
        }
    }
}
