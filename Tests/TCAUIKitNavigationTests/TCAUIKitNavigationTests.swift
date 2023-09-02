import ComposableArchitecture
import XCTest
@testable import TCAUIKitNavigation
#if canImport(UIKit)
@MainActor
final class TCAUIKitNavigationTests: XCTestCase {
    func test_initialStack() throws {
        
        // WHEN
        // the coordinator gets initialized with a stack state which has one screen (Screen A)
        let store: Store<TestReducer.State, TestReducer.Action> = Store(initialState: TestReducer.State(path: .init([.screenA(.init())])), reducer: TestReducer.init)
        let navigationController = NavigationControllerMock()
        _ = withDependencies {
            $0.mainQueue = .immediate
        } operation: {
            TestCoordinator(store: store, navigationController: navigationController, parent: nil)
        }
        
        // THEN
        // the view controllers of the navigation controller got updated
        // and show the expected view controller for this Screen
        // as this was the initial creation of the view hierarchy this is not animated
        XCTAssertEqual(navigationController.callCount.setViewControllers, 1)
        let passedArguments = try XCTUnwrap(navigationController.arguments.setViewControllers.first)
        let viewControllers = passedArguments.0
        XCTAssertEqual(viewControllers.count, 1)
        XCTAssert(viewControllers.first is ScreenAViewController)
        let setViewControllersWasAnimated = passedArguments.1
        XCTAssertFalse(setViewControllersWasAnimated)
    }
    
    func test_pushElementToStack() throws {
        // GIVEN
        // the coordinator has been initialized with a stack state which has one screen (Screen A)
        let store = Store(initialState: TestReducer.State(path: .init([.screenA(.init())])), reducer: TestReducer.init)
        let navigationController = NavigationControllerMock()
        let testCoordinator = withDependencies {
            $0.mainQueue = .immediate
        } operation: {
            TestCoordinator(store: store, navigationController: navigationController, parent: nil)
        }
        
        // WHEN
        // a new screen gets pushed to the navigation stack
        let expectation = testCoordinator.expectationForCallOf(.refreshViewHierarchy, afterExecuting: { store.send(.path(.push(id: .init(integerLiteral: 1), state: .screenB(.init())))) })
                
        wait(for: [expectation], timeout: 1.0)
        
        
        // THEN
        // the view controllers of the navigation controller got updated
        // and reflect the new view hierarchy:
        // - Screen A -> Screen B
        // as this was not the initial creation of the view hierarchy the push of Screen B was animated
        XCTAssertEqual(navigationController.callCount.setViewControllers, 2)
        let passedArguments = try XCTUnwrap(navigationController.arguments.setViewControllers[safeIndex: 1])
        let viewControllers = passedArguments.0
        XCTAssertEqual(viewControllers.count, 2)
        XCTAssert(viewControllers[safeIndex: 0] is ScreenAViewController)
        XCTAssert(viewControllers[safeIndex: 1] is ScreenBViewController)
        let setViewControllersWasAnimated = passedArguments.1
        XCTAssert(setViewControllersWasAnimated)
    }
    
    func test_popElementFromStackViaUI() async throws {
        // GIVEN
        // the coordinator has been initialized with a stack state which has two screens (Screen A, Screen B)
        let store = Store(initialState: TestReducer.State(path: .init([.screenA(.init()), .screenB(.init())])), reducer: TestReducer.init)
        let navigationController = NavigationControllerMock()
        let testCoordinator = withDependencies {
            $0.mainQueue = .immediate
        } operation: {
            TestCoordinator(store: store, navigationController: navigationController, parent: nil)
        }
        let viewStore = ViewStore(store, observe: { $0 })
        // the view store stack has initially two ids (for Screen A, Screen B)
        XCTAssertEqual(viewStore.path.ids.count, 2)
        
        // WHEN
        // the user navigates backwards (e.g. via gesture or the back button)
        let firstViewController = try XCTUnwrap(navigationController.arguments.setViewControllers.first?.0[safeIndex: 0])
        XCTAssert(firstViewController is ScreenAViewController)
        await withMainSerialExecutor {
            testCoordinator.navigationController(navigationController, willShow: firstViewController, animated: true)
            await Task.megaYield(count: 20)
        }
        
        // THEN
        // the ids of the store got updated
        // and reflect the new view hierarchy:
        // - Screen A
        
        XCTAssertEqual(viewStore.path.ids.count, 1)
    }
    
