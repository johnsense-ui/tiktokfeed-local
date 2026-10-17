//
//  VideoCustomCell.swift
//  TikTok Video Feed Swift
//
//  Created by Cedan Misquith on 19/10/22.
//
//  改：右侧加了点赞数（数据来自本地视频库的 digg 字段）
//

import UIKit
import AVFoundation

class VideoCustomCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var bottomGradientImageView: UIImageView!

    var playerController: VideoPlayerController?
    var videoLayer: AVPlayerLayer = AVPlayerLayer()

    private let likeIcon = UIImageView()
    private let likeLabel = UILabel()

    var videoURL: String? {
        didSet {
            if let videoURL = videoURL {
                VideoPlayerController.sharedVideoPlayer.setupVideoFor(url: videoURL)
            }
            videoLayer.isHidden = videoURL == nil
        }
    }

    override func awakeFromNib() {
        let bottomGradient = Utilities.shared.createGradient(color1: UIColor.black.withAlphaComponent(0.0),
                                                            color2: UIColor.black.withAlphaComponent(0.7),
                                                            frame: bottomGradientImageView.bounds)
        bottomGradientImageView.contentMode = .scaleAspectFill
        bottomGradientImageView.image = bottomGradient
        self.contentView.backgroundColor = .black
        videoLayer.backgroundColor = UIColor.clear.cgColor
        videoLayer.videoGravity = AVLayerVideoGravity.resize
        thumbnailImageView.layer.addSublayer(videoLayer)
        selectionStyle = .none

        setupActionColumn()
    }

    private func setupActionColumn() {
        let stack = UIStackView(arrangedSubviews: [likeIcon, likeLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        likeIcon.image = UIImage(systemName: "heart.fill",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold))
        likeIcon.tintColor = UIColor(red: 0.996, green: 0.173, blue: 0.333, alpha: 1)
        likeIcon.contentMode = .scaleAspectFit

        likeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        likeLabel.textColor = .white
        likeLabel.textAlignment = .center
        likeLabel.text = "0"

        NSLayoutConstraint.activate([
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -110),
            stack.widthAnchor.constraint(equalToConstant: 56),
        ])
    }

    override func prepareForReuse() {
        thumbnailImageView.imageURL = nil
        super.prepareForReuse()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoLayer.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height)
    }

    func configureCell(data: VideoObject) {
        self.thumbnailImageView.imageURL = data.thumbnailURL
        self.videoURL = data.videoURL
        self.titleLabel.text = data.title
        self.descriptionLabel.text = data.videoDescription
        self.likeLabel.text = NumberText.short(data.likeCount)
    }
}

extension VideoCustomCell: PlayVideoLayerContainer {
    func visibleVideoHeight() -> CGFloat {
        let videoFrameInParentSuperView: CGRect? = self.superview?.superview?.convert(
            thumbnailImageView.frame,
            from: thumbnailImageView)
        guard let videoFrame = videoFrameInParentSuperView,
              let superViewFrame = superview?.frame else {
            return 0
        }
        let visibleVideoFrame = videoFrame.intersection(superViewFrame)
        return visibleVideoFrame.size.height
    }
}

enum NumberText {
    static func short(_ n: Int) -> String {
        switch n {
        case ..<10_000:
            return "\(n)"
        case 10_000..<100_000_000:
            return String(format: "%.1fw", Double(n) / 10_000)
        default:
            return String(format: "%.1f亿", Double(n) / 100_000_000)
        }
    }
}
