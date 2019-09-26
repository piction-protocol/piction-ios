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

final class PostViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var subscriptionView: UIView!
    @IBOutlet weak var subscriptionButton: UIButton!
    @IBOutlet weak var postWebView: WKWebView! {
        didSet {
            postWebView.navigationDelegate = self
            postWebView.scrollView.delegate = self
            postWebView.isOpaque = false
        }
    }
    @IBOutlet weak var prevPostButton: UIButton!
    @IBOutlet weak var nextPostButton: UIButton!
    @IBOutlet weak var shareBarButton: UIBarButtonItem!

    var headerViewController: PostHeaderViewController?
    var footerViewController: PostFooterViewController?

    private func embedPostHeaderViewController(postItem: PostModel, userInfo: UserModel) {
        for subview in postWebView.scrollView.subviews {
            if subview.tag == 1000 || subview.tag == 1001 {
                subview.removeFromSuperview()
            }
        }
        headerViewController = PostHeaderViewController.make(postItem: postItem, userInfo: userInfo)
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_W, height: 220))
        containerView.tag = 1000
        embed(headerViewController!, to: containerView)
        self.postWebView.scrollView.addSubview(containerView)
    }

    private func embedPostFooterViewController(height: CGFloat) {
        let posY = height - 278
        let containerView = UIView(frame: CGRect(x: 0, y: posY, width: SCREEN_W, height: 278))
        containerView.tag = 1001
        embed(footerViewController!, to: containerView)
        self.postWebView.scrollView.addSubview(containerView)
    }

    private func makePostFooterViewController(uri: String, postItem: PostModel) {
        footerViewController = PostFooterViewController.make(uri: uri, postItem: postItem)
    }

    private func openSignInViewController() {
        let vc = SignInViewController.make()
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .swipePresent)
        }
    }

    func cacheWebview() {
        if postWebView != nil {
            postWebView.stopLoading()
            postWebView.loadHTMLString("about:blank", baseURL: nil)
        }

        URLCache.shared.removeAllCachedResponses()
        URLCache.shared.diskCapacity = 0
        URLCache.shared.memoryCapacity = 0
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tabBarController?.tabBar.isHidden = true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if #available(iOS 13.0, *) {
            if previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) ?? false {

                setWebviewColor()
            }
        }
    }

    @available(iOS 13.0, *)
    private func setWebviewColor() {
        let fontColor = UIColor(named: "PictionDarkGray")?.hexString ?? "#000000"
        postWebView.evaluateJavaScript("document.getElementsByTagName('body')[0].style.color =\"\(fontColor)\"")
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
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            prevPostBtnDidTap: prevPostButton.rx.tap.asDriver().throttle(1, latest: true),
            nextPostBtnDidTap: nextPostButton.rx.tap.asDriver().throttle(1, latest: true),
            subscriptionBtnDidTap: subscriptionButton.rx.tap.asDriver(),
            shareBarBtnDidTap: shareBarButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self?.tabBarController?.tabBar.isHidden = true
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] in
                self?.tabBarController?.tabBar.isHidden = false
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
                        return ((postItem.id ?? 0) != 0 ? UIColor(named: "PictionDarkGray") ?? UIColor(r: 51, g: 51, b: 51) : UIColor(r: 151, g: 151, b: 151))
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
                        return ((postItem.id ?? 0) != 0 ? UIColor(named: "PictionDarkGray") ?? UIColor(r: 51, g: 51, b: 51) : UIColor(r: 151, g: 151, b: 151))
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
                let headerView = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_W, height: 100))
                headerView.backgroundColor = UIColor.green

                self?.postWebView.loadHTMLString(contentItem, baseURL: nil)
            })
            .disposed(by: disposeBag)

        output
            .reloadPost
            .drive(onNext: { [weak self] _ in
                guard let `self` = self else { return }
                self.subscriptionView.isHidden = true
                self.postWebView.scrollView.isScrollEnabled = true
                self.postWebView.loadHTMLString("", baseURL: nil)
                for subview in self.postWebView.scrollView.subviews {
                    if subview.tag == 1000 || subview.tag == 1001 {
                        subview.removeFromSuperview()
                    }
                }
            })
            .disposed(by: disposeBag)

        output
            .showNeedSubscription
            .drive(onNext: { [weak self] userInfo in
                guard let `self` = self else { return }
                var buttonTitle: String {
                    return userInfo.loginId == nil ? "로그인" : "무료로 구독하기"
                }
                self.subscriptionButton.setTitle(buttonTitle, for: .normal)
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
            .drive(onNext: { [weak self] uri in
                self?.openSignInViewController()
            })
            .disposed(by: disposeBag)

        output
            .sharePost
            .drive(onNext: { url in
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
            })
            .disposed(by: disposeBag)


        output
            .activityIndicator
            .drive(onNext: { [weak self] status in
                if status {
                    self?.view.makeToastActivity(.center)
                } else {
                    self?.view.hideToastActivity()
                }
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
