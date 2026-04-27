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

        // Firebase FCM delivers image URL under "gcm.n.image" key
        let userInfo = request.content.userInfo
        let imageUrlString = (userInfo["gcm.n.image"] as? String)
            ?? (userInfo["imageUrl"] as? String)
            ?? (userInfo["image"] as? String)

        guard let urlString = imageUrlString, let imageUrl = URL(string: urlString) else {
            contentHandler(content)
            return
        }

        downloadAndAttach(imageUrl: imageUrl, to: content) {
            contentHandler(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let handler = contentHandler, let content = bestAttemptContent {
            handler(content)
        }
    }

    private func downloadAndAttach(
        imageUrl: URL,
        to content: UNMutableNotificationContent,
        completion: @escaping () -> Void
    ) {
        URLSession.shared.downloadTask(with: imageUrl) { tempUrl, _, _ in
            defer { completion() }
            guard let tempUrl = tempUrl else { return }
            let ext = imageUrl.pathExtension.isEmpty ? "jpg" : imageUrl.pathExtension
            let destUrl = tempUrl.deletingLastPathComponent().appendingPathComponent("notif_image.\(ext)")
            try? FileManager.default.moveItem(at: tempUrl, to: destUrl)
            if let attachment = try? UNNotificationAttachment(identifier: "image", url: destUrl) {
                content.attachments = [attachment]
            }
        }.resume()
    }
}
