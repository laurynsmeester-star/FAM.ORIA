import SwiftUI
import os
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// App Check is intentionally not configured here.
//
// Previously this app installed a debug App Check provider on the simulator
// and an App Attest provider on device. The debug provider only emits valid
// tokens when its generated token is registered in Firebase Console →
// App Check → Manage debug tokens. Without that one-time setup, every
// Firestore write, every Storage upload, and every download URL request
// is rejected — which is exactly what was happening: documents weren't
// saving, journal entries weren't saving, and album photo uploads were
// failing with "Object … does not exist".
//
// To re-enable App Check later:
//   1. Add `import FirebaseAppCheck` back to this file.
//   2. Restore the FamoriaAppCheckProviderFactory below.
//   3. Run the app once on simulator, copy the debug token printed in the
//      Xcode console, and register it under Firebase Console → App Check →
//      iOS app → "Manage debug tokens".
//   4. Restore the `AppCheck.setAppCheckProviderFactory(...)` call below
//      *before* `FirebaseApp.configure()`.

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                Log.notifications.error("Notification permission error: \(error.localizedDescription, privacy: .public)")
            }
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }

        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let page = userInfo["page"] as? String {
            NotificationCenter.default.post(name: .famoriaDeepLink, object: page)
        }
        completionHandler()
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.notifications.error("Failed to register for remote notifications: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Log.notifications.debug("FCM token received: \(token, privacy: .private)")
        // Store token in Firestore so the server can send push notifications
        UserDefaults.standard.set(token, forKey: "famoria.fcmToken")
    }
}

extension Notification.Name {
    static let famoriaDeepLink = Notification.Name("famoriaDeepLink")
}

// MARK: - Local Notification Scheduler

enum FamoriaNotificationScheduler {
    static func scheduleEventReminder(event: FamilyEvent, minutesBefore: Int = 60) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Event"
        content.body = "\(event.title) is coming up!"
        content.sound = .default
        content.userInfo = ["page": "events", "eventId": event.id]

        let triggerDate = event.date.addingTimeInterval(-Double(minutesBefore * 60))
        guard triggerDate > Date() else { return }

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let request = UNNotificationRequest(
            identifier: "event-\(event.id)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    static func cancelEventReminder(eventId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["event-\(eventId)"])
    }

    static func scheduleAllEventReminders(events: [FamilyEvent]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let timingKey = UserDefaults.standard.string(forKey: "famoria.reminder.timing") ?? "1day"
        let minutes: Int = {
            switch timingKey {
            case "15min":  return 15
            case "30min":  return 30
            case "1hour":  return 60
            case "1day":   return 1440
            case "1week":  return 10080
            default:       return 1440
            }
        }()

        for event in events where event.date > Date() {
            scheduleEventReminder(event: event, minutesBefore: minutes)
        }
    }
}

@main
struct Famoria_2026App: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .onReceive(NotificationCenter.default.publisher(for: .famoriaDeepLink)) { notification in
                    if let page = notification.object as? String,
                       let famoriaPage = FamoriaPage(rawValue: page) {
                        appState.deepLinkPage = famoriaPage
                    }
                }
                .onChange(of: appState.events) { _, events in
                    if UserDefaults.standard.bool(forKey: "famoria.notif.reminders") != false {
                        FamoriaNotificationScheduler.scheduleAllEventReminders(events: events)
                    }
                }
        }
    }
}

