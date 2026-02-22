import SwiftUI
import UIKit
import ImageIO
import AVFoundation

actor RemoteImagePipeline {
    static let shared = RemoteImagePipeline()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [NSString: Task<UIImage?, Never>] = [:]
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024,
            diskPath: "sdal_native_images"
        )
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)

        cache.countLimit = 500
        cache.totalCostLimit = 128 * 1024 * 1024
    }

    func image(for url: URL, targetSize: CGSize? = nil, scale: CGFloat = 2.0) async -> UIImage? {
        let key = cacheKey(url: url, targetSize: targetSize, scale: scale)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        if let active = inFlight[key] {
            return await active.value
        }

        let task = Task<UIImage?, Never> { [session] in
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    return nil
                }
                return downsampledImage(data: data, targetSize: targetSize, scale: scale) ?? UIImage(data: data)
            } catch {
                return nil
            }
        }

        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image {
            cache.setObject(image, forKey: key, cost: imageCost(image))
        }
        return image
    }

    func prefetch(url: URL?, targetSize: CGSize? = nil, scale: CGFloat = 2.0) {
        guard let url else { return }
        Task {
            _ = await image(for: url, targetSize: targetSize, scale: scale)
        }
    }

    private func cacheKey(url: URL, targetSize: CGSize?, scale: CGFloat) -> NSString {
        guard let targetSize, targetSize.width > 0, targetSize.height > 0 else {
            return "\(url.absoluteString)|o" as NSString
        }
        let w = Int((targetSize.width * scale).rounded())
        let h = Int((targetSize.height * scale).rounded())
        return "\(url.absoluteString)|\(w)x\(h)" as NSString
    }

    private func downsampledImage(data: Data, targetSize: CGSize?, scale: CGFloat) -> UIImage? {
        guard let targetSize, targetSize.width > 0, targetSize.height > 0 else { return nil }
        let maxDimension = max(targetSize.width, targetSize.height) * scale
        guard maxDimension > 0 else { return nil }
        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceShouldCache: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxDimension))
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func imageCost(_ image: UIImage) -> Int {
        if let cgImage = image.cgImage {
            return cgImage.bytesPerRow * cgImage.height
        }
        let pixels = image.size.width * image.size.height * image.scale * image.scale
        return Int(pixels * 4)
    }
}

struct CachedRemoteImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let targetSize: CGSize?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    init(
        url: URL?,
        targetSize: CGSize? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.targetSize = targetSize
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: "\(url?.absoluteString ?? "")|\(targetSize?.debugDescription ?? "nil")") {
            guard let url else {
                uiImage = nil
                return
            }
            let scale = UIScreen.main.scale
            uiImage = await RemoteImagePipeline.shared.image(for: url, targetSize: targetSize, scale: scale)
        }
    }
}

struct AsyncAvatarView: View {
    let imageName: String?
    let size: CGFloat

    var body: some View {
        let resolved = AppConfig.avatarURL(imageName: imageName)

        Group {
            if let resolved {
                CachedRemoteImage(url: resolved, targetSize: CGSize(width: size, height: size)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 2))
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(SDALTheme.secondary.opacity(0.18))
            Image(systemName: "person.fill")
                .foregroundStyle(SDALTheme.secondary)
        }
    }
}

struct CameraCapturePicker: UIViewControllerRepresentable {
    let onImageData: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            DispatchQueue.main.async {
                onImageData(nil)
            }
            return UIViewController()
        }

        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        if authorization == .denied || authorization == .restricted {
            DispatchQueue.main.async {
                onImageData(nil)
            }
            return UIViewController()
        }

        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.modalPresentationStyle = .fullScreen
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageData: onImageData)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImageData: (Data?) -> Void

        init(onImageData: @escaping (Data?) -> Void) {
            self.onImageData = onImageData
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImageData(nil)
            picker.dismiss(animated: true)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            let data = image?.jpegData(compressionQuality: 0.9)
            onImageData(data)
            picker.dismiss(animated: true)
        }
    }
}
