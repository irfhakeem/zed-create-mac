import AppKit
import QuartzCore

public enum AppModalStep {
    case selectDirectory
    case enterFileName
}

public final class KeyFloatingPanel: NSPanel {
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
}

final class ContainerTrackingView: NSView {
    var onMouseExit: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouseExit?()
    }
}

final class CustomTableView: NSTableView {
    var hoveredRow: Int? = nil {
        didSet {
            if oldValue != hoveredRow {
                var toReload = IndexSet()
                if let old = oldValue, old >= 0 && old < numberOfRows {
                    toReload.insert(old)
                }
                if let new = hoveredRow, new >= 0 && new < numberOfRows {
                    toReload.insert(new)
                }
                if !toReload.isEmpty {
                    reloadData(forRowIndexes: toReload, columnIndexes: IndexSet(integer: 0))
                }
            }
        }
    }
    
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        hoveredRow = (row >= 0 && row < numberOfRows) ? row : nil
    }
    
    override func mouseExited(with event: NSEvent) {
        hoveredRow = nil
    }
    
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        hoveredRow = (row >= 0 && row < numberOfRows) ? row : nil
    }
}

public final class PureModalController: NSObject, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    public var window: KeyFloatingPanel!
    private var visualEffectView: NSVisualEffectView!
    private var containerView: ContainerTrackingView!
    
    private var searchIcon: NSImageView!
    private var searchField: NSTextField!
    private var dividerLine: NSBox!
    private var scrollView: NSScrollView!
    private var tableView: CustomTableView!
    private var footerView: NSView!
    
    private var step2Container: NSView!
    private var step2Breadcrumb: NSTextField!
    private var step2Icon: NSImageView!
    private var fileNameField: NSTextField!
    private var step2ExamplesView: NSView!
    private var errorLabel: NSTextField!
    
    public let rootPath: String
    public let activeFilePath: String?
    private var allDirectories: [String] = []
    private var filteredResults: [FuzzyMatchResult] = []
    private var currentStep: AppModalStep = .selectDirectory
    private var selectedDirectory: String = "./"
    private var didBecomeKey = false
    
    public init(rootPath: String, activeFilePath: String? = nil) {
        self.rootPath = rootPath
        self.activeFilePath = activeFilePath
        super.init()
        
        let scanner = DirectoryScanner(rootPath: rootPath)
        self.allDirectories = scanner.scanDirectories()
        self.filteredResults = FuzzyMatcher.match(query: "", candidates: allDirectories)
        
        setupWindow()
        setupUI()
        
        if let activeFile = activeFilePath, !activeFile.isEmpty, activeFile != "$ZED_FILE" {
            let activeDir = (activeFile as NSString).deletingLastPathComponent
            let rel = activeDir.replacingOccurrences(of: rootPath, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let targetDir = rel.isEmpty ? "./" : "./" + rel
            if let idx = filteredResults.firstIndex(where: { $0.path == targetDir }) {
                tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
                tableView.scrollRowToVisible(idx)
            }
        } else if !filteredResults.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        
        DispatchQueue.main.async {
            self.window.makeFirstResponder(self.searchField)
        }
    }
    
    private func setupWindow() {
        let width: CGFloat = 580
        let height: CGFloat = 360
        
        window = KeyFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let xPos = screenFrame.origin.x + (screenFrame.width - width) / 2
            let yPos = screenFrame.origin.y + (screenFrame.height * 0.64) - (height / 2)
            window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
        } else {
            window.center()
        }
        window.acceptsMouseMovedEvents = true
    }
    
    private func setupUI() {
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 12
        contentView.layer?.masksToBounds = true
        contentView.layer?.borderWidth = 1
        contentView.layer?.borderColor = NSColor(white: 0.28, alpha: 1.0).cgColor
        
        visualEffectView = NSVisualEffectView(frame: contentView.bounds)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        contentView.addSubview(visualEffectView)
        
        let darkOverlay = NSBox(frame: contentView.bounds)
        darkOverlay.autoresizingMask = [.width, .height]
        darkOverlay.boxType = .custom
        darkOverlay.fillColor = NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 0.96)
        darkOverlay.borderWidth = 0
        contentView.addSubview(darkOverlay)
        
        containerView = ContainerTrackingView(frame: contentView.bounds)
        containerView.autoresizingMask = [.width, .height]
        containerView.onMouseExit = { [weak self] in
            self?.tableView.hoveredRow = nil
        }
        contentView.addSubview(containerView)
        
        setupStep1Views()
        setupStep2Views()
        setupFooterView()
        
        showStep1()
        window.contentView = contentView
    }
    
    private func setupStep1Views() {
        searchIcon = NSImageView(frame: NSRect(x: 16, y: 322, width: 20, height: 18))
        if let img = NSImage(systemSymbolName: "folder", accessibilityDescription: "Search") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            searchIcon.image = img.withSymbolConfiguration(config)
            searchIcon.contentTintColor = NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        }
        containerView.addSubview(searchIcon)
        
        searchField = NSTextField(frame: NSRect(x: 44, y: 314, width: 520, height: 26))
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.isEditable = true
        searchField.isSelectable = true
        searchField.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        searchField.textColor = .white
        searchField.placeholderString = "Select directory... (type to filter)"
        searchField.delegate = self
        containerView.addSubview(searchField)
        
        dividerLine = NSBox(frame: NSRect(x: 0, y: 304, width: 580, height: 1))
        dividerLine.boxType = .custom
        dividerLine.fillColor = NSColor(white: 0.22, alpha: 1.0)
        dividerLine.borderWidth = 0
        containerView.addSubview(dividerLine)
        
        scrollView = NSScrollView(frame: NSRect(x: 10, y: 36, width: 560, height: 262))
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        
        tableView = CustomTableView(frame: scrollView.bounds)
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.rowHeight = 24
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.autoresizingMask = [.width]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(tableRowClicked)
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DirColumn"))
        column.width = 544
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        containerView.addSubview(scrollView)
    }
    
    private func setupStep2Views() {
        step2Container = NSView(frame: NSRect(x: 0, y: 36, width: 580, height: 324))
        step2Container.isHidden = true
        
        step2Breadcrumb = NSTextField(labelWithString: "Creating in: ./")
        step2Breadcrumb.frame = NSRect(x: 16, y: 290, width: 548, height: 20)
        step2Breadcrumb.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        step2Breadcrumb.textColor = NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        step2Container.addSubview(step2Breadcrumb)
        
        step2Icon = NSImageView(frame: NSRect(x: 16, y: 257, width: 20, height: 18))
        if let img = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "File") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            step2Icon.image = img.withSymbolConfiguration(config)
            step2Icon.contentTintColor = NSColor(red: 0.35, green: 0.85, blue: 0.55, alpha: 1.0)
        }
        step2Container.addSubview(step2Icon)
        
        fileNameField = NSTextField(frame: NSRect(x: 44, y: 252, width: 520, height: 26))
        fileNameField.isBordered = false
        fileNameField.drawsBackground = false
        fileNameField.focusRingType = .none
        fileNameField.isEditable = true
        fileNameField.isSelectable = true
        fileNameField.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        fileNameField.textColor = .white
        fileNameField.placeholderString = "File name (e.g. user.go, sub/model.go, or folder/)"
        fileNameField.delegate = self
        step2Container.addSubview(fileNameField)
        
        let div2 = NSBox(frame: NSRect(x: 0, y: 242, width: 580, height: 1))
        div2.boxType = .custom
        div2.fillColor = NSColor(white: 0.22, alpha: 1.0)
        div2.borderWidth = 0
        step2Container.addSubview(div2)
        
        step2ExamplesView = NSView(frame: NSRect(x: 18, y: 40, width: 544, height: 180))
        let titleLabel = NSTextField(labelWithString: "Examples:")
        titleLabel.frame = NSRect(x: 0, y: 155, width: 200, height: 18)
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        step2ExamplesView.addSubview(titleLabel)
        
        let examples = [
            ("Single file", "user.go", "Creates standard file in selected folder"),
            ("Nested path", "handlers/user.go", "Creates parent folders automatically"),
            ("New folder", "services/", "Ending with / creates a directory"),
            ("Brace expansion", "model.{go,sql}", "Creates multiple files at once")
        ]
        
        var yOffset: CGFloat = 125
        for (name, ex, desc) in examples {
            let row = makeExampleRow(y: yOffset, title: name, example: ex, desc: desc)
            step2ExamplesView.addSubview(row)
            yOffset -= 28
        }
        step2Container.addSubview(step2ExamplesView)
        
        errorLabel = NSTextField(labelWithString: "")
        errorLabel.frame = NSRect(x: 18, y: 10, width: 544, height: 20)
        errorLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        errorLabel.textColor = .systemOrange
        errorLabel.isHidden = true
        step2Container.addSubview(errorLabel)
        
        containerView.addSubview(step2Container)
    }
    
    private func makeExampleRow(y: CGFloat, title: String, example: String, desc: String) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: y, width: 544, height: 22))
        
        let t1 = NSTextField(labelWithString: title)
        t1.frame = NSRect(x: 0, y: 2, width: 105, height: 18)
        t1.font = NSFont.systemFont(ofSize: 11)
        t1.textColor = NSColor(white: 0.5, alpha: 1.0)
        view.addSubview(t1)
        
        let t2 = NSTextField(labelWithString: example)
        t2.frame = NSRect(x: 110, y: 2, width: 145, height: 18)
        t2.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        t2.textColor = NSColor(red: 0.4, green: 0.8, blue: 0.6, alpha: 1.0)
        view.addSubview(t2)
        
        let t3 = NSTextField(labelWithString: desc)
        t3.frame = NSRect(x: 260, y: 2, width: 280, height: 18)
        t3.font = NSFont.systemFont(ofSize: 10)
        t3.textColor = NSColor(white: 0.4, alpha: 1.0)
        view.addSubview(t3)
        
        return view
    }
    
    private func setupFooterView() {
        footerView = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 32))
        let bgBox = NSBox(frame: footerView.bounds)
        bgBox.autoresizingMask = [.width, .height]
        bgBox.boxType = .custom
        bgBox.fillColor = NSColor(white: 0.08, alpha: 1.0)
        bgBox.borderWidth = 0
        footerView.addSubview(bgBox)
        
        let hints = NSTextField(labelWithString: "↑↓ navigate   ↵ select   esc cancel")
        hints.frame = NSRect(x: 14, y: 7, width: 350, height: 16)
        hints.font = NSFont.systemFont(ofSize: 10)
        hints.textColor = NSColor(white: 0.5, alpha: 1.0)
        footerView.addSubview(hints)
        
        let appLabel = NSTextField(labelWithString: "zed-create")
        appLabel.frame = NSRect(x: 480, y: 7, width: 85, height: 16)
        appLabel.alignment = .right
        appLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        appLabel.textColor = NSColor(white: 0.35, alpha: 1.0)
        footerView.addSubview(appLabel)
        
        containerView.addSubview(footerView)
    }
    
    private func showStep1() {
        currentStep = .selectDirectory
        tableView.hoveredRow = nil
        searchIcon.isHidden = false
        searchField.isHidden = false
        dividerLine.isHidden = false
        scrollView.isHidden = false
        step2Container.isHidden = true
        
        DispatchQueue.main.async {
            self.window.makeFirstResponder(self.searchField)
        }
    }
    
    private func showStep2() {
        currentStep = .enterFileName
        tableView.hoveredRow = nil
        searchIcon.isHidden = true
        searchField.isHidden = true
        dividerLine.isHidden = true
        scrollView.isHidden = true
        step2Container.isHidden = false
        
        step2Breadcrumb.stringValue = "📁 Creating in: \(selectedDirectory)"
        fileNameField.stringValue = ""
        errorLabel.isHidden = true
        
        DispatchQueue.main.async {
            self.window.makeFirstResponder(self.fileNameField)
        }
    }
    
    @objc private func tableRowClicked() {
        let row = tableView.clickedRow
        if row >= 0 && row < filteredResults.count {
            selectedDirectory = filteredResults[row].path
            showStep2()
        }
    }
    
    private func confirmDirectorySelection() {
        let row = tableView.selectedRow
        if row >= 0 && row < filteredResults.count {
            selectedDirectory = filteredResults[row].path
            showStep2()
        }
    }
    
    private func confirmFileCreation() {
        let input = fileNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        do {
            let created = try FileCreator.create(
                rootPath: rootPath,
                selectedDirectory: selectedDirectory,
                input: input
            )
            FileCreator.openInZed(filePaths: created)
            closeApp()
        } catch {
            errorLabel.stringValue = "Error: \(error.localizedDescription)"
            errorLabel.isHidden = false
        }
    }
    
    public func controlTextDidChange(_ obj: Notification) {
        guard let tf = obj.object as? NSTextField else { return }
        
        if tf == searchField {
            let query = tf.stringValue
            tableView.hoveredRow = nil
            self.filteredResults = FuzzyMatcher.match(query: query, candidates: allDirectories)
            self.tableView.reloadData()
            
            if !self.filteredResults.isEmpty {
                self.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                self.tableView.scrollRowToVisible(0)
            } else {
                self.tableView.deselectAll(nil)
            }
        }
    }
    
    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) || commandSelector == #selector(NSResponder.insertTab(_:)) {
            if currentStep == .selectDirectory {
                confirmDirectorySelection()
            } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                confirmFileCreation()
            }
            return true
        }
        
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            if currentStep == .enterFileName {
                showStep1()
            } else {
                closeApp()
            }
            return true
        }
        
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            if currentStep == .selectDirectory {
                tableView.hoveredRow = nil
                let row = tableView.selectedRow
                if row > 0 {
                    let newRow = row - 1
                    tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
                    tableView.scrollRowToVisible(newRow)
                }
                return true
            }
        }
        
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            if currentStep == .selectDirectory {
                tableView.hoveredRow = nil
                let row = tableView.selectedRow
                if row < filteredResults.count - 1 {
                    let newRow = row + 1
                    tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
                    tableView.scrollRowToVisible(newRow)
                }
                return true
            }
        }
        
        return false
    }
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredResults.count
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredResults.count else { return nil }
        let item = filteredResults[row]
        let isSelected = tableView.selectedRow == row
        let isHovered = self.tableView.hoveredRow == row
        
        let identifier = NSUserInterfaceItemIdentifier("DirRowCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? DirRowCellView
        if cell == nil {
            cell = DirRowCellView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 24))
            cell?.identifier = identifier
        }
        cell?.configure(item: item, isSelected: isSelected, isHovered: isHovered)
        return cell
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        let rows = tableView.rows(in: tableView.visibleRect)
        tableView.reloadData(forRowIndexes: IndexSet(integersIn: rows.location..<rows.location + rows.length), columnIndexes: IndexSet(integer: 0))
    }
    
    public func windowDidBecomeKey(_ notification: Notification) {
        didBecomeKey = true
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        if didBecomeKey {
            closeApp()
        }
    }
    
    @objc private func appDidResignActive() {
        if didBecomeKey {
            closeApp()
        }
    }
    
    public func closeApp() {
        window?.orderOut(nil)
        NSApp.terminate(nil)
    }
}

