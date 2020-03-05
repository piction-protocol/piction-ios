//
//  MyProjectViewController.swift
//  PictionView
//
//  Created by jhseo on 12/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

// MARK: - UITableViewController
final class MyProjectViewController: UITableViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var emptyView: UIView!
    @IBOutlet weak var createProjectButton: UIBarButtonItem!

    // swipe 액션 Observable
    private let contextualAction = PublishSubject<IndexPath>()

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension MyProjectViewController: ViewModelBindable {
    typealias ViewModel = MyProjectViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        // UITableViewController의 경우 UITableViewDelegate, UITableViewDataSource가 자동으로 적용되므로 사용하지 않으면 제거
        tableView.dataSource = nil

        let input = MyProjectViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            createProjectBtnDidTap: createProjectButton.rx.tap.asDriver(), // 생성 버튼 눌렀을 때 (에디터 기능 지원안함)
            selectedIndexPath: tableView.rx.itemSelected.asDriver(), // tableView의 row를 눌렀을 때
            contextualAction: contextualAction.asDriver(onErrorDriveWith: .empty()) // tableView의 row를 swipe 할때 (에디터 기능 지원안함)
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)

                // 에디터 기능 지원 안함
                self?.createProjectButton.isEnabled = FEATURE_EDITOR
                self?.createProjectButton.title = FEATURE_EDITOR ? LocalizationKey.create.localized() : ""
            })
            .disposed(by: disposeBag)

        // 프로젝트 리스트를 tableView에 출력
        output
            .projectList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // 프로젝트 생성 또는 수정 화면으로 push (에디터 기능 지원 안함)
        output
            .openCreateProjectViewController
            .drive(onNext: { [weak self] indexPath in
                if let indexPath = indexPath {
                    let uri = dataSource[indexPath].uri ?? ""
                    self?.openView(type: .createProject(uri: uri), openType: .push)
                } else {
                    self?.openView(type: .createProject(uri: ""), openType: .push)
                }
            })
            .disposed(by: disposeBag)

        // tableView의 row를 선택할 때
        output
            .selectedIndexPath
            .map { dataSource[$0] }
            .filter { $0.status != "DEPRECATED" } // deprecated된 프로젝트는 진입하지 않음
            .map { $0.uri }
            .flatMap(Driver.from)
            .map { .project(uri: $0) } // 프로젝트 화면으로 push
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
            .disposed(by: disposeBag)

        // emptyView 출력
        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] in
                self?.embedCustomEmptyViewController(style: $0)
            })
            .disposed(by: disposeBag)

        // 네트워크 오류 시 에러 팝업 출력
        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
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

// MARK: - UITableViewDelegate
extension MyProjectViewController {
    // tableView row의 swipe 액션 (에디터 기능 지원 안함)
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: LocalizationKey.edit.localized(), handler: { [weak self] (action, view, completionHandler) in
            self?.contextualAction.onNext(indexPath)
            completionHandler(true)
        })
        return UISwipeActionsConfiguration(actions: [editAction])
    }
}

// MARK: - DataSource
extension MyProjectViewController {
    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(
            // cell 설정
            configureCell: { (dataSource, tableView, indexPath, model) in
                let cell: MyProjectTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
            },
            // swipe 액션 사용 (에디터 기능 지원 안함)
            canEditRowAtIndexPath: { (_, _) in
                return FEATURE_EDITOR
            })
    }
}

// MARK: - Private Method
extension MyProjectViewController {
    // emptyView를 embed
    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = visibleHeight
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }
}
