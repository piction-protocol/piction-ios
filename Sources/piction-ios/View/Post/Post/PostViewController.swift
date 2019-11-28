//
//  PostViewController.swift
//  PictionView
//
//  Created by jhseo on 01/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import Swinject
import WebKit
import SafariServices
import PictionSDK
import RxGesture

final class PostViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var subscriptionView: UIView!
    @IBOutlet weak var subscriptionDescriptionLabel: UILabel!
    @IBOutlet weak var subscriptionButton: UIButton!
    @IBOutlet weak var postWebView: WKWebView! {
        didSet {
            postWebView.navigationDelegate = self
            postWebView.scrollView.delegate = self
            postWebView.isOpaque = false
            postWebView.scrollView.contentInsetAdjustmentBehavior = .never
        }
    }
    @IBOutlet weak var prevPostButton: UIButton!
    @IBOutlet weak var nextPostButton: UIButton!
    @IBOutlet weak var shareBarButton: UIBarButtonItem!

    private let loadPost = PublishSubject<Int>()

    var headerViewController: PostHeaderViewController?
    var footerViewController: PostFooterViewController?

    private func embedPostHeaderViewController(postItem: PostModel, userInfo: UserModel) {
        if let headerView = headerViewController {
            remove(headerView)
        }
        headerViewController = PostHeaderViewController.make(postItem: postItem, userInfo: userInfo)
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 220))
        containerView.tag = 1000
        embed(headerViewController!, to: containerView)
        self.postWebView.scrollView.addSubview(containerView)
    }

    private func embedPostFooterViewController(height: CGFloat) {
        if let footerView = self.footerViewController {
            remove(footerView)

            let posY = height - 747
            let containerView = UIView(frame: CGRect(x: 0, y: posY, width: view.frame.size.width, height: 747))
            containerView.tag = 1001
            embed(footerView, to: containerView)
            self.postWebView.scrollView.addSubview(containerView)
        }
    }

    private func makePostFooterViewController(uri: String, postItem: PostModel) {
        if let footerView = footerViewController {
            remove(footerView)
        }
        footerViewController = PostFooterViewController.make(uri: uri, postItem: postItem)
        footerViewController?.delegate = self
    }

    private func openSignInViewController() {
        let vc = SignInViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .swipePresent)
        }
    }

    private func openFanPassListViewController(uri: String, postId: Int? = nil) {
        let vc = FanPassListViewController.make(uri: uri, postId: postId)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
        }
    }

    private func removeHeaderFooter() {
        for subview in postWebView.scrollView.subviews {
            if subview.tag == 1000 || subview.tag == 1001 {
                subview.removeFromSuperview()
            }
        }
        if let header = headerViewController {
            remove(header)
        }
        if let footer = footerViewController {
            remove(footer)
        }
    }

    func cacheWebview() {
        if postWebView != nil {
            postWebView.stopLoading()
            postWebView.loadHTMLString("", baseURL: nil)
        }

        URLCache.shared.removeAllCachedResponses()
        URLCache.shared.diskCapacity = 0
        URLCache.shared.memoryCapacity = 0
    }

    func showFullScreen(_ status: Bool = true, animated: Bool = true) {
        let isScrollTop = postWebView.scrollView.contentOffset.y <= -44
        let isScrollBottom = (postWebView.scrollView.contentOffset.y + self.view.frame.size.height) >= self.postWebView.scrollView.contentSize.height
        let fullScreen = (isScrollTop || isScrollBottom) ? false : status
        self.navigationController?.setNavigationBarHidden(fullScreen, animated: animated)
        self.navigationController?.setToolbarHidden(fullScreen, animated: animated)
        self.setNeedsStatusBarAppearanceUpdate()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if #available(iOS 13.0, *) {
            if previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) ?? false {

                setWebviewColor()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let headerView = headerViewController {
            headerView.view.frame.size.width = view.frame.size.width
        }
        if let footerView = footerViewController {
            if !postWebView.isLoading {
                footerView.view.frame.size.width = view.frame.size.width
                postWebView.evaluateJavaScript("document.body.style.marginBottom =\"747px\"", completionHandler: { (complete, error) in
                    self.postWebView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { (height, error) in

                        if self.subscriptionView.isHidden {
                            if let height = height as? CGFloat {
                                self.embedPostFooterViewController(height: height)
                                self.loadComplete()
                            }
                        }
                    })
                })
            }
        }
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    override var prefersStatusBarHidden: Bool {
        return self.navigationController?.isNavigationBarHidden ?? false
    }

    @available(iOS 13.0, *)
    private func setWebviewColor() {
        let fontColor = UIColor.pictionDarkGrayDM.hexString
        postWebView.evaluateJavaScript("document.getElementsByTagName('body')[0].style.color =\"\(fontColor ?? "#333333")\"")
    }

    deinit {
        cacheWebview()
    }
}

