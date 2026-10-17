//
//  ViewController.swift
//  TikTok Video Feed Swift
//
//  Created by Cedan Misquith on 19/10/22.
//
//  改：数据来自本地视频库；加了齿轮改地址、连不上时的错误提示、翻到底自动续页
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var topGradientImageView: UIImageView!

    var presenter: Presenter!

    private let settingsButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var errorShown = false

    override func viewDidLoad() {
        super.viewDidLoad()
        presenter = Presenter(delegate: self)
        configureGradients()
        configureTableView()
        configureOverlays()
        presenter.loadMore()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        VideoPlayerController.sharedVideoPlayer.pausePlayeVideosFor(tableView: tableView)
    }

    fileprivate func configureGradients() {
        let topGradient = Utilities.shared.createGradient(color1: UIColor.black.withAlphaComponent(0.7),
                                                         color2: UIColor.black.withAlphaComponent(0.0),
                                                         frame: topGradientImageView.bounds)
        topGradientImageView.contentMode = .scaleAspectFill
        topGradientImageView.image = topGradient
    }

    fileprivate func configureTableView() {
        tableView.isPagingEnabled = true
        tableView.bounces = false
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.backgroundColor = .black
        tableView.register(UINib(nibName: "VideoCustomCell", bundle: nil),
                           forCellReuseIdentifier: "VideoCustomCell")
    }

    fileprivate func configureOverlays() {
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.tintColor = .white
        let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        settingsButton.setImage(UIImage(systemName: "gearshape.fill", withConfiguration: cfg), for: .normal)
        settingsButton.addTarget(self, action: #selector(changeServer), for: .touchUpInside)
        view.addSubview(settingsButton)

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.font = .systemFont(ofSize: 14)
        errorLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        errorLabel.isHidden = true
        view.addSubview(errorLabel)

        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("重试", for: .normal)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        retryButton.addTarget(self, action: #selector(retry), for: .touchUpInside)
        retryButton.isHidden = true
        view.addSubview(retryButton)

        NSLayoutConstraint.activate([
            settingsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            settingsButton.widthAnchor.constraint(equalToConstant: 36),
            settingsButton.heightAnchor.constraint(equalToConstant: 36),

            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 16),
        ])
    }

    @objc private func retry() {
        errorLabel.isHidden = true
        retryButton.isHidden = true
        presenter.loadMore()
    }

    @objc private func changeServer() {
        let alert = UIAlertController(title: "视频库地址",
                                      message: "例如 http://192.168.1.10:6688",
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = AppConfig.base
            tf.placeholder = AppConfig.fallback
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
            tf.keyboardType = .URL
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存并重连", style: .default) { [weak self, weak alert] _ in
            guard let self = self else { return }
            var value = (alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { value = AppConfig.fallback }
            if !value.lowercased().hasPrefix("http://") && !value.lowercased().hasPrefix("https://") {
                value = "http://" + value
            }
            AppConfig.base = value
            self.presenter.reset()
            self.tableView.reloadData()
            self.errorLabel.isHidden = true
            self.retryButton.isHidden = true
            self.presenter.loadMore()
        })
        present(alert, animated: true)
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presenter.videos.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.view.frame.height
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "VideoCustomCell") as? VideoCustomCell else {
            return UITableViewCell()
        }
        cell.configureCell(data: presenter.videos[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // 翻到倒数第三条就续页
        if indexPath.row >= presenter.videos.count - 3 {
            presenter.loadMore()
        }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let videoCell = cell as? PlayVideoLayerContainer {
            if videoCell.videoURL != nil {
                VideoPlayerController.sharedVideoPlayer.removeLayerFor(cell: videoCell)
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        VideoPlayerController.sharedVideoPlayer.pausePlayeVideosFor(tableView: tableView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            VideoPlayerController.sharedVideoPlayer.pausePlayeVideosFor(tableView: tableView)
        }
    }
}

extension ViewController: PresenterProtocol {

    func refresh() {
        errorLabel.isHidden = true
        retryButton.isHidden = true
        tableView.reloadData()
    }

    func didFail(_ message: String) {
        guard presenter.videos.isEmpty else { return }   // 已经有内容就别打断播放
        errorLabel.text = message
        errorLabel.isHidden = false
        retryButton.isHidden = false
    }
}