final class DirRowCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let textContainer = NSView()
    private let label = NSTextField(labelWithString: "")
    private let highlightBg = NSBox()
    
    private var item: FuzzyMatchResult?
    private var isSelectedRow: Bool = false
    private var isHovered: Bool = false
    private var isScrolling: Bool = false
    private var currentTextWidth: CGFloat = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        
        highlightBg.boxType = .custom
        highlightBg.borderWidth = 0
        highlightBg.cornerRadius = 6
        addSubview(highlightBg)
        
        addSubview(iconView)
        
        textContainer.wantsLayer = true
        textContainer.layer?.masksToBounds = true
        addSubview(textContainer)
        
        label.wantsLayer = true
        label.isBordered = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.lineBreakMode = .byTruncatingMiddle
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textContainer.addSubview(label)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stopAutoScroll()
        isHovered = false
        isSelectedRow = false
        item = nil
        updateHighlight()
    }
    
    override func layout() {
        super.layout()
        
        let hMargin: CGFloat = 6
        highlightBg.frame = NSRect(
            x: hMargin,
            y: 1,
            width: max(0, bounds.width - (hMargin * 2)),
            height: bounds.height - 2
        )
        
        let iconSize: CGFloat = 14
        iconView.frame = NSRect(
            x: 16,
            y: round((bounds.height - iconSize) / 2),
            width: iconSize,
            height: iconSize
        )
        
        let textX: CGFloat = 36
        let textRightMargin: CGFloat = 14
        let visibleWidth = max(0, bounds.width - textX - textRightMargin)
        textContainer.frame = NSRect(
            x: textX,
            y: 0,
            width: visibleWidth,
            height: bounds.height
        )
        
        let labelH: CGFloat = 16
        let labelY = round((bounds.height - labelH) / 2)
        if isScrolling {
            label.frame = NSRect(
                x: 0,
                y: labelY,
                width: max(currentTextWidth + 24, visibleWidth),
                height: labelH
            )
        } else {
            label.frame = NSRect(
                x: 0,
                y: labelY,
                width: visibleWidth,
                height: labelH
            )
        }
    }
    
    func configure(item: FuzzyMatchResult, isSelected: Bool, isHovered: Bool) {
        self.item = item
        self.isSelectedRow = isSelected
        self.isHovered = isHovered
        self.toolTip = item.path
        
        updateHighlight()
        
        let symbolName = item.path == "./" ? "house.fill" : "folder.fill"
        if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = isSelected
                ? NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
                : (isHovered ? NSColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0) : NSColor(white: 0.5, alpha: 1.0))
        }
        
        let attr = NSMutableAttributedString(
            string: item.path,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: isSelected ? NSColor.white : NSColor(white: 0.82, alpha: 1.0)
            ]
        )
        
        let highlightColor = isSelected
            ? NSColor(red: 0.95, green: 0.8, blue: 0.3, alpha: 1.0)
            : NSColor(red: 0.4, green: 0.75, blue: 1.0, alpha: 1.0)
        let boldFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        
        for idx in item.matchedIndices {
            if idx < item.path.count {
                let r = NSRange(location: idx, length: 1)
                attr.addAttribute(.foregroundColor, value: highlightColor, range: r)
                attr.addAttribute(.font, value: boldFont, range: r)
            }
        }
        
        label.attributedStringValue = attr
        currentTextWidth = ceil(attr.size().width)
        
        needsLayout = true
        
        if isHovered {
            startAutoScrollIfNeeded()
        } else {
            stopAutoScroll()
        }
    }
    
    private func updateHighlight() {
        if isSelectedRow {
            highlightBg.fillColor = NSColor(red: 0.2, green: 0.28, blue: 0.42, alpha: 0.85)
        } else if isHovered {
            highlightBg.fillColor = NSColor(red: 0.2, green: 0.28, blue: 0.42, alpha: 0.35)
        } else {
            highlightBg.fillColor = .clear
        }
    }
    
    private func startAutoScrollIfNeeded() {
        guard !isScrolling else { return }
        let visibleWidth = textContainer.bounds.width
        guard visibleWidth > 10 else { return }
        let overflow = currentTextWidth - visibleWidth
        guard overflow > 4 else { return }
        
        isScrolling = true
        label.lineBreakMode = .byClipping
        let labelH: CGFloat = 16
        let labelY = round((bounds.height - labelH) / 2)
        label.frame = NSRect(
            x: 0,
            y: labelY,
            width: currentTextWidth + 24,
            height: labelH
        )
        
        let anim = CABasicAnimation(keyPath: "transform.translation.x")
        anim.fromValue = 0
        anim.toValue = -(overflow + 10)
        let duration = max(1.5, Double(overflow) / 38.0)
        anim.duration = duration
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.beginTime = CACurrentMediaTime() + 0.3
        anim.fillMode = .both
        label.layer?.add(anim, forKey: "autoScroll")
    }
    
    private func stopAutoScroll() {
        guard isScrolling else { return }
        isScrolling = false
        label.layer?.removeAnimation(forKey: "autoScroll")
        label.layer?.transform = CATransform3DIdentity
        label.lineBreakMode = .byTruncatingMiddle
        let labelH: CGFloat = 16
        let labelY = round((bounds.height - labelH) / 2)
        label.frame = NSRect(
            x: 0,
            y: labelY,
            width: textContainer.bounds.width,
            height: labelH
        )
    }
}