extension PostViewController: ViewModelBindable {
    typealias ViewModel = PostViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = PostViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewDidAppear: rx.viewDidAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            loadPost: loadPost.asDriver(onErrorDriveWith: .empty()),
            prevPostBtnDidTap: prevPostButton.rx.tap.asDriver().throttle(1, latest: true),
            nextPostBtnDidTap: nextPostButton.rx.tap.asDriver().throttle(1, latest: true),
            subscriptionBtnDidTap: subscriptionButton.rx.tap.asDriver(),
            shareBarBtnDidTap: shareBarButton.rx.tap.asDriver(),
            contentOffset: postWebView.scrollView.rx.contentOffset.asDriver(),
            willBeginDecelerating: postWebView.scrollView.rx.willBeginDecelerating.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)

                self?.postWebView.scrollView.contentInset = UIEdgeInsets(
                    top: (self?.getCurrentNavigationHeight() ?? 0),
                    left: 0,
                    bottom:  self?.navigationController?.toolbar.bounds.size.height ?? 0,
                    right: 0)
                let uri = self?.viewModel?.uri ?? ""
                let postId = self?.viewModel?.postId ?? 0
                FirebaseManager.screenName("포스트뷰어_\(uri)_\(postId)")
            })
            .disposed(by: disposeBag)

        output
            .viewDidAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.toolbar.isHidden = false
