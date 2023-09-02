#if canImport(UIKit)
import Combine
import ComposableArchitecture
import OrderedCollections
import UIKit
import CombineInterception
/// Coordinator which can be used to utilize the TCA `StackReducer` in UIKit.
///
/// It automatically handle pop via the UI and notifies the StackReducer about it.
/// This means one can leverage all benefits of the `StackStoreView` like automatic cancellation, etc.
/// In addition it's possible to utilize child / sub coordinators, which is not possible in SwiftUI due to the limitations of `StackView`.
///
/// - Note: This class is intended to be subclassed to provide a leaner intializer for example by providing a implementation of the `destinatiom` closure.
open class ComposableCoordinator<State: Equatable, Action>: NSObject, Coordinator, UINavigationControllerDelegate {
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.caseLetHelper) var caseLetHelper
    
    private let store: Store<StackState<State>, StackAction<State, Action>>
    private let viewStore: ViewStore<StackState<State>, StackAction<State, Action>>
    private let destination: (DestinationInstruction<State, Action>) -> Destination
    
    fileprivate let navigationController: UINavigationController
    
    private var destinationIdMapping: [StackElementID: Destination] = [:]
    fileprivate var cancellables: Set<AnyCancellable> = []
    private let isChild: Bool
    private weak var parent: Coordinator?
        
    public init(store: Store<StackState<State>, StackAction<State, Action>>,
                navigationController: UINavigationController = .init(),
                parent: Coordinator?,
                destination: @escaping (DestinationInstruction<State, Action>) -> Destination
    ) {
        self.store = store
        self.viewStore = ViewStore(store, observe: { $0 })
        self.navigationController = navigationController
        self.destination = destination
        self.isChild = parent != nil
        self.parent = parent
        super.init()
        if !isChild {
            navigationController.delegate = self
        } else {
            assert(navigationController.delegate is Coordinator, "Coordinator initiated as a child got a UINavigationController with a non-compatible delegate = \(String(describing: navigationController.delegate))")
        }
        createViewHierarchy()
        if !isChild {
            refreshViews(ids: viewStore.ids, animated: false)
        }
        setupObserving()
    }
    
    fileprivate func setupObserving() {
        viewStore.publisher
            .ids
            .dropFirst()
            .receive(on: mainQueue)
            .sink { [weak self] _ in
                self?.refreshViewHierarchy()
            }
            .store(in: &cancellables)
    }
    
    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        let handledTransition = handleNavigationControllerTransition(to: viewController)
        assert(handledTransition, "Transition to: \(viewController) has not been handled by any coordinator in the current coordinator stack of: \(navigationController)")
    }
    
    public func allViews() -> [UIViewController] {
        guard isChild else {
            return []
        }

        return viewStore.ids.compactMap { id -> [UIViewController]? in
            switch self.destinationIdMapping[id] {
            case .view(let view):
                return [view]
            case .coordinator(let child):
                return child.allViews()
            case .none:
                return nil
            }
        }.flatMap { $0 }
    }
    
    public func handleNavigationControllerTransition(to viewController: UIViewController) -> Bool {
        guard let toIdEntry = destinationIdMapping.first(where: { switch $0.value {
        case .view(let existingController):
            return viewController === existingController || caseLetHelper.isResolvedCaseLetViewController(viewController)
        case .coordinator:
            return false
        }
        }) else {
            for child in destinationIdMapping.childCoordinators {
                if child.handleNavigationControllerTransition(to: viewController) {
                    return true
                }
            }
            return false
        }
        let toId = toIdEntry.key
        
        let isPop = viewStore.ids.last != toId
        guard isPop else {
            return true
        }
        
        guard let index = viewStore.ids.firstIndex(of: toId) else {
            return false
        }
        viewStore.ids[index+1..<viewStore.ids.count].forEach { destinationIdMapping[$0] = nil }
        viewStore.send(.popFrom(id: viewStore.ids[index+1]))
        return true
    }
    
    public func refreshViewHierarchy() {
        refreshViews(ids: viewStore.ids, animated: true)
    }
    
    private func refreshViews(ids: OrderedSet<StackElementID>, animated: Bool) {
        let viewControllers = createViewHierarchy()
        if isChild {
            parent?.refreshViewHierarchy()
        } else {
            navigationController.setViewControllers(viewControllers, animated: animated)
        }
    }
    
    @discardableResult
    private func createViewHierarchy() -> [UIViewController] {
        viewStore.ids.compactMap { id -> [UIViewController]? in
            // compactMap shouldn't mutate self but it allows us to iterate over each id once, but maybe this is not worth it as the ids array is probably never large enough to be noticeable?
            guard var state = self.viewStore[id: id] else {
                destinationIdMapping[id] = nil
                return nil
            }
            let destination: Destination
            switch self.destinationIdMapping[id] {
            case .view(let view):
                return [view]
            case .coordinator(let child):
                return child.allViews()
            case .none:
                destination = self.destination(
                    .init(state: state,
                          parent: self,
                          store: self.store.scope(
                            state: {
                                state = $0[id: id] ?? state
                                return state
                                
                            },
                            action: { .element(id: id, action: $0) }
                          )
                         )
                )
            }
            let newViews: [UIViewController]
            switch destination {
            case .view(let view):
                newViews = [view]
                destinationIdMapping[id] = .view(view)
            case .coordinator(let child):
                newViews = child.allViews()
                destinationIdMapping[id] = .coordinator(child)
            }
            
            return newViews
        }.flatMap { $0 }
    }
    
    public func viewControllerToPresent() -> UIViewController {
        return navigationController
    }
}

