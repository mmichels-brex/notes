//
//  MarkdownEditorView.swift
//  notes
//
//  Simple text editor
//

import SwiftUI
import AppKit

struct MarkdownEditorView: View {
    let file: NoteFile
    @Binding var content: String
    let onSave: () -> Void
    
    var body: some View {
        PlainTextEditor(text: $content, onSave: onSave)
            .background(
                // Subtle gradient background for depth
                LinearGradient(
                    colors: [
                        Color(nsColor: .textBackgroundColor),
                        Color(nsColor: .textBackgroundColor).opacity(0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    let onSave: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.importsGraphics = false
        
        // Beautiful, modern typography with SF Pro
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear  // Let SwiftUI gradient show through
        
        // Better line spacing for readability
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 12
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
        
        // Better text editing experience
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        
        // Enable link detection with modern styling
        textView.isAutomaticLinkDetectionEnabled = true
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]
        
        // Generous padding for comfortable writing (like Apple Notes)
        textView.textContainerInset = NSSize(width: 32, height: 32)
        
        // Smooth scrolling
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.backgroundColor = .clear
        
        // Set initial content
        textView.string = text
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        
        // Only update if text changed externally
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            
            // Trigger link detection for the entire document
            textView.checkTextInDocument(nil)
            
            if selectedRange.location <= textView.string.count {
                textView.setSelectedRange(selectedRange)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSave: onSave)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        let onSave: () -> Void
        
        init(text: Binding<String>, onSave: @escaping () -> Void) {
            self._text = text
            self.onSave = onSave
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            onSave()
        }
    }
}
