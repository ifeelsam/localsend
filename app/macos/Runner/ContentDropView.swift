import Cocoa

class ContentDropView: NSView {
    weak var panelController: DragSharePanelController?
    var onDragSessionStarted: (() -> Void)?
    var onDragSessionEnded: (() -> Void)?
    var onDrop: ((NSDraggingInfo, String?) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        registerForDraggedTypes([.fileURL, .URL, .string])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragSessionStarted?()
        if let button = superview {
            panelController?.show(relativeTo: button)
        }
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            let mouseLocation = NSEvent.mouseLocation
            if self.panelController?.contains(screenPoint: mouseLocation) == true {
                return
            }
            if let buttonFrame = self.window?.convertToScreen(self.convert(self.bounds, to: nil)),
               buttonFrame.contains(mouseLocation) {
                return
            }
            self.onDragSessionEnded?()
            self.panelController?.hide()
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let fingerprint = panelController?.hoveredFingerprint
        onDrop?(sender, fingerprint)
        panelController?.hide()
        return true
    }
}
