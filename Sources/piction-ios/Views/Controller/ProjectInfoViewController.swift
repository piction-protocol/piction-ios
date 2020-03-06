//
//  ProjectInfoViewController.swift
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
import PictionSDK

// MARK: - UIViewController
final class ProjectInfoViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var writerLabel: UILabel!
    @IBOutlet weak var loginIdLabel: UILabel!
    @IBOutlet weak var creatorButton: UIButton!
    @IBOutlet weak var synopsisLabel: UILabel!
    @IBOutlet weak var creatorInfoStackView: UIStackView!
    @IBOutlet weak var synopsisStackView: UIStackView!
    @IBOutlet weak var categoryStackView: UIStackView!
    @IBOutlet weak var tagStackView: UIStackView!
    @IBOutlet weak var categoryCollectionView: UICollectionView!
    @IBOutlet weak var tagCollectionView: UICollectionView!

    deinit {
        // 메모리 해제되는지 확인
        print("[deinit] \(String(describing: type(of: self)))")
    }
}

// MARK: - ViewModelBindable
extension ProjectInfoViewController: ViewModelBindable {
    typealias ViewModel = ProjectInfoViewModel

    func bindViewModel(viewModel: ViewModel) {
        let categoryDataSource = categoryConfigureDataSource()
        let tagDataSource = tagConfigureDataSource()

        let input = ProjectInfoViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(), // 화면이 보여지기 전에
            categoryCollectionViewSelectedIndexPath: categoryCollectionView.rx.itemSelected.asDriver(), // categoryCollectionView의 item을 눌렀을 때
            tagCollectionViewSelectedIndexPath: tagCollectionView.rx.itemSelected.asDriver(), // tagCollectionView의 item을 눌렀을 때
            creatorBtnDidTap: creatorButton.rx.tap.asDriver() // Creator를 눌렀을 때
        )

        let output = viewModel.build(input: input)

        // 화면이 보여지기 전에 NavigationBar 설정
        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        // 프로젝트 정보를 불러와서 설정
        output
            .projectInfo
            .drive(onNext: { [weak self] projectInfo in
                if let profileImage = projectInfo.user?.picture {
                    let userPictureWithIC = "\(profileImage)?w=240&h=240&quality=80&output=webp"
                    if let url = URL(string: userPictureWithIC) {
                        self?.thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
                    }
                } else {
                    self?.thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
                }
                self?.writerLabel.text = projectInfo.user?.username
                self?.loginIdLabel.text = "@\(projectInfo.user?.loginId ?? "")"
                self?.synopsisStackView.isHidden = projectInfo.synopsis == ""
                self?.synopsisLabel.text = projectInfo.synopsis ?? ""
                self?.categoryStackView.isHidden = (projectInfo.categories?.isEmpty ?? true) || (projectInfo.status ?? "" == "HIDDEN")
                self?.tagStackView.isHidden = (projectInfo.tags?.isEmpty ?? true) || (projectInfo.status ?? "" == "HIDDEN")
                self?.creatorInfoStackView.isHidden = projectInfo.user == nil
            })
            .disposed(by: disposeBag)

        // 프로젝트 정보를 불러와서 tag 목록을 tagCollectionView에 출력
        output
            .projectInfo
            .drive { $0 }
            .map { [SectionModel(model: "tag", items: $0.tags ?? [])] }
            .bind(to: tagCollectionView.rx.items(dataSource: tagDataSource))
            .disposed(by: disposeBag)

        // 프로젝트 정보를 불러와서 category 목록을 categoryCollectionView에 출력
        output
            .projectInfo
            .drive { $0 }
            .map { [SectionModel(model: "category", items: $0.categories ?? [])] }
            .bind(to: categoryCollectionView.rx.items(dataSource: categoryDataSource))
            .disposed(by: disposeBag)

        // categoryCollectionView의 item을 선택할 때
        output
            .categoryCollectionViewSelectedIndexPath
            .map { categoryDataSource[$0].id }
            .flatMap(Driver.from)
            .map { .categorizedProject(id: $0) } // categorizedProject 화면으로 push
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
            .disposed(by: disposeBag)

        // tagCollectionView의 item을 선택할 때
        output
            .tagCollectionViewSelectedIndexPath
            .map { tagDataSource[$0] }
            .flatMap(Driver.from)
            .map { .taggingProject(tag: $0) } // taggingProject 화면으로 push
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
            })
            .disposed(by: disposeBag)

        // creator profile 화면으로 push
        output
            .openCreatorProfileViewController
            .map { .creatorProfile(loginId: $0) }
            .drive(onNext: { [weak self] in
                self?.openView(type: $0, openType: .push)
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

// MARK: - DataSource
extension ProjectInfoViewController {
    // category data source
    private func categoryConfigureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, CategoryModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, CategoryModel>>(
            // cell 설정
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: ProjectInfoCategoryCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }

    // tag data source
    private func tagConfigureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, String>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, String>>(
            // cell 설정
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: ProjectInfoTagCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        })
    }
}
