#if canImport(UIKit)
import Combine
import ComposableArchitecture
import UIKit

public class CaseLetCoordinator<EnumState, EnumAction, CaseState, CaseAction, Content: Coordinator>: Coordinator {
    public let store: Store<EnumState, EnumAction>
    public let toCaseState: (EnumState) -> CaseState?
    public let fromCaseAction: (CaseAction) -> EnumAction
    public let content: (_ store: Store<CaseState, CaseAction>, _ navigationController: UINavigationController, _ parent: Coordinator) -> Content
    private var cancellables = Set<AnyCancellable>()
    private weak var parent: Coordinator?
    private var embeddedCoordinator: Coordinator?
    private let navigationController: UINavigationController
    
    public init(parent: Coordinator?,
         navigationController: UINavigationController,
         store: Store<EnumState, EnumAction>,
         toCaseState: @escaping (EnumState) -> CaseState?,
         action fromCaseAction: @escaping (CaseAction) -> EnumAction,
         then content: @escaping (_ store: Store<CaseState, CaseAction>, _ navigationController: UINavigationController, _ parent: Coordinator) -> Content) {
        self.parent = parent
        self.navigationController = navigationController
        self.store = store
        self.toCaseState = toCaseState
        self.fromCaseAction = fromCaseAction
        self.content = content
        setupEmbeddedCoordinator()
    }
    
    public func allViews() -> [UIViewController] {
        embeddedCoordinator?.allViews() ?? []
    }
    
    public func handleNavigationControllerTransition(to viewController: UIViewController) -> Bool {
        embeddedCoordinator?.handleNavigationControllerTransition(to: viewController) ?? false
    }
    
    public func refreshViewHierarchy() {
        parent?.refreshViewHierarchy()
    }
    
    // TODO: If we move this to a separate protocol we can omit this entirely and also API could become cleaner as maybe not every coordinator is intended to be presented?
    public func viewControllerToPresent() -> UIViewController {
        embeddedCoordinator?.viewControllerToPresent() ?? .init(nibName: nil, bundle: nil)
    }
    
    private func setupEmbeddedCoordinator() {
        store.scope(state: toCaseState, action: fromCaseAction)
            .ifLet { [weak self] store in
                guard let self else { return }
                embeddedCoordinator = content(store, navigationController, self)
            }
            .store(in: &cancellables)
    }
}
#endif
