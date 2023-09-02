#if canImport(UIKit)
import Combine
import ComposableArchitecture
import Dependencies
import UIKit

public class CaseLetViewController<EnumState, EnumAction, CaseState, CaseAction>: UIViewController {
    @Dependency(\.caseLetHelper) var caseLetHelper
    public let store: Store<EnumState, EnumAction>
    public let toCaseState: (EnumState) -> CaseState?
    public let fromCaseAction: (CaseAction) -> EnumAction
    public let content: (_ store: Store<CaseState, CaseAction>) -> UIViewController
    private var cancellables = Set<AnyCancellable>()
    
    public init(store: Store<EnumState, EnumAction>,
         toCaseState: @escaping (EnumState) -> CaseState?,
         action fromCaseAction: @escaping (CaseAction) -> EnumAction,
         then content: @escaping (_ store: Store<CaseState, CaseAction>) -> UIViewController) {
        self.store = store
        self.toCaseState = toCaseState
        self.fromCaseAction = fromCaseAction
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        store.scope(state: toCaseState, action: fromCaseAction)
            .ifLet { [weak self] store in
                self?.replaceContent(store: store)
            }
            .store(in: &cancellables)
    }
    
    private func embedContent(store: Store<CaseState, CaseAction>) {
        let content = content(store)
        
        self.view.subviews.forEach { $0.removeFromSuperview() }
        self.children.forEach { $0.removeFromParent() }
        
        guard let contentView = content.view else {
            return
        }
        self.view.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: self.view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
        
        self.addChild(content)
        content.didMove(toParent: self)
    }
    
    private func replaceContent(store: Store<CaseState, CaseAction>) {
        guard let navigationController, let index = navigationController.viewControllers.firstIndex(of: self) else {
            assertionFailure("\(Self.self) tried to replace view controller without being part of current navigation hierarchy")
            return
        }
        let content = content(store)
        caseLetHelper.markAsCaseLetViewController(content, of: self)
        var viewControllers = navigationController.viewControllers
        viewControllers[index] = content
        let needsManualRefresh = navigationController.viewControllers.count == index + 1
        if needsManualRefresh {
            // Replacing the navigation stack too fast results in a broken UINavigationBar.
            // A potential workaround is to pop & push and eventually set the viewcontrollers animated.
            // The pop & push fixes the empty UINavigationBar and the animated set fixes the wrong back button in a root view.
            navigationController.popViewController(animated: false)
            navigationController.pushViewController(content, animated: false)
        }
        navigationController.setViewControllers(viewControllers, animated: needsManualRefresh)
    }



#endif
#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

extension CaseLetViewController {
    @_disfavoredOverload
    public convenience init<Content: View>(store: Store<EnumState, EnumAction>,
          toCaseState: @escaping (EnumState) -> CaseState?,
          action fromCaseAction: @escaping (CaseAction) -> EnumAction,
          then content: @escaping (_ store: Store<CaseState, CaseAction>) -> Content) {
        self.init(
            store: store,
            toCaseState: toCaseState,
            action: fromCaseAction,
            then: { UIHostingController(rootView: content($0)) }
        )
     }
}
#endif
