import SwiftUI
import HotKey
import QuartzCore
import Cocoa
import Carbon
import UserNotifications
import ApplicationServices
import UniformTypeIdentifiers

class AppState: ObservableObject {
    var searchWindowController: NSWindowController?
    let hotKey: HotKey
    var initialTopY: CGFloat?
    private var clipboardTimer: Timer?
    private var lastClipboardChangeCount: Int = 0
    @AppStorage("autoSaveClipboard") private var autoSaveClipboard: Bool = false
    var dropZoneWindowController: NSWindowController?
    
    init() {
        hotKey = HotKey(key: .space, modifiers: [.command, .shift])
        hotKey.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.showSearchWindow()
            }
        }
        
        // Set up notification delegate BEFORE requesting permissions
        let notificationDelegate = NotificationDelegate.shared
        UNUserNotificationCenter.current().delegate = notificationDelegate
        
        requestNotificationPermissions()
        checkAccessibilityPermissions()
        setupGlobalHotkey()
        
        // Start clipboard monitoring if enabled
        if autoSaveClipboard {
            startClipboardMonitoring()
        }
    }
    
    deinit {
        stopClipboardMonitoring()
    }
    
    func toggleClipboardMonitoring(_ enabled: Bool) {
        if enabled {
            startClipboardMonitoring()
        } else {
            stopClipboardMonitoring()
        }
    }
    
    private func startClipboardMonitoring() {
        // Initialize with current clipboard state
        lastClipboardChangeCount = NSPasteboard.general.changeCount
        
        // Monitor clipboard every 0.5 seconds
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboardChanges()
        }
    }
    
    private func stopClipboardMonitoring() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }
    
    private func checkClipboardChanges() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        // Check if clipboard content has changed
        if currentChangeCount != lastClipboardChangeCount {
            lastClipboardChangeCount = currentChangeCount
            
            // Auto-save the new clipboard content
            saveCurrentClipboard(isAutoSave: true)
        }
    }
    
    // New method to save current clipboard content without copying
    func saveCurrentClipboard(isAutoSave: Bool = false) {
        print("saveCurrentClipboard called (auto: \(isAutoSave))")
        
        // Get bookmark data from UserDefaults
        let bookmarkData = UserDefaults.standard.data(forKey: "dataFolderBookmark") ?? Data()
        
        guard !bookmarkData.isEmpty else {
            if !isAutoSave {
                // Only show alert for manual saves
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "No Data Folder Configured"
                    alert.informativeText = "Please configure a data folder from the menu bar icon before saving."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
            return
        }
        
        // Resolve the security-scoped bookmark
        var bookmarkDataIsStale = false
        guard let folderURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &bookmarkDataIsStale
        ) else {
            print("Failed to resolve bookmark")
            UserDefaults.standard.removeObject(forKey: "dataFolderBookmark")
            UserDefaults.standard.removeObject(forKey: "dataFolderPath")
            return
        }
        
        // Start accessing the security-scoped resource
        guard folderURL.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource")
            return
        }
        
        // Ensure we stop accessing when done
        defer {
            folderURL.stopAccessingSecurityScopedResource()
        }
        
        // Process current clipboard content
        processClipboardContent(folderURL: folderURL, savedItems: [:], isAutoSave: isAutoSave)
    }
    
    func showSearchWindow() {
        if let window = searchWindowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let contentView = SearchView(isVisible: .constant(true), onRequestClose: {
            NSApp.terminate(nil)
        }, onDropZoneRequest: { [weak self] in
            self?.showDropZone()
        })
        let hosting = NSHostingController(rootView: contentView)
        let window = SpotlightWindow(contentViewController: hosting)
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.setFrameCentered(width: 596, height: 60)
        window.center()
        if NSScreen.main != nil {
            let windowFrame = window.frame
            initialTopY = windowFrame.maxY  // macOS coordinates: maxY is the top edge
        }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
            self?.hideSearchWindow()
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("SecondBrain.RecenterWindow"), object: nil, queue: .main) { [weak self] note in
            if let userInfo = note.userInfo,
               let width = userInfo["width"] as? CGFloat,
               let height = userInfo["height"] as? CGFloat {
                self?.recenterWindow(width: width, height: height)
            }
        }
        searchWindowController = NSWindowController(window: window)
        searchWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideSearchWindow() {
        searchWindowController?.window?.orderOut(nil)
        searchWindowController = nil
    }
    
    func recenterWindow(width: CGFloat, height: CGFloat) {
        if let window = searchWindowController?.window {
            if let topY = initialTopY, height > 60 {
                if width > 596 {
                    let currentFrame = window.frame
                    let currentCenterY = currentFrame.midY
                    window.setFrameKeepingVerticalCenter(width: width, height: height, centerY: currentCenterY)
                } else {
                    window.setFrameFromTop(width: width, height: height, topY: topY)
                }
            } else if height == 60 {
                window.setFrameCentered(width: width, height: height)
                if NSScreen.main != nil {
                    let windowFrame = window.frame
                    initialTopY = windowFrame.maxY
                }
            }
        }
    }
    
    private func setupGlobalHotkey() {
        // Check if we have accessibility permissions
        guard AXIsProcessTrusted() else {
            print("No accessibility permissions - global hotkey won't work")
            return
        }
        
        // Register for cmd+ctrl+s
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            print("Global key event: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags)")
            // Check for cmd+ctrl+s
            if event.keyCode == 1 && // 's' key
               event.modifierFlags.contains(.command) &&
               event.modifierFlags.contains(.control) &&
               !event.modifierFlags.contains(.option) &&
               !event.modifierFlags.contains(.shift) {
                print("Save shortcut detected!")
                self.captureAndSaveSelection()
            }
        }
        
        // Also monitor local events (when app is focused)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 1 && // 's' key
               event.modifierFlags.contains(.command) &&
               event.modifierFlags.contains(.control) &&
               !event.modifierFlags.contains(.option) &&
               !event.modifierFlags.contains(.shift) {
                self.captureAndSaveSelection()
                return nil // Consume the event
            }
            return event
        }
    }
    
    private func captureAndSaveSelection() {
        print("captureAndSaveSelection called!")
        
        // Get bookmark data from UserDefaults
        let bookmarkData = UserDefaults.standard.data(forKey: "dataFolderBookmark") ?? Data()
        print("Bookmark data size: \(bookmarkData.count) bytes")
        
        guard !bookmarkData.isEmpty else {
            print("No data folder configured")
            // Show alert to user
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "No Data Folder Configured"
                alert.informativeText = "Please configure a data folder from the menu bar icon before saving."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }
        
        // Resolve the security-scoped bookmark
        var bookmarkDataIsStale = false
        guard let folderURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &bookmarkDataIsStale
        ) else {
            print("Failed to resolve bookmark")
            // Clear invalid bookmark
            UserDefaults.standard.removeObject(forKey: "dataFolderBookmark")
            UserDefaults.standard.removeObject(forKey: "dataFolderPath")
            return
        }
        
        print("Resolved folder URL: \(folderURL.path)")
        print("Bookmark is stale: \(bookmarkDataIsStale)")
        
        // Start accessing the security-scoped resource
        guard folderURL.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource")
            return
        }
        
        // Ensure we stop accessing when done
        defer {
            folderURL.stopAccessingSecurityScopedResource()
        }
        
        // Save current clipboard contents to restore later
        let pasteboard = NSPasteboard.general
        let savedTypes = pasteboard.types ?? []
        var savedItems: [NSPasteboard.PasteboardType: Any] = [:]
        
        // Save current clipboard contents
        for type in savedTypes {
            if let data = pasteboard.data(forType: type) {
                savedItems[type] = data
            }
        }
        
        // Simulate Cmd+C to copy selected content
        let source = CGEventSource(stateID: .hidSystemState)
        let cDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true) // 'c' key
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        
        cDown?.flags = .maskCommand
        cUp?.flags = .maskCommand
        
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)
        
        // Wait a bit for the copy to complete, then process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.processClipboardContent(folderURL: folderURL, savedItems: savedItems)
        }
    }
    
    private func processClipboardContent(folderURL: URL, savedItems: [NSPasteboard.PasteboardType: Any], isAutoSave: Bool = false) {
        let pasteboard = NSPasteboard.general
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        var savedSuccessfully = false
        var contentType = "content"
        var fileName = ""
        
        // Check if we should organize by type
        let organizeByType = UserDefaults.standard.bool(forKey: "organizeByType")
        
        // Print available types for debugging
        if let types = pasteboard.types {
            print("Available pasteboard types: \(types.map { $0.rawValue })")
        }
        
        // Check for PDF data
        if let pdfData = pasteboard.data(forType: .pdf) {
            fileName = "document_\(timestamp).pdf"
            contentType = "PDF"
            let subfolder = organizeByType ? "PDFs" : nil
            let fileURL = createFileURL(in: folderURL, subfolder: subfolder, filename: fileName)
            
            do {
                try pdfData.write(to: fileURL)
                savedSuccessfully = true
                print("Saved PDF to: \(fileURL.path)")
            } catch {
                print("Failed to save PDF: \(error)")
            }
        }
        // Check for image data (multiple formats)
        else if let imageData = pasteboard.data(forType: .tiff) ?? 
                          pasteboard.data(forType: .png) {
            // Save as PNG
            fileName = "image_\(timestamp).png"
            contentType = "Image"
            let subfolder = organizeByType ? "Images" : nil
            let fileURL = createFileURL(in: folderURL, subfolder: subfolder, filename: fileName)
            
            // Convert to PNG if needed
            if let bitmap = NSBitmapImageRep(data: imageData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                do {
                    try pngData.write(to: fileURL)
                    savedSuccessfully = true
                    print("Saved image to: \(fileURL.path)")
                } catch {
                    print("Failed to save image: \(error)")
                }
            }
        }
        // Check for file URLs (dragged files)
        else if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
                !fileURLs.isEmpty {
            // Handle multiple files
            if fileURLs.count > 1 {
                contentType = "\(fileURLs.count) Files"
                fileName = "Multiple files"
            }
            
            // Copy files to the data folder
            for sourceURL in fileURLs {
                let fileExtension = sourceURL.pathExtension.lowercased()
                let baseName = sourceURL.deletingPathExtension().lastPathComponent
                let destFileName = "\(baseName)_\(timestamp).\(fileExtension)"
                
                if fileURLs.count == 1 {
                    contentType = detectFileType(from: fileExtension)
                    fileName = destFileName
                }
                
                let subfolder = organizeByType ? getSubfolderForType(contentType) : nil
                let destURL = createFileURL(in: folderURL, subfolder: subfolder, filename: destFileName)
                
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: destURL)
                    savedSuccessfully = true
                    print("Copied file to: \(destURL.path)")
                } catch {
                    print("Failed to copy file: \(error)")
                }
            }
        }
        // Check for RTF content
        else if let rtfData = pasteboard.data(forType: .rtf) {
            fileName = "document_\(timestamp).rtf"
            contentType = "Rich Text"
            let subfolder = organizeByType ? "Documents" : nil
            let fileURL = createFileURL(in: folderURL, subfolder: subfolder, filename: fileName)
            
            do {
                try rtfData.write(to: fileURL)
                savedSuccessfully = true
                print("Saved RTF to: \(fileURL.path)")
            } catch {
                print("Failed to save RTF: \(error)")
            }
        }
        // Check for HTML content
        else if let htmlString = pasteboard.string(forType: .html) {
            fileName = "webpage_\(timestamp).html"
            contentType = "HTML"
            let subfolder = organizeByType ? "Web" : nil
            let fileURL = createFileURL(in: folderURL, subfolder: subfolder, filename: fileName)
            
            do {
                try htmlString.write(to: fileURL, atomically: true, encoding: .utf8)
                savedSuccessfully = true
                print("Saved HTML to: \(fileURL.path)")
            } catch {
                print("Failed to save HTML: \(error)")
            }
        }
        // Check for URL string (web links)
        else if let urlString = pasteboard.string(forType: .string),
                let url = URL(string: urlString),
                url.scheme?.hasPrefix("http") == true {
            fileName = "link_\(timestamp).txt"
            contentType = "Web Link"
            let subfolder = organizeByType ? "Links" : nil
            let fileURL = createFileURL(in: folderURL, subfolder: subfolder, filename: fileName)
            
            do {
                // Save as markdown link
                let linkContent = "# Web Link\n\n[\(url.host ?? "Link")](\(urlString))\n\nSaved: \(Date())"
                try linkContent.write(to: fileURL, atomically: true, encoding: .utf8)
                savedSuccessfully = true
                print("Saved link to: \(fileURL.path)")
            } catch {
                print("Failed to save link: \(error)")
            }
        }
        // Fall back to plain text
        else if let text = pasteboard.string(forType: .string), !text.isEmpty {
            fileName = "text_\(timestamp).txt"
            contentType = "Text"
            let subfolder = organizeByType ? "Text" : nil
            let fileURL = createFileURL(in: folderURL, subfolder: subfolder, filename: fileName)
            
            do {
                try text.write(to: fileURL, atomically: true, encoding: .utf8)
                savedSuccessfully = true
                print("Saved text to: \(fileURL.path)")
                
                // Show notification with text preview
                self.showSaveNotification(contentType: contentType, filename: fileName, textPreview: text)
                
                // Restore old clipboard contents
                self.restoreClipboard(with: savedItems)
                return
            } catch {
                print("Failed to save text: \(error)")
            }
        } else {
            print("No supported content found in clipboard")
        }
        
        // Show notification for non-text content
        if savedSuccessfully {
            self.showSaveNotification(contentType: contentType, filename: fileName)
        }
        
        // Restore old clipboard contents only if not auto-save
        if !isAutoSave && !savedItems.isEmpty {
            self.restoreClipboard(with: savedItems)
        }
    }
    
    private func createFileURL(in baseFolder: URL, subfolder: String?, filename: String) -> URL {
        if let subfolder = subfolder {
            let subfolderURL = baseFolder.appendingPathComponent(subfolder)
            
            // Create subfolder if it doesn't exist
            if !FileManager.default.fileExists(atPath: subfolderURL.path) {
                try? FileManager.default.createDirectory(at: subfolderURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            return subfolderURL.appendingPathComponent(filename)
        } else {
            return baseFolder.appendingPathComponent(filename)
        }
    }
    
    private func getSubfolderForType(_ type: String) -> String {
        switch type {
        case "Image": return "Images"
        case "PDF": return "PDFs"
        case "Word Document", "Spreadsheet", "Presentation", "Rich Text": return "Documents"
        case "Video": return "Videos"
        case "Audio": return "Audio"
        case "Archive": return "Archives"
        case "Text": return "Text"
        case "HTML", "Web Link": return "Web"
        case "Code": return "Code"
        default: return "Files"
        }
    }
    
    private func detectFileType(from fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic":
            return "Image"
        case "pdf":
            return "PDF"
        case "doc", "docx":
            return "Word Document"
        case "xls", "xlsx":
            return "Spreadsheet"
        case "ppt", "pptx":
            return "Presentation"
        case "mp4", "mov", "avi", "mkv", "webm":
            return "Video"
        case "mp3", "wav", "aac", "flac", "m4a":
            return "Audio"
        case "zip", "rar", "7z", "tar", "gz":
            return "Archive"
        case "txt", "md", "markdown":
            return "Text"
        case "html", "htm":
            return "HTML"
        case "css", "js", "json", "xml", "yaml", "yml":
            return "Code"
        default:
            return "File"
        }
    }
    
    private func restoreClipboard(with savedItems: [NSPasteboard.PasteboardType: Any]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        for (type, value) in savedItems {
            if let data = value as? Data {
                pasteboard.setData(data, forType: type)
            } else if let string = value as? String {
                pasteboard.setString(string, forType: type)
            }
        }
    }
    
    private func showSaveNotification(contentType: String, filename: String, textPreview: String? = nil) {
        print("Attempting to show notification for: \(filename)")
        
        let content = UNMutableNotificationContent()
        content.title = "Saved to your second brain!"
        
        // Create a more user-friendly display
        let displayName: String
        if contentType == "Text", let preview = textPreview {
            // Use first few words of content as display name
            let words = preview.split(separator: " ").prefix(5).joined(separator: " ")
            displayName = words.isEmpty ? "Text snippet" : words + "..."
        } else {
            displayName = filename
        }
        
        content.body = "\(contentType): \(displayName) was logged and stored."
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error)")
            } else {
                print("Notification request added successfully")
            }
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted")
            } else {
                print("Notification permissions denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func checkAccessibilityPermissions() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            // Request accessibility permissions
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "To use the save shortcut (⌘⌃S), Second Brain needs accessibility permissions. Please grant access in System Settings > Privacy & Security > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            
            if alert.runModal() == .alertFirstButtonReturn {
                // Open accessibility settings
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    func showDropZone() {
        if let window = dropZoneWindowController?.window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        let dropZoneView = DropZoneView { [weak self] urls, text, image in
            self?.handleDroppedContent(urls: urls, text: text, image: image)
        }
        
        let hosting = NSHostingController(rootView: dropZoneView)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "Second Brain Drop Zone"
        window.setContentSize(NSSize(width: 300, height: 200))
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        window.center()
        
        dropZoneWindowController = NSWindowController(window: window)
        dropZoneWindowController?.showWindow(nil)
    }
    
    func hideDropZone() {
        dropZoneWindowController?.window?.close()
        dropZoneWindowController = nil
    }
    
    private func handleDroppedContent(urls: [URL]?, text: String?, image: NSImage?) {
        // Get data folder
        let bookmarkData = UserDefaults.standard.data(forKey: "dataFolderBookmark") ?? Data()
        guard !bookmarkData.isEmpty else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "No Data Folder Configured"
                alert.informativeText = "Please configure a data folder from the menu bar icon before saving."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }
        
        var bookmarkDataIsStale = false
        guard let folderURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &bookmarkDataIsStale
        ) else {
            return
        }
        
        guard folderURL.startAccessingSecurityScopedResource() else {
            return
        }
        defer {
            folderURL.stopAccessingSecurityScopedResource()
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let organizeByType = UserDefaults.standard.bool(forKey: "organizeByType")
        
        // Handle different content types
        if let urls = urls, !urls.isEmpty {
            // Handle file drops
            for url in urls {
                let fileExtension = url.pathExtension.lowercased()
                let baseName = url.deletingPathExtension().lastPathComponent
                let destFileName = "\(baseName)_\(timestamp).\(fileExtension)"
                let contentType = detectFileType(from: fileExtension)
                let subfolder = organizeByType ? getSubfolderForType(contentType) : nil
                let destURL = createFileURL(in: folderURL, subfolder: subfolder, filename: destFileName)
                
                do {
                    try FileManager.default.copyItem(at: url, to: destURL)
                    showSaveNotification(contentType: contentType, filename: destFileName)
                } catch {
                    print("Failed to copy dropped file: \(error)")
                }
            }
        } else if let image = image {
            // Handle image drops
            let fileName = "dropped_image_\(timestamp).png"
            let subfolder = organizeByType ? "Images" : nil
            let fileURL = createFileURL(in: folderURL, subfolder: subfolder, filename: fileName)
            
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                do {
                    try pngData.write(to: fileURL)
                    showSaveNotification(contentType: "Image", filename: fileName)
                } catch {
                    print("Failed to save dropped image: \(error)")
                }
            }
        } else if let text = text {
            // Handle text drops
            let fileName = "dropped_text_\(timestamp).txt"
            let subfolder = organizeByType ? "Text" : nil
            let fileURL = createFileURL(in: folderURL, subfolder: subfolder, filename: fileName)
            
            do {
                try text.write(to: fileURL, atomically: true, encoding: .utf8)
                showSaveNotification(contentType: "Text", filename: fileName, textPreview: text)
            } catch {
                print("Failed to save dropped text: \(error)")
            }
        }
    }
}

