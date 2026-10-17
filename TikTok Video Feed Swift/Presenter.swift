//
//  Presenter.swift
//  TikTok Video Feed Swift
//
//  Created by Cedan Misquith on 19/10/22.
//
//  改：数据源从写死的 Google 示例视频，换成「本地视频库」/api/videos
//

import Foundation

protocol PresenterProtocol: AnyObject {
    func refresh()
    func didFail(_ message: String)
}

struct VideoObject {
    var videoURL: String
    var thumbnailURL: String
    var title: String
    var videoDescription: String
    var likeCount: Int
    var authorId: String
    var authorName: String

    init(videoURL: String,
         thumbnailURL: String,
         title: String,
         videoDescription: String,
         likeCount: Int = 0,
         authorId: String = "",
         authorName: String = "") {
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.title = title
        self.videoDescription = videoDescription
        self.likeCount = likeCount
        self.authorId = authorId
        self.authorName = authorName
    }
}

/// 服务器地址：存 UserDefaults，App 里改，不用重装
enum AppConfig {
    static let key = "dzc.serverBase"
    static let fallback = "http://172.29.8.196:6688"

    static var base: String {
        get {
            let v = UserDefaults.standard.string(forKey: key) ?? ""
            return v.isEmpty ? fallback : v
        }
        set {
            var t = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            while t.hasSuffix("/") { t.removeLast() }
            UserDefaults.standard.set(t, forKey: key)
        }
    }
}

class Presenter: NSObject {

    private(set) var videos: [VideoObject] = []
    weak var delegate: PresenterProtocol?

    private var offset = 0
    private var total = Int.max
    private var isLoading = false
    private let pageSize = 15
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()

    init(delegate: PresenterProtocol) {
        self.delegate = delegate
    }

    var canLoadMore: Bool { offset < total }

    func reset() {
        videos.removeAll()
        offset = 0
        total = Int.max
        isLoading = false
    }

    func loadMore() {
        guard !isLoading, canLoadMore else { return }

        let base = AppConfig.base
        let urlString = "\(base)/api/videos?limit=\(pageSize)&offset=\(offset)&sort=newest"
        guard let url = URL(string: urlString) else {
            delegate?.didFail("服务器地址无效：\(base)")
            return
        }

        isLoading = true
        session.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.delegate?.didFail("连不上 \(base)\n\(error.localizedDescription)")
                    return
                }
                guard let data = data else {
                    self.delegate?.didFail("服务器没返回数据")
                    return
                }

                do {
                    let resp = try JSONDecoder().decode(FeedResponse.self, from: data)
                    self.total = resp.total
                    self.offset += resp.items.count

                    let mapped = resp.items.map { item -> VideoObject in
                        let caption = (item.caption?.isEmpty == false ? item.caption! : (item.title ?? ""))
                        let author = (item.authorName?.isEmpty == false ? item.authorName! : "未知作者")
                        return VideoObject(
                            videoURL: "\(base)/api/stream/\(item.id)",
                            thumbnailURL: "\(base)/api/poster/\(item.id)",
                            title: "@" + author,
                            videoDescription: caption,
                            likeCount: item.digg ?? 0,
                            authorId: item.authorId ?? "",
                            authorName: author
                        )
                    }
                    self.videos.append(contentsOf: mapped)
                    self.delegate?.refresh()
                } catch {
                    self.delegate?.didFail("数据格式不对：\(error.localizedDescription)")
                }
            }
        }.resume()
    }
}

// MARK: - 服务端结构

private struct FeedResponse: Decodable {
    let total: Int
    let items: [FeedItem]
}

private struct FeedItem: Decodable {
    let id: Int
    let title: String?
    let caption: String?
    let authorName: String?
    let authorId: String?
    let digg: Int?
}
