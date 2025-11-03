//
//  MarkdownEditorView.swift
//  notes
//
//  Markdown editor with live preview (split view)
//

import SwiftUI
import Down
import AppKit

struct MarkdownEditorView: View {
    let file: NoteFile
    @Binding var content: String
    let onSave: () -> Void
    
    var body: some View {
        HSplitView {
            // Editor on the left
            PlainTextEditor(text: $content, onSave: onSave)
            
            // Preview on the right
            MarkdownPreview(markdown: content)
        }
    }
}

struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    let onSave: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
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

struct MarkdownPreview: NSViewRepresentable {
    let markdown: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .textBackgroundColor
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        
        // Skip if markdown hasn't changed (optimization)
        if context.coordinator.lastRenderedMarkdown == markdown {
            return
        }
        
        context.coordinator.lastRenderedMarkdown = markdown
        
        // Debounce markdown rendering - only render after typing stops
        context.coordinator.renderTask?.cancel()
        context.coordinator.renderTask = Task {
            // Small delay to batch rapid changes
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
            
            guard !Task.isCancelled else { return }
            
            // Render on background thread
            let attributedString = await Task.detached(priority: .userInitiated) { () -> NSAttributedString? in
                if let down = try? Down(markdownString: markdown),
                   let attributed = try? down.toAttributedString() {
                    return attributed
                }
                return nil
            }.value
            
            guard !Task.isCancelled else { return }
            
            // Update UI on main thread
            await MainActor.run {
                if let attributedString = attributedString {
                    textView.textStorage?.setAttributedString(attributedString)
                } else {
                    textView.string = markdown
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var lastRenderedMarkdown: String = ""
        var renderTask: Task<Void, Never>?
        
        deinit {
            renderTask?.cancel()
        }
    }
}