/// Coordinator which can be used to utilize the TCA `StackReducer` and `_PresentationReducer`in UIKit.
///
/// This is a more powerful variant of the `ComposableCoordinator` as it also allows the handling for presenting views.
/// - Note: This class is intended to be subclassed to provide a leaner intializer for example by providing a implementation of the `destinatiom`and `presentation` closures.
open class ComposablePresentingCoordinator<State: Equatable, Action, PresentedState: Equatable, PresentedAction>: ComposableCoordinator<State, Action>{
        
    private let presentationStore: Store<PresentationState<PresentedState>, PresentationAction<PresentedAction>>?
    private let presentation: (DestinationInstruction<PresentedState, PresentedAction>) -> PresentationResult
        
    private var presentedDestination: Destination?
    private var presentedDestinationCancellable: Set<AnyCancellable>?

    
    public init(stackStore: Store<StackState<State>, StackAction<State, Action>>,
         presentationStore: Store<PresentationState<PresentedState>, PresentationAction<PresentedAction>>,
         navigationController: UINavigationController,
         destination: @escaping (DestinationInstruction<State, Action>) -> Destination,
         presentation: @escaping (DestinationInstruction<PresentedState, PresentedAction>) -> PresentationResult
    ) {
        self.presentationStore = presentationStore
        self.presentation = presentation
        super.init(store: stackStore,
                  navigationController: navigationController,
                  parent: nil,
                  destination: destination)
    }
    
    override func setupObserving() {
        super.setupObserving()
        setupPresentationStoreObserving()
    }
    
    private func setupPresentationStoreObserving() {
        guard let presentationStore else {
            return
        }
        presentationStore.scope(state: \.wrappedValue,
                                          action: { .presented($0) })
            .ifLet(
                then: { [weak self] presentedStore in
                    guard let self else { return }
                    
                    let result = presentation(.init(state: ViewStore(presentedStore, observe: { $0 }).state, parent: nil, store: presentedStore))
                    presentedDestination = result.destination
                    let viewController = result.controllerToPresent
                    
                    viewController.publisher(for: #selector(UIViewController.viewDidDisappear(_:)))
                        .sink { _ in
                            presentationStore.send(.dismiss)
                        }
                        .store(in: &cancellables)

                    viewController.modalPresentationStyle = result.style.modalPresentationStyle
                    navigationController.present(viewController, animated: true)
                },
                else: { [weak self] in
                    guard let self else { return }
                    presentedDestination = nil
                    guard navigationController.presentedViewController != nil else {
                        return
                    }
                    navigationController.dismiss(animated: true)
                }
            )
            .store(in: &cancellables)
    }
}

fileprivate extension Dictionary<StackElementID, Destination> {
    var childCoordinators: [Coordinator] {
        compactMap {
            switch $0.value {
            case .coordinator(let child):
                return child
            case .view:
                return nil
            }
        }
    }
}

public struct PresentationResult {
    let style: PresentationStyle
    let destination: Destination
    
    public init(style: PresentationStyle, destination: Destination) {
        self.style = style
        self.destination = destination
    }
    
    var controllerToPresent: UIViewController {
        switch destination {
        case .view(let viewController):
            return viewController
        case .coordinator(let coordinator):
            return coordinator.viewControllerToPresent()
        }
    }
}
#endif
