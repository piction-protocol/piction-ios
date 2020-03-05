//
//  CategoryListViewController.swift
//  piction-ios
//
//  Created by jhseo on 2020/01/09.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

// MARK: - CategoryListViewDelegate
protocol CategoryListViewDelegate: class {
    func loadComplete()
}

// MARK: - UIViewController
final class CategoryListViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var collectionView: UICollectionView!

    weak var delegate: CategoryListViewDelegate?

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension CategoryListViewController: ViewModelBindable {
    typealias ViewModel = CategoryListViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        let input = CategoryListViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            viewWillLayoutSubviews: rx.viewWillLayoutSubviews.asDriver(), // subview의 layout이 갱신되기 전에
            selectedIndexPath: collectionView.rx.itemSelected.asDriver() // collectionView의 item을 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // subview의 layout이 갱신되기 전에
        output
            .viewWillLayoutSubviews
            .drive(onNext: { [weak self] in
                self?.changeLayoutSubviews()
            })
            .disposed(by: disposeBag)

        // 카테고리 목록을 collectionView에 출력
        output
            .categoryList
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        // 카테고리 목록을 출력 한 후 delegate의 loadComplete를 호출
        output
            .categoryList
            .drive(onNext: { [weak self] _ in
                self?.collectionView.layoutIfNeeded()
                self?.delegate?.loadComplete()
            })
            .disposed(by: disposeBag)

        // collectionView의 item을 선택하면 categorizedProject로 push
        output
            .selectedIndexPath
            .map { dataSource[$0].id }
            .flatMap(Driver.from)
            .map { .categorizedProject(id: $0) } // categorizedProject 화면으로 push
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
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
    }
}

// MARK: - DataSource
extension CategoryListViewController {
    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, CategoryModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, CategoryModel>>(
            // cell 설정
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: CategoryListCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                cell.layoutIfNeeded()
                return cell
            })
    }
}

// MARK: - Private Method
extension CategoryListViewController {
    // Pad에서 가로/세로모드 변경 시 cell size 변경
    private func changeLayoutSubviews() {
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let cellCount: CGFloat = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad && view.frame.size.width == UIScreen.main.bounds.size.width ? 4 : 2
            let width = (view.frame.size.width - 40 - (cellCount - 1) * 7) / cellCount
            let height = width / 2
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
        }
    }
}
