// RemoteImage.swift
// A drop-in for AsyncImage that loads through URLSession.shared and keeps
// decoded images in memory.
//
// Two reasons it exists:
//   1. AsyncImage uses its own session, which ignores URLProtocol classes
//      registered on the shared session. With the mock backend that meant
//      every cover 404'd into a letter placeholder.
//   2. AsyncImage has no memory cache, so covers re-download and flash as
//      the shelf scrolls. ImageLoader caches by URL.
//
// Same closure shape as AsyncImage, so call sites only change the type name.

import SwiftUI
import UIKit

struct RemoteImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url else { phase = .empty; return }
                if let cached = ImageLoader.shared.cached(url) {
                    phase = .success(Image(uiImage: cached))
                    return
                }
                phase = .empty
                do {
                    let image = try await ImageLoader.shared.load(url)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        phase = .success(Image(uiImage: image))
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    phase = .failure(error)
                }
            }
    }
}

/// Fetches and caches images. Concurrent requests for the same URL share
/// one download.
actor ImageLoader {
    static let shared = ImageLoader()

    enum LoadError: Error { case notAnImage }

    // NSCache is thread-safe, so it can be read outside the actor for the
    // synchronous first-paint check.
    private nonisolated(unsafe) let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = 300
    }

    /// Synchronous cache hit for first paint. Safe to call from any isolation.
    nonisolated func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func load(_ url: URL) async throws -> UIImage {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        if let running = inFlight[url] { return try await running.value }

        let task = Task<UIImage, Error> { [session] in
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else { throw LoadError.notAnImage }
            return image
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }

        let image = try await task.value
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