    func test_popMultipleElementsFromStackViaUI() async throws {
        // GIVEN
        // the coordinator has been initialized with a stack state which has three screens (Screen A, Screen B, Screen A)
        let store = Store(initialState: TestReducer.State(path: .init([.screenA(.init()), .screenB(.init()), .screenA(.init())])), reducer: TestReducer.init)
        let navigationController = NavigationControllerMock()
        let testCoordinator = withDependencies {
            $0.mainQueue = .immediate
            $0.caseLetHelper = LiveCaseLetHelper()
        } operation: {
            TestCoordinator(store: store, navigationController: navigationController, parent: nil)
        }
        let viewStore = ViewStore(store, observe: { $0 })
        // the view store stack has initially three ids (for Screen A, Screen B, Screen A)
        XCTAssertEqual(viewStore.path.ids.count, 3)
        
        // WHEN
        // the user navigates backwards multiple screens (e.g. long-pressing the back button)
        let firstViewController = try XCTUnwrap(navigationController.arguments.setViewControllers.first?.0[safeIndex: 0])
        weak var secondViewController = try XCTUnwrap(navigationController.arguments.setViewControllers.first?.0[safeIndex: 1])
        weak var thirdViewController = try XCTUnwrap(navigationController.arguments.setViewControllers.first?.0[safeIndex: 2])
        XCTAssert(firstViewController is ScreenAViewController)
        await withMainSerialExecutor {
            testCoordinator.navigationController(navigationController, willShow: firstViewController, animated: true)
            await Task.megaYield(count: 20)
        }
        
        // THEN
        // the ids of the store got updated
        // and reflect the new view hierarchy:
        // - Screen A
        
        XCTAssertEqual(viewStore.path.ids.count, 1)
        
        navigationController.reset() // remove strong reference due to mock behavior
        
        // the viwe controller for the 2nd screen has been deallocated
        assertDeallocation {
            secondViewController ?? UIViewController()
        }
        
        // the viwe controller for the 3rd screen has been deallocated
        assertDeallocation {
            thirdViewController ?? UIViewController()
        }
    }
}

extension Array {
    public subscript(safeIndex index: Int) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }

        return self[index]
    }
}

extension XCTestCase {
    
    /// Checks for the callback to be the expected value within the given timeout.
    ///
    /// - Parameters:
    ///   - condition: The condition to check for.
    ///   - timeout: The timeout in which the callback should return true.
    ///   - description: A string to display in the test log for this expectation, to help diagnose failures.
    func wait(for condition: @autoclosure @escaping () -> Bool, timeout: TimeInterval, description: String, file: StaticString = #file, line: UInt = #line) {
        let end = Date().addingTimeInterval(timeout)

        var value: Bool = false
        let closure: () -> Void = {
            value = condition()
        }

        while !value && 0 < end.timeIntervalSinceNow {
            if RunLoop.current.run(mode: RunLoop.Mode.default, before: Date(timeIntervalSinceNow: 0.002)) {
                Thread.sleep(forTimeInterval: 0.002)
            }
            closure()
        }

        closure()

        XCTAssertTrue(value, "Timed out waiting for condition to be true: \"\(description)\"", file: file, line: line)
    }

    func assertDeallocation<T: AnyObject>(of object: () -> T) {
        weak var weakReferenceToObject: T?

        let autoreleasepoolExpectation = expectation(description: "Autoreleasepool should drain")

        autoreleasepool {
            let object = object()

            weakReferenceToObject = object

            XCTAssertNotNil(weakReferenceToObject)

            autoreleasepoolExpectation.fulfill()
        }

        wait(for: [autoreleasepoolExpectation], timeout: 10.0)
        wait(for: weakReferenceToObject == nil, timeout: 3.0, description: "The object should be deallocated since no strong reference points to it.")
    }
}

private class NavigationControllerMock: UINavigationController {
    struct CallCount {
       var setViewControllers = 0
    }
    
    struct Arguments {
        var setViewControllers: [([UIViewController], Bool)] = []
    }
    
    class Closures {
        var setViewControllers: (() -> Void)?
        
        init() {}
    }
    
    private(set) var callCount = CallCount()
    private(set) var arguments = Arguments()
    var executeWhenCall = Closures()
    
