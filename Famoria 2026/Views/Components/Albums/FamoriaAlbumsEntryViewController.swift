//
//  FamoriaAlbumsEntryViewController.swift
//  Famoria Update 2026
//
//  UIKit bridge — wraps AlbumsView (SwiftUI) in a UIHostingController
//  so it can be pushed onto any UINavigationController or presented modally
//  from existing UIKit code.
//
//  ─────────────────────────────────────────────
//  USAGE EXAMPLES
//  ─────────────────────────────────────────────
//
//  // 1. Push from any UIViewController:
//  let vc = FamoriaAlbumsEntryViewController()
//  navigationController?.pushViewController(vc, animated: true)
//
//  // 2. Present modally:
//  let vc = FamoriaAlbumsEntryViewController()
//  present(vc, animated: true)
//
//  // 3. Embed as a tab in UITabBarController (e.g. in SceneDelegate):
//  let albumsVC = FamoriaAlbumsEntryViewController()
//  albumsVC.tabBarItem = UITabBarItem(
//      title: "Albums",
//      image: UIImage(systemName: "photo.stack"),
//      selectedImage: UIImage(systemName: "photo.stack.fill")
//  )
//  ─────────────────────────────────────────────
//

import UIKit
import SwiftUI

final class FamoriaAlbumsEntryViewController: UIViewController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        embedAlbumsView()
    }

    // MARK: - Private

    private func embedAlbumsView() {
        // Create the SwiftUI root view
        let albumsView = AlbumsView()
        let hostingController = UIHostingController(rootView: albumsView)

        // Add as child view controller
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor    .constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor .constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)

        // Hide the UIKit navigation bar — AlbumsView manages its own header
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore nav bar for the screens you return to if needed
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}
