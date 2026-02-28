//
//  GrowingTextView.swift
//  Motive
//
//  Aurora Design System - Multi-line text input with dynamic height.
//  Supports Shift+Enter for newlines, Enter for submit, placeholder text,
//  and auto-growing up to a configurable max line count.
//

import AppKit
import SwiftUI

struct GrowingTextView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var font: NSFont = .systemFont(ofSize: 14)
    var textColor: NSColor = .labelColor
    var placeholderColor: NSColor = .placeholderTextColor
    var maxLines: Int = 6
    var isDisabled: Bool = false
    var onSubmit: () -> Void
    var onEscape: (() -> Void)?
    var onTextChange: ((String) -> Void)?
    @Binding var height: CGFloat

    func makeNSView(context: Context) -> GrowingTextContainer {
        let container = GrowingTextContainer()
        let textView = container.textView

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = !isDisabled
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.placeholderString = placeholder
        textView.placeholderColor = placeholderColor
        textView.insertionPointColor = textColor

        let scrollView = container.scrollView
        scrollView.hasVerticalScroller = false
        scrollView.scrollerStyle = .overlay

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        DispatchQueue.main.async {
            context.coordinator.recalculateHeight()
        }

        return container
    }

    func updateNSView(_ container: GrowingTextContainer, context: Context) {
        let textView = container.textView
        if textView.hasMarkedText() { return }

        if textView.string != text {
            textView.string = text
            context.coordinator.recalculateHeight()
        }
        textView.isEditable = !isDisabled
        textView.font = font
        textView.textColor = textColor
        textView.placeholderString = placeholder
        textView.placeholderColor = placeholderColor
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: GrowingTextView
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?

        init(_ parent: GrowingTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if textView.hasMarkedText() { return }
            parent.text = textView.string
            parent.onTextChange?(textView.string)
            recalculateHeight()
        }

        func textView(
            _ textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                }
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape?()
                return true
            }
            return false
        }

        func recalculateHeight() {
            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else { return }

            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let insets = textView.textContainerInset
            let lineHeight = layoutManager.defaultLineHeightForFont(parent.font)
            let singleLineHeight = lineHeight + insets.height * 2
            let maxContentHeight = lineHeight * CGFloat(parent.maxLines) + insets.height * 2
            let contentHeight = usedRect.height + insets.height * 2
            let newHeight = min(max(contentHeight, singleLineHeight), maxContentHeight)

            let overflows = contentHeight > maxContentHeight
            scrollView?.hasVerticalScroller = overflows

            if abs(parent.height - newHeight) > 0.5 {
                parent.height = newHeight
            }

            if overflows {
                DispatchQueue.main.async { [weak self] in
                    guard let textView = self?.textView,
                          let scrollView = self?.scrollView
                    else { return }
                    textView.scrollRangeToVisible(textView.selectedRange())
                    let docHeight = textView.frame.height
                    let clipHeight = scrollView.contentView.bounds.height
                    let maxY = docHeight - clipHeight
                    if maxY > 0 {
                        var origin = scrollView.contentView.bounds.origin
                        let bottomInset = textView.textContainerInset.height
                        if origin.y < maxY, maxY - origin.y <= bottomInset {
                            origin.y = maxY
                            scrollView.contentView.scroll(to: origin)
                            scrollView.reflectScrolledClipView(scrollView.contentView)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Clip view that pins content to top when it fits

private class TopAlignedClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let documentView else { return rect }
        if documentView.frame.height <= bounds.height {
            rect.origin.y = 0
        }
        return rect
    }
}

// MARK: - Container View (forwards focus to NSTextView)

class GrowingTextContainer: NSView {
    let scrollView: NSScrollView
    let textView: GrowingPlaceholderTextView

    init() {
        scrollView = NSScrollView()
        textView = GrowingPlaceholderTextView()
        super.init(frame: .zero)

        let clipView = TopAlignedClipView()
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        scrollView.documentView = textView
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func layout() {
        super.layout()
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        window?.makeFirstResponder(textView)
        return true
    }
}

// MARK: - NSTextView with placeholder support

class GrowingPlaceholderTextView: NSTextView {
    var placeholderString: String = "" {
        didSet { needsDisplay = true }
    }

    var placeholderColor: NSColor = .placeholderTextColor

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholderString.isEmpty else { return }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? .systemFont(ofSize: 14),
            .foregroundColor: placeholderColor,
        ]
        let inset = textContainerInset
        let padding = textContainer?.lineFragmentPadding ?? 0
        let rect = NSRect(
            x: inset.width + padding,
            y: inset.height,
            width: bounds.width - inset.width * 2 - padding * 2,
            height: bounds.height - inset.height * 2
        )
        placeholderString.draw(in: rect, withAttributes: attrs)
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }
}

// MARK: - Layout Manager helper

extension NSLayoutManager {
    func defaultLineHeightForFont(_ font: NSFont) -> CGFloat {
        defaultLineHeight(for: font)
    }
}