    func reset() {
        callCount = .init()
        arguments = .init()
        executeWhenCall = .init()
    }
    
    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        callCount.setViewControllers += 1
        arguments.setViewControllers.append((viewControllers, animated))
        executeWhenCall.setViewControllers?()
    }
}

private class ScreenAViewController: UIViewController {}
private class ScreenBViewController: UIViewController {}

private class TestCoordinator: ComposableCoordinator<TestReducer.Path.State, TestReducer.Path.Action> {
    enum Function {
        case allViews
        case handleNavigationControllerTransition
        case refreshViewHierarchy
        case idChangeHandling
    }
    
    private struct FunctionToAwait {
        let expectation = XCTestExpectation()
        let function: Function
    }
    
    private var currentFunctionToAwait: FunctionToAwait?
    
    init(store: Store<TestReducer.State, TestReducer.Action>,
         navigationController: UINavigationController,
         parent: Coordinator?) {
        let pathStore = store.scope(state: \.path, action: TestReducer.Action.path)
        super.init(store: pathStore,
                   navigationController: navigationController,
                   parent: parent,
                   destination: {
            switch $0.state {
            case .screenA:
                return .view(ScreenAViewController())
            case .screenB:
                return .view(ScreenBViewController())
            }
        })
    }
    
    func expectationForCallOf(_ function: Function, afterExecuting task: @escaping () -> Void) -> XCTestExpectation {
        let currentFunctionToAwait = FunctionToAwait(function: function)
        self.currentFunctionToAwait = currentFunctionToAwait
        task()
        return currentFunctionToAwait.expectation
    }
    
    override func allViews() -> [UIViewController] {
        let views = super.allViews()
        if currentFunctionToAwait?.function == .allViews {
            currentFunctionToAwait?.expectation.fulfill()
        }
        return views
    }
    
    override func handleNavigationControllerTransition(to viewController: UIViewController) -> Bool {
        let result = super.handleNavigationControllerTransition(to: viewController)
        if currentFunctionToAwait?.function == .handleNavigationControllerTransition {
            currentFunctionToAwait?.expectation.fulfill()
        }
        return result
    }
    
    override func refreshViewHierarchy() {
        super.refreshViewHierarchy()
        if currentFunctionToAwait?.function == .refreshViewHierarchy {
            currentFunctionToAwait?.expectation.fulfill()
        }
    }
}

private struct TestReducer: Reducer {
    struct State: Equatable {
        var path: StackState<Path.State>
    }
    
    enum Action: Equatable {
        case path(StackAction<Path.State, Path.Action>)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .path(.element(id: _, action: .screenA(.screenBButtonTapped))):
                state.path.append(.screenB(.init()))
                return .none
            case .path(.element(id: _, action: .screenA(.screenAButtonTapped))):
                state.path.append(.screenA(.init()))
                return .none
            case .path(.element(id: _, action: .screenB(.screenBButtonTapped))):
                state.path.append(.screenB(.init()))
                return .none
            case .path(.element(id: _, action: .screenB(.screenAButtonTapped))):
                state.path.append(.screenA(.init()))
                return .none
            case .path:
                return .none
            }
        }
        .forEach(\.path, action: /Action.path) {
            Path()
        }
    }
    
    struct Path: Reducer {
        enum State: Codable, Equatable, Hashable {
            case screenA(ScreenA.State = .init())
            case screenB(ScreenB.State = .init())
        }
        
        enum Action: Equatable {
            case screenA(ScreenA.Action)
            case screenB(ScreenB.Action)
        }
        
        var body: some Reducer<State, Action> {
            Scope(state: /State.screenA, action: /Action.screenA) {
                ScreenA()
            }
            Scope(state: /State.screenB, action: /Action.screenB) {
                ScreenB()
            }
        }
    }
}

struct ScreenA: Reducer {
    struct State: Codable, Equatable, Hashable {}
    
    enum Action: Equatable {
        case screenAButtonTapped
        case screenBButtonTapped
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .screenAButtonTapped:
            return .none
        case .screenBButtonTapped:
            return .none
        }
    }
}

struct ScreenB: Reducer {
    struct State: Codable, Equatable, Hashable {}
    
    enum Action: Equatable {
        case screenAButtonTapped
        case screenBButtonTapped
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .screenAButtonTapped:
            return .none
        case .screenBButtonTapped:
            return .none
        }
    }
}

#endif
