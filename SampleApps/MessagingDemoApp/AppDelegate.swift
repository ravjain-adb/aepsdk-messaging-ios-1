//
// Copyright 2021 Adobe. All rights reserved.
// This file is licensed to you under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License. You may obtain a copy
// of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
// OF ANY KIND, either express or implied. See the License for the specific language
// governing permissions and limitations under the License.
//

import ACPCore
import AEPAssurance
import AEPCore
import AEPEdge
import AEPEdgeIdentity
import AEPLifecycle
import AEPMessaging
import AEPSignal
import UIKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let notificationCenter = UNUserNotificationCenter.current()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        notificationCenter.delegate = self

        let options: UNAuthorizationOptions = [.alert, .sound, .badge]

        notificationCenter.requestAuthorization(options: options) {
            didAllow, _ in
            if !didAllow {
                print("User has declined notifications")
            }
        }

        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Lifecycle.self, Messaging.self, Edge.self, Signal.self, Identity.self])

        MobileCore.configureWith(appId: "<appid>")
        MobileCore.updateConfigurationWith(configDict: [
            "messaging.useSandbox": true,
        ])

        // only start lifecycle if the application is not in the background
        if application.applicationState != .background {
            MobileCore.lifecycleStart(additionalContextData: nil)
        }

        AEPAssurance.registerExtension()
        ACPCore.start {
            if let url = URL(string: "<griffonurl>") {
                AEPAssurance.startSession(url)
            }
        }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in

            if let error = error {
                print("error requesting authorization: \(error)")
            }

            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }

        return true
    }

    // MARK: - UISceneSession Lifecycle

    func application(_: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options _: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_: UIApplication, didDiscardSceneSessions _: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Push Notification handling

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Token is - ")
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print(token)
        MobileCore.setPushIdentifier(deviceToken)
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError _: Error) {
        MobileCore.setPushIdentifier(nil)
    }

    func applicationWillEnterForeground(_: UIApplication) {
        MobileCore.lifecycleStart(additionalContextData: nil)
    }

    func applicationDidEnterBackground(_: UIApplication) {
        MobileCore.lifecyclePause()
    }

    func scheduleNotification() {
        let content = UNMutableNotificationContent()

        content.title = "Notification Title"
        content.body = "This is example how to create "

        content.userInfo = ["_xdm": ["cjm": ["_experience": ["customerJourneyManagement":
                                                                ["messageExecution": ["messageExecutionID": "16-Sept-postman", "messageID": "567",
                                                                                      "journeyVersionID": "some-journeyVersionId", "journeyVersionInstanceId": "someJourneyVersionInstanceId"]]]]]]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let identifier = "Local Notification"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error \(error.localizedDescription)")
            }
        }
    }

    func scheduleNotificationWithCustomAction() {
        let content = UNMutableNotificationContent()

        content.title = "Notification Title"
        content.body = "This is example how to create "
        content.categoryIdentifier = "MEETING_INVITATION"
        content.userInfo = ["_xdm": ["cjm": ["_experience": ["customerJourneyManagement":
                                                                ["messageExecution": ["messageExecutionID": "16-Sept-postman", "messageID": "567",
                                                                                      "journeyVersionID": "some-journeyVersionId", "journeyVersionInstanceId": "someJourneyVersionInstanceId"]]]]]]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let identifier = "Local Notification"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Define the custom actions.
        let acceptAction = UNNotificationAction(identifier: "ACCEPT_ACTION",
                                                title: "Accept",
                                                options: UNNotificationActionOptions(rawValue: 0))
        let declineAction = UNNotificationAction(identifier: "DECLINE_ACTION",
                                                 title: "Decline",
                                                 options: UNNotificationActionOptions(rawValue: 0))
        // Define the notification type
        let meetingInviteCategory =
            UNNotificationCategory(identifier: "MEETING_INVITATION",
                                   actions: [acceptAction, declineAction],
                                   intentIdentifiers: [],
                                   hiddenPreviewsBodyPlaceholder: "",
                                   options: .customDismissAction)
        // Register the notification type.
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.setNotificationCategories([meetingInviteCategory])

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error \(error.localizedDescription)")
            }
        }
    }

    func userNotificationCenter(_: UNUserNotificationCenter,
                                willPresent _: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }

    func userNotificationCenter(_: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Perform the task associated with the action.
        switch response.actionIdentifier {
        case "ACCEPT_ACTION":
            Messaging.handleNotificationResponse(response, applicationOpened: true, customActionId: "ACCEPT_ACTION")

        case "DECLINE_ACTION":
            Messaging.handleNotificationResponse(response, applicationOpened: false, customActionId: "DECLINE_ACTION")

        // Handle other actions…
        default:
            Messaging.handleNotificationResponse(response, applicationOpened: true, customActionId: nil)
        }

        // Always call the completion handler when done.
        completionHandler()
    }
}
