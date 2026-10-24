import SwiftUI
import PhotosUI

@MainActor @Observable
private final class AvatarPhotoLibrary {
    var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    var assets = PHFetchResult<PHAsset>()
    var selectedID: String?
    var downloadProgress: Double?
    var error: String?
    let images = PHCachingImageManager()
    private var selectionRequest: PHImageRequestID?

    func open() async {
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard !Task.isCancelled else { return }
        refresh()
    }

    func refresh() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            assets = PHFetchResult<PHAsset>()
            return
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        assets = PHAsset.fetchAssets(with: .image, options: options)
    }

    func choose(_ asset: PHAsset, select: @escaping (UIImage) -> Void) {
        cancelSelection()
        let id = asset.localIdentifier
        selectedID = id
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        options.progressHandler = { [weak self] progress, _, _, _ in
            Task { @MainActor in
                guard let self, self.selectedID == id else { return }
                self.downloadProgress = progress
            }
        }
        // Avatar-sized stills also support HEIC and Live Photos without decoding a full original.
        selectionRequest = images.requestImage(for: asset, targetSize: CGSize(width: 1200, height: 1200),
                                               contentMode: .aspectFit, options: options) { [weak self] image, info in
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
            let cancelled = (info?[PHImageCancelledKey] as? Bool) == true
            Task { @MainActor in
                guard let self, self.selectedID == id, !degraded, !cancelled else { return }
                self.selectionRequest = nil
                self.selectedID = nil
                self.downloadProgress = nil
                if let image { select(image) }
                else { self.error = "Couldn't load this photo. Check your connection or choose another image." }
            }
        }
    }

    func cancelSelection() {
        selectedID = nil
        downloadProgress = nil
        if let selectionRequest { images.cancelImageRequest(selectionRequest) }
        selectionRequest = nil
    }

    func chooseMorePhotos() {
        guard status == .limited,
              var controller = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })?
                .windows.first(where: \.isKeyWindow)?.rootViewController else { return }
        while let presented = controller.presentedViewController { controller = presented }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
}

struct AvatarPhotoGrid: View {
    let select: (UIImage) -> Void
    @State private var library = AvatarPhotoLibrary()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { geometry in
            let side = (geometry.size.width-4)/3
            ZStack(alignment: .topTrailing) {
                if library.status == .authorized || library.status == .limited {
                    if library.assets.count == 0 {
                        statusMessage(library.status == .limited ? "No photos selected" : "No photos yet",
                                      detail: library.status == .limited ? "Choose photos for your group avatar." : "Photos in your library will appear here.") {
                            if library.status == .limited {
                                Button("Choose photos", action: library.chooseMorePhotos)
                            }
                        }
                    } else {
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                                ForEach(0..<library.assets.count, id: \.self) { index in
                                    let asset = library.assets.object(at: index)
                                    Button { library.choose(asset, select: select) } label: {
                                        AvatarPhotoThumbnail(asset: asset, images: library.images)
                                            .frame(width: side, height: side).clipped()
                                            .overlay {
                                                if library.selectedID == asset.localIdentifier {
                                                    Color.black.opacity(0.3)
                                                    ProgressView(value: library.downloadProgress).tint(.white)
                                                        .padding(20).accessibilityLabel("Loading photo")
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(library.selectedID != nil)
                                    .accessibilityLabel("Photo \(index+1)")
                                    .accessibilityIdentifier("avatar-photo-\(index)")
                                    .id(asset.localIdentifier)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        if library.status == .limited {
                            Button(action: library.chooseMorePhotos) {
                                Image(systemName: "photo.badge.plus").frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain).glassEffect(.regular.interactive(), in: Circle())
                            .padding(6).accessibilityLabel("Choose more photos")
                        }
                    }
                } else if library.status == .notDetermined {
                    ProgressView("Opening photo library…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    statusMessage("Photo access is off", detail: library.status == .restricted
                                  ? "Photo access is restricted on this iPhone."
                                  : "Allow access in Settings to choose a group avatar.") {
                        if library.status == .denied {
                            Button("Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                        }
                    }
                }
            }
        }
        .task { await library.open() }
        .onChange(of: scenePhase) { if scenePhase == .active { library.refresh() } }
        .onDisappear { library.cancelSelection(); library.images.stopCachingImagesForAllAssets() }
        .alert("Photo unavailable", isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
            Button("OK", role: .cancel) { library.error = nil }
        } message: { Text(library.error ?? "") }
    }

    private func statusMessage<Actions: View>(_ title: String, detail: String, @ViewBuilder actions: () -> Actions) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle").font(.title2)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            actions().font(.subheadline.weight(.semibold)).tint(appleBlue)
        }
        .padding(18).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AvatarPhotoThumbnail: View {
    let asset: PHAsset
    let images: PHCachingImageManager
    @State private var image: UIImage?
    @State private var request: PHImageRequestID?
    @State private var active = false

    var body: some View {
        Color.white.opacity(0.15)
            .overlay {
                if let image { Image(uiImage: image).resizable().scaledToFill() }
                else { Image(systemName: "photo").foregroundStyle(.secondary) }
            }
            .onAppear {
                active = true
                guard request == nil else { return }
                let options = PHImageRequestOptions()
                options.deliveryMode = .opportunistic
                options.resizeMode = .fast
                options.isNetworkAccessAllowed = true
                request = images.requestImage(for: asset, targetSize: CGSize(width: 320, height: 320),
                                              contentMode: .aspectFill, options: options) { result, _ in
                    Task { @MainActor in if active, let result { image = result } }
                }
            }
            .onDisappear {
                active = false
                if let request { images.cancelImageRequest(request) }
                request = nil
            }
    }
}