//                self?.navigationController?.setToolbarHidden(false, animated: false)
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                self?.navigationController?.setNavigationBarHidden(false, animated: false)
                self?.navigationController?.toolbar.isHidden = true
                self?.navigationController?.setToolbarHidden(true, animated: false)
            })
            .disposed(by: disposeBag)

        output
            .headerInfo
            .drive(onNext: { [weak self] (postItem, userInfo) in
                self?.embedPostHeaderViewController(postItem: postItem, userInfo: userInfo)
                self?.navigationItem.title = postItem.title
            })
            .disposed(by: disposeBag)

        output
            .footerInfo
            .drive(onNext: { [weak self] (uri, postItem) in
                self?.makePostFooterViewController(uri: uri, postItem: postItem)
            })
            .disposed(by: disposeBag)

        output
            .prevPostIsEnabled
            .drive(onNext: { [weak self] postItem in
                self?.prevPostButton.isEnabled = (postItem.id ?? 0) != 0
                var buttonColor: UIColor {
                    if #available(iOS 13.0, *) {
                        return (postItem.id ?? 0) != 0 ? .pictionDarkGrayDM : UIColor(r: 151, g: 151, b: 151)
                    } else {
                        return (postItem.id ?? 0) != 0 ? UIColor(r: 51, g: 51, b: 51) : UIColor(r: 151, g: 151, b: 151)
                    }
                }
                self?.prevPostButton.setTitleColor(buttonColor, for: .normal)
            })
            .disposed(by: disposeBag)

        output
            .nextPostIsEnabled
            .drive(onNext: { [weak self] postItem in
                self?.nextPostButton.isEnabled = (postItem.id ?? 0) != 0
                var buttonColor: UIColor {
                    if #available(iOS 13.0, *) {
                        return (postItem.id ?? 0) != 0 ? .pictionDarkGrayDM : UIColor(r: 151, g: 151, b: 151)
                    } else {
                        return (postItem.id ?? 0) != 0 ? UIColor(r: 51, g: 51, b: 51) : UIColor(r: 151, g: 151, b: 151)
                    }
                }
                self?.nextPostButton.setTitleColor(buttonColor, for: .normal)
            })
            .disposed(by: disposeBag)

        output
            .showPostContent
            .drive(onNext: { [weak self] contentItem in
                self?.postWebView.loadHTMLString(contentItem, baseURL: nil)
            })
            .disposed(by: disposeBag)

        output
            .reloadPost
            .drive(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.subscriptionView.isHidden = true
                self.postWebView.scrollView.isScrollEnabled = true
                self.removeHeaderFooter()
                self.postWebView.loadHTMLString("", baseURL: nil)
                self.showFullScreen(false)
            })
            .disposed(by: disposeBag)

        output
            .showNeedSubscription
            .drive(onNext: { [weak self] (userInfo, postInfo, _) in
                guard let `self` = self else { return }
                var buttonTitle: String {
                    if (postInfo.fanPass?.level ?? 0) == 0 {
                        return LocalizedStrings.btn_subs_free.localized()
                    }
                    return LocalizedStrings.btn_subs.localized()
                }
                var description: String {
                    return (postInfo.fanPass?.level ?? 0) == 0 ? LocalizedStrings.str_subs_only.localized() : LocalizedStrings.str_subs_only_with_fanpass.localized(with: postInfo.fanPass?.name ?? "")
                }
                self.subscriptionButton.setTitle(buttonTitle, for: .normal)
                self.subscriptionDescriptionLabel.text = description
                self.subscriptionView.isHidden = false
                self.postWebView.scrollView.isScrollEnabled = false

                for subview in self.postWebView.scrollView.subviews {
                    if subview.tag == 1001 {
                        subview.isHidden = true
                    }
                }
            })
            .disposed(by: disposeBag)

        output
            .openSignInViewController
            .drive(onNext: { [weak self] _ in
                self?.openSignInViewController()
            })
            .disposed(by: disposeBag)

        output
            .openFanPassListViewController
            .drive(onNext: { [weak self] (uri, postId) in
                self?.openFanPassListViewController(uri: uri, postId: postId)
            })
            .disposed(by: disposeBag)

        output
            .sharePost
            .drive(onNext: { [weak self] url in
                guard let `self` = self else { return }
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
                            popover.sourceRect = CGRect(x: self.view.frame.size.width, y: 64, width: 0, height: 0)
                        }
                    }
                    topController.present(activityViewController, animated: true, completion: nil)
                }
            })
            .disposed(by: disposeBag)

        output
            .willBeginDecelerating
            .drive(onNext: { [weak self] _ in
                self?.showFullScreen()
            })
            .disposed(by: disposeBag)

        output
            .contentOffset
            .distinctUntilChanged()
            .drive(onNext: { [weak self] offset in
                guard let `self` = self else { return }
                let isScrollTop = offset.y <= -44
                let isScrollBottom = (offset.y + self.view.frame.size.height) >= self.postWebView.scrollView.contentSize.height
                if isScrollTop || isScrollBottom {
                    self.showFullScreen(false)
                }
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { status in
                Toast.loadingActivity(status)
            })
            .disposed(by: disposeBag)

        output
            .showToast
            .drive(onNext: { message in
                Toast.showToast(message)
            })
            .disposed(by: disposeBag)

        output
            .sharePost
            .drive(onNext: { url in

            })
            .disposed(by: disposeBag)

        view.rx.tapGesture(configuration: { gestureRecognizer, delegate in
                gestureRecognizer.delegate = self
                gestureRecognizer.cancelsTouchesInView = false
            })
            .when(.recognized)
            .subscribe(onNext: { [weak self] _ in
                self?.showFullScreen(!(self?.navigationController?.isNavigationBarHidden ?? false))
            })
            .disposed(by: disposeBag)
    }
}

extension PostViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if #available(iOS 13.0, *) {
            setWebviewColor()
        }
        webView.evaluateJavaScript("document.readyState") { (complete, error) in
            if complete != nil {
                webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { [weak self] (height, error) in
                    guard let `self` = self else { return }
                    if self.subscriptionView.isHidden {
                        if let height = height as? CGFloat {
                            self.embedPostFooterViewController(height: height)
                        }
                    }
                })
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated  {
            if let requestUrlString = navigationAction.request.url?.absoluteString {
                guard let url = URL(string: requestUrlString) else {
                    decisionHandler(.allow)
                    return }
                let safariViewController = SFSafariViewController(url: url)
                present(safariViewController, animated: true, completion: nil)

                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }
}

extension PostViewController: UIScrollViewDelegate {
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
}

extension PostViewController: PostFooterViewDelegate {
    func loadComplete() {
        if let footerViewController = self.footerViewController {
            if let contentHeight = footerViewController.tableView?.contentSize.height {
                postWebView.evaluateJavaScript("document.body.style.marginBottom =\"\(contentHeight)px\"")
            }
        }
    }
    func reloadPost(postId: Int) {
        loadPost.onNext(postId)
    }
}

extension PostViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if (touch.view?.isKind(of: UIControl.self) ?? false) {
            return false
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.isKind(of: UITapGestureRecognizer.self) && otherGestureRecognizer.isKind(of: UIPanGestureRecognizer.self) {
            return false
        }
        return true
    }
}