// Add this class before the SpotlightWindow class
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // This method allows notifications to be displayed while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              willPresent notification: UNNotification, 
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Display the notification even when the app is in the foreground
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}

class SpotlightWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension NSWindow {
    func setFrameCentered(width: CGFloat, height: CGFloat) {
        if let screen = NSScreen.main {
            let rect = CGRect(
                x: (screen.frame.width - width) / 2,
                y: (screen.frame.height - height) / 2,
                width: width,
                height: height
            )
            setFrame(rect, display: true)
        }
    }
    func setFrameCenteredWithAnimation(width: CGFloat, height: CGFloat) {
        if let screen = NSScreen.main {
            let rect = CGRect(
                x: (screen.frame.width - width) / 2,
                y: (screen.frame.height - height) / 2,
                width: width,
                height: height
            )
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animator().setFrame(rect, display: true)
            })
        }
    }
    func setFrameKeepingVerticalCenter(width: CGFloat, height: CGFloat, centerY: CGFloat) {
        if let screen = NSScreen.main {
            let x = (screen.frame.width - width) / 2
            let y = centerY - height / 2
            let rect = CGRect(x: x, y: y, width: width, height: height)
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animator().setFrame(rect, display: true)
            })
        }
    }
    func setFrameFromTop(width: CGFloat, height: CGFloat, topY: CGFloat) {
        if let screen = NSScreen.main {
            let x = (screen.frame.width - width) / 2
            let y = topY - height  // topY is the top edge, subtract height to get bottom edge
            let rect = CGRect(x: x, y: y, width: width, height: height)
            // Animate the frame change smoothly
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animator().setFrame(rect, display: true)
            })
        }
    }
}

