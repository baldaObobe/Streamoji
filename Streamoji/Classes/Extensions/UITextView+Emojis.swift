//
//  UITextView+Emojis.swift
//  Streamoji
//
//  Created by Matheus Cardoso on 30/06/20.
//

import Foundation

fileprivate var renderViews: [EmojiSource: UIImageView] = [:]


// MARK: Public
extension UITextView {
    public func configureEmojis(_ emojis: [String: EmojiSource], rendering: EmojiRendering = .highQuality) throws {
        self.applyEmojis(emojis, rendering: rendering)

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.UITextViewTextDidChange,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.applyEmojis(emojis, rendering: rendering)
        }
    }
}

// MARK: Private
extension UITextView {
    private var textContainerView: UIView { subviews[1] }
    
    private var customEmojiViews: [EmojiView] {
        textContainerView.subviews.compactMap { $0 as? EmojiView }
    }
    
    private func applyEmojis(_ emojis: [String: EmojiSource], rendering: EmojiRendering) {
        self.attributedText = attributedText.insertingEmojis(emojis)
        customEmojiViews.forEach { $0.removeFromSuperview() }
        addEmojiImagesIfNeeded(rendering: rendering)
    }
    
    private func addEmojiImagesIfNeeded(rendering: EmojiRendering) {
        attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: [], using: { attributes, crange, _ in
            DispatchQueue.main.async {
                guard
                    let emojiAttachment = attributes[NSAttributedString.Key.attachment] as? NSTextAttachment,
                    let position1 = self.position(from: self.beginningOfDocument, offset: crange.location),
                    let position2 = self.position(from: position1, offset: crange.length),
                    let range = self.textRange(from: position1, to: position2),
                    let emojiData = emojiAttachment.contents,
                    let emoji = try? JSONDecoder().decode(EmojiSource.self, from: emojiData)
                else {
                    return
                }
                
                let rect = self.firstRect(for: range)

                let emojiView = EmojiView(frame: rect)
                emojiView.backgroundColor = self.backgroundColor
                emojiView.isUserInteractionEnabled = false
                
                switch emoji {
                case .character(let character):
                    emojiView.label.text = character
                case .imageUrl(let imageUrl):
                    if renderViews[emoji] == nil, let url = URL(string: imageUrl) {
                        let renderView = UIImageView(frame: rect)
                        renderView.setFromURL(url, rendering: rendering)
                        renderViews[emoji] = renderView
                        self.window?.addSubview(renderView)
                        renderView.alpha = 0
                    }
                
                    if let view = renderViews[emoji] {
                        emojiView.setFromRenderView(view)
                    }
                case .alias:
                    break
                }
                
                self.textContainerView.addSubview(emojiView)
            }
        })
    }
}