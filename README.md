# Second Brain (2B) - macOS App

A smart macOS app that captures and organizes your digital memories, creating your personal second brain.

## Features

- **Smart Clipboard Monitoring**: Automatically saves copied content (text, images, files) to your second brain
- **Drag & Drop Zone**: Easily save content by dragging files, images, or text to the drop zone
- **Quick Capture**: Use `⌘⌃S` to instantly save selected content from any app
- **Search & Recall**: Quickly find your saved memories with intelligent search
- **Slash Commands**: Use `/` commands for quick actions
- **Beautiful UI**: Modern, clean interface with smooth animations

## Installation

1. Clone the repository
2. Open `2B.xcodeproj` in Xcode
3. Build and run the project

## Usage

### Quick Start
- **Open Search**: Press `⌘⇧Space`
- **Save Selection**: Press `⌘⌃S` to save current selection
- **Slash Commands**: Type `/` to see available commands
  - `/recent` - View recent memories
  - `/topics` - Browse by topics
  - `/dropzone` - Open the drop zone

### Features in Detail

#### Auto-save Clipboard
Enable auto-save from the menu bar to automatically capture everything you copy.

#### Drop Zone
Drag and drop files, images, or text directly into the drop zone window for instant saving.

#### Organization
Files can be automatically organized by type (images, documents, text, etc.) in your data folder.

## Requirements

- macOS 11.0 or later
- Xcode 13.0 or later (for building)

## Permissions

The app requires:
- Accessibility permissions (for global hotkeys)
- Notification permissions (for save confirmations)

## Configuration

Configure your data folder from the menu bar icon to specify where your second brain content is stored.

## Technologies Used

- Swift
- SwiftUI
- HotKey (for global shortcuts)
- SVGView (for icon rendering)

## License

[Add your license here]

## Contributing

[Add contribution guidelines if you want to accept contributions] 