// Add this new SwiftUI view before the SecondBrainApp struct
struct DropZoneView: View {
    let onDrop: ([URL]?, String?, NSImage?) -> Void
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(isDragging ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundColor(isDragging ? .blue : .gray.opacity(0.3))
                )
            
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 48))
                    .foregroundColor(isDragging ? .blue : .gray.opacity(0.5))
                
                Text("Drop files, images, or text here")
                    .font(.headline)
                    .foregroundColor(isDragging ? .blue : .gray)
                
                Text("Content will be saved to your Second Brain")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL, .text, .image, .tiff, .png, .pdf], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // Handle file URLs
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            onDrop([url], nil, nil)
                        }
                    }
                }
            }
            // Handle images
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadObject(ofClass: NSImage.self) { image, error in
                    if let image = image as? NSImage {
                        DispatchQueue.main.async {
                            onDrop(nil, nil, image)
                        }
                    }
                }
            }
            // Handle text
            else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                    if let text = item as? String {
                        DispatchQueue.main.async {
                            onDrop(nil, text, nil)
                        }
                    }
                }
            }
        }
    }
}

@main
struct SecondBrainApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("dataFolderPath") private var dataFolderPath: String = ""
    @AppStorage("dataFolderBookmark") private var dataFolderBookmarkData: Data = Data()
    @AppStorage("organizeByType") private var organizeByType: Bool = true
    @AppStorage("autoSaveClipboard") private var autoSaveClipboard: Bool = false
    @State private var shouldSelectFolder = false
    
    var body: some Scene {
        MenuBarExtra {
            Button("Show Second Brain") {
                appState.showSearchWindow()
            }
            Button("Show Drop Zone") {
                appState.showDropZone()
            }
            Button("Save Current Clipboard") {
                appState.saveCurrentClipboard()
            }
            Divider()
            Button("Test Notification") {
                // Test notification functionality
                let content = UNMutableNotificationContent()
                content.title = "Test Notification"
                content.body = "If you see this, notifications are working!"
                content.sound = UNNotificationSound.default
                
                let request = UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content, trigger: nil)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Test notification error: \(error)")
                    } else {
                        print("Test notification sent successfully")
                    }
                }
                
                // Also check current settings
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    print("Current notification settings:")
                    print("- Authorization status: \(settings.authorizationStatus.rawValue)")
                    print("- Alert setting: \(settings.alertSetting.rawValue)")
                    print("- Sound setting: \(settings.soundSetting.rawValue)")
                    print("- Badge setting: \(settings.badgeSetting.rawValue)")
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Data Folder:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if dataFolderPath.isEmpty {
                    Text("Not configured")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text(dataFolderPath)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Button("Configure Data Folder") {
                    // Use main thread to show the panel
                    DispatchQueue.main.async {
                        self.selectDataFolder()
                    }
                }
                .buttonStyle(.borderless)
                
                Divider()
                
                Toggle("Organize by file type", isOn: $organizeByType)
                    .font(.caption)
                    .toggleStyle(.checkbox)
                
                Toggle("Auto-save clipboard", isOn: $autoSaveClipboard)
                    .font(.caption)
                    .toggleStyle(.checkbox)
                    .onChange(of: autoSaveClipboard) { _, newValue in
                        appState.toggleClipboardMonitoring(newValue)
                    }
                if autoSaveClipboard {
                    Text("Automatically saves copied content")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image("2bicon_black")
                .resizable()
                .frame(width: 16, height: 16)
        }
        .menuBarExtraStyle(.window)
        Settings {
            EmptyView()
        }
    }
    
    private func selectDataFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select a folder to store your Second Brain data"
        openPanel.prompt = "Select Folder"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                // Create security-scoped bookmark
                do {
                    let bookmarkData = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    dataFolderBookmarkData = bookmarkData
                    dataFolderPath = url.path
                    print("Data folder configured: \(url.path)")
                } catch {
                    print("Failed to create bookmark: \(error)")
                }
            }
        }
    }
} 