#if canImport(UIKit)
import UIKit

public protocol Coordinator: AnyObject {
    
    /// Returns all current active view controllers which this coordinator controls.
    func allViews() -> [UIViewController]
    
    /// Handles the `UINavigationController` transition to the given `viewController`.
    ///
    /// - Returns: `true` if the transition has been handled and `false` if not.
    func handleNavigationControllerTransition(to viewController: UIViewController) -> Bool
    
    
    /// Refreshes the view hierarchy.
    ///
    /// Calling this method propagates to the root of the coordinator tree which eventually updates the view controllers of its `UINavigationCotroller`.
    func refreshViewHierarchy()
    
    /// Returns the `UIViewController` which should be presented by the parent coordinator.
    func viewControllerToPresent() -> UIViewController
}
#endif
