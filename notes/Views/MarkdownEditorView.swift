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
        
        // Clean, modern font styling
        textView.font = .systemFont(ofSize: 15, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        
        // Better text editing experience
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        
        // Enable link detection and make links clickable
        textView.isAutomaticLinkDetectionEnabled = true
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]
        
        // Nice padding for comfortable writing
        textView.textContainerInset = NSSize(width: 20, height: 20)
        
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
