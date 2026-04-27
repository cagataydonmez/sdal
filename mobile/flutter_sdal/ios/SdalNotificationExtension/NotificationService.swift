import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // Image URL arrives in the FCM data payload (not via fcm_options.image,
        // which causes FCM INTERNAL errors when Google pre-validates the URL).
        let userInfo = request.content.userInfo
        let imageUrlString = (userInfo["imageUrl"] as? String)
            ?? (userInfo["gcm.n.image"] as? String)

        guard let urlString = imageUrlString,
              !urlString.isEmpty,
              let imageUrl = URL(string: urlString) else {
            contentHandler(content)
            return
        }

        URLSession.shared.downloadTask(with: imageUrl) { tempUrl, response, _ in
            defer { contentHandler(content) }
            guard let tempUrl = tempUrl,
                  (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let ext: String
            let path = imageUrl.path.lowercased()
            if path.hasSuffix(".png") { ext = "png" }
            else if path.hasSuffix(".jpeg") { ext = "jpeg" }
            else { ext = "jpg" }
            let destUrl = tempUrl
                .deletingLastPathComponent()
                .appendingPathComponent("sdal_notif.\(ext)")
            try? FileManager.default.moveItem(at: tempUrl, to: destUrl)
            if let attachment = try? UNNotificationAttachment(
                identifier: "image",
                url: destUrl,
                options: nil
            ) {
                content.attachments = [attachment]
            }
        }.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        if let handler = contentHandler, let content = bestAttemptContent {
            handler(content)
        }
    }
}
