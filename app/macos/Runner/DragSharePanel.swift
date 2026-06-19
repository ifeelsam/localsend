import Cocoa

struct DragShareDevice: Equatable {
    let fingerprint: String
    let alias: String
    let deviceType: String
}

struct DragShareStrings {
    let title: String
    let myDevices: String
    let scanning: String
}

protocol DragSharePanelDelegate: AnyObject {
    func dragSharePanelDidDrop(_ sender: NSDraggingInfo, fingerprint: String?)
}

final class DragSharePanelController: NSObject {
    weak var delegate: DragSharePanelDelegate?

    private var panel: NSPanel?
    private var contentView: DragSharePanelView?
    private var devices: [DragShareDevice] = []
    private var strings = DragShareStrings(
        title: "Drag items here to send them to your devices",
        myDevices: "My devices",
        scanning: "Searching for devices…"
    )

    var hoveredFingerprint: String? {
        contentView?.hoveredFingerprint
    }

    func updateStrings(_ strings: DragShareStrings) {
        self.strings = strings
        contentView?.updateStrings(strings)
    }

    func updateDevices(_ devices: [DragShareDevice]) {
        self.devices = devices
        contentView?.updateDevices(devices)
    }

    func show(relativeTo button: NSView?) {
        guard let button = button else { return }

        if panel == nil {
            let panelView = DragSharePanelView()
            panelView.delegate = self

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .popUpMenu
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.contentView = panelView

            self.panel = panel
            self.contentView = panelView
        }

        contentView?.updateStrings(strings)
        contentView?.updateDevices(devices)

        if let panel = panel, let contentView = contentView {
            let fittingSize = contentView.fittingSize
            panel.setContentSize(fittingSize)

            let buttonFrame = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero
            let panelX = buttonFrame.midX - fittingSize.width / 2
            let panelY = buttonFrame.minY - fittingSize.height - 4
            panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        contentView?.clearHover()
        panel?.orderOut(nil)
    }

    func contains(screenPoint: NSPoint) -> Bool {
        guard let panel = panel, panel.isVisible else { return false }
        return panel.frame.contains(screenPoint)
    }

    func handleDrop(_ sender: NSDraggingInfo, fingerprint: String?) {
        delegate?.dragSharePanelDidDrop(sender, fingerprint: fingerprint)
        hide()
    }
}

extension DragSharePanelController: DragSharePanelViewDelegate {
    func dragSharePanelViewDidDrop(_ sender: NSDraggingInfo, fingerprint: String?) {
        handleDrop(sender, fingerprint: fingerprint)
    }

    func dragSharePanelViewDidExitDrag() {
        hide()
    }
}

protocol DragSharePanelViewDelegate: AnyObject {
    func dragSharePanelViewDidDrop(_ sender: NSDraggingInfo, fingerprint: String?)
    func dragSharePanelViewDidExitDrag()
}

final class DragSharePanelView: NSView {
    weak var delegate: DragSharePanelViewDelegate?

    private let titleLabel = NSTextField(labelWithString: "")
    private let sectionLabel = NSTextField(labelWithString: "")
    private let scanningLabel = NSTextField(labelWithString: "")
    private let devicesContainer = NSView()
    private var deviceViews: [DragShareDeviceDropView] = []
    private var strings = DragShareStrings(
        title: "Drag items here to send them to your devices",
        myDevices: "My devices",
        scanning: "Searching for devices…"
    )

    private(set) var hoveredFingerprint: String?

    override var fittingSize: NSSize {
        layoutSubtreeIfNeeded()
        return NSSize(width: 360, height: max(180, frame.height))
    }

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
        layer?.cornerRadius = 12
        layer?.masksToBounds = true

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effect)
        NSLayoutConstraint.activate([
            effect.topAnchor.constraint(equalTo: topAnchor),
            effect.leadingAnchor.constraint(equalTo: leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: trailingAnchor),
            effect.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 2

        sectionLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        scanningLabel.font = NSFont.systemFont(ofSize: 13)
        scanningLabel.textColor = .secondaryLabelColor
        scanningLabel.alignment = .center

        let divider = NSBox()
        divider.boxType = .separator

        let stack = NSStackView(views: [titleLabel, divider, sectionLabel, devicesContainer, scanningLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            devicesContainer.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            devicesContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 88),
        ])

        registerForDraggedTypes([.fileURL, .URL, .string])
        updateStrings(strings)
    }

