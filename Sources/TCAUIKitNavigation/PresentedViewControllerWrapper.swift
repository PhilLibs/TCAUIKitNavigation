#if canImport(UIKit)
import UIKit

/// Small Wrapper to react on `viewWillDisappear(_:)`.
///
/// This wrapper shows the `wrappedController` without changing the layout.
/// It's necessary to react on `viewWillDisappear(_:)` to capture every dismiss of the `wrappedController` without infering with existing delegates.
class PresentedViewControllerWrapper: UIViewController {
    private let wrappedController: UIViewController
    private let onDisappear: () -> Void
    
    init(wrappedController: UIViewController, onDisapear: @escaping () -> Void) {
        self.wrappedController = wrappedController
        self.onDisappear = onDisapear
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.addChild(wrappedController)
        wrappedController.didMove(toParent: self)
        self.view.addSubview(wrappedController.view)
        wrappedController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            wrappedController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            wrappedController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            wrappedController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            wrappedController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onDisappear()
    }
}
#endif