    func updateStrings(_ strings: DragShareStrings) {
        self.strings = strings
        titleLabel.stringValue = strings.title
        sectionLabel.stringValue = strings.myDevices
        scanningLabel.stringValue = strings.scanning
        scanningLabel.isHidden = !deviceViews.isEmpty
    }

    func updateDevices(_ devices: [DragShareDevice]) {
        deviceViews.forEach { $0.removeFromSuperview() }
        deviceViews = []

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 16
        row.distribution = .fillEqually

        for device in devices {
            let view = DragShareDeviceDropView(device: device)
            view.onHoverChanged = { [weak self] fingerprint, hovered in
                self?.hoveredFingerprint = hovered ? fingerprint : nil
            }
            view.onDrop = { [weak self] sender, fingerprint in
                self?.delegate?.dragSharePanelViewDidDrop(sender, fingerprint: fingerprint)
            }
            deviceViews.append(view)
            row.addArrangedSubview(view)
        }

        devicesContainer.subviews.forEach { $0.removeFromSuperview() }
        row.translatesAutoresizingMaskIntoConstraints = false
        devicesContainer.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: devicesContainer.topAnchor),
            row.leadingAnchor.constraint(equalTo: devicesContainer.leadingAnchor),
            row.trailingAnchor.constraint(lessThanOrEqualTo: devicesContainer.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: devicesContainer.bottomAnchor),
        ])

        scanningLabel.isHidden = !devices.isEmpty
    }

    func clearHover() {
        hoveredFingerprint = nil
        deviceViews.forEach { $0.setHovered(false) }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            let mouseLocation = NSEvent.mouseLocation
            if let frame = self.window?.frame, frame.contains(mouseLocation) {
                return
            }
            self.delegate?.dragSharePanelViewDidExitDrag()
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        delegate?.dragSharePanelViewDidDrop(sender, fingerprint: hoveredFingerprint)
        return true
    }
}

final class DragShareDeviceDropView: NSView {
    let device: DragShareDevice
    var onHoverChanged: ((String, Bool) -> Void)?
    var onDrop: ((NSDraggingInfo, String) -> Void)?

    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private var isHovered = false

    init(device: DragShareDevice) {
        self.device = device
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 88).isActive = true

        let circle = NSView()
        circle.wantsLayer = true
        circle.layer?.cornerRadius = 32
        circle.translatesAutoresizingMaskIntoConstraints = false

        iconView.image = NSImage(systemSymbolName: iconName(for: device.deviceType), accessibilityDescription: nil)
        iconView.contentTintColor = .labelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        circle.addSubview(iconView)
        addSubview(circle)

        nameLabel.stringValue = device.alias
        nameLabel.font = NSFont.systemFont(ofSize: 11)
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        NSLayoutConstraint.activate([
            circle.topAnchor.constraint(equalTo: topAnchor),
            circle.centerXAnchor.constraint(equalTo: centerXAnchor),
            circle.widthAnchor.constraint(equalToConstant: 64),
            circle.heightAnchor.constraint(equalToConstant: 64),
            iconView.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            nameLabel.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        registerForDraggedTypes([.fileURL, .URL, .string])
        setHovered(false)
    }

    func setHovered(_ hovered: Bool) {
        isHovered = hovered
        layer?.backgroundColor = NSColor.clear.cgColor
        if let circle = subviews.first {
            circle.layer?.backgroundColor = hovered
                ? NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
                : NSColor.secondaryLabelColor.withAlphaComponent(0.15).cgColor
            circle.layer?.borderWidth = hovered ? 2 : 0
            circle.layer?.borderColor = hovered ? NSColor.controlAccentColor.cgColor : NSColor.clear.cgColor
        }
    }

    private func iconName(for deviceType: String) -> String {
        switch deviceType {
        case "mobile": return "iphone"
        case "desktop": return "desktopcomputer"
        case "web": return "globe"
        case "headless": return "terminal"
        case "server": return "server.rack"
        default: return "desktopcomputer"
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        setHovered(true)
        onHoverChanged?(device.fingerprint, true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setHovered(false)
        onHoverChanged?(device.fingerprint, false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDrop?(sender, device.fingerprint)
        return true
    }
}

func extractDroppedFilePaths(from sender: NSDraggingInfo) -> [String] {
    let pasteboard = sender.draggingPasteboard
    guard let fileUrls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else {
        return []
    }

    var paths: [String] = []
    for url in fileUrls {
        if let bookmark = createBookmarkForFile(at: url),
           let resolved = SecurityScopedResourceManager.shared.startAccessing(bookmark: bookmark) {
            paths.append(resolved.path)
        } else {
            paths.append(url.path)
        }
    }
    return paths
}
