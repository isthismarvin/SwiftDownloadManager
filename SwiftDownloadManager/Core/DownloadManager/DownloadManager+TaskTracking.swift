import Foundation

extension DownloadManager {
    func cancelMetadataProbe(for id: UUID) {
        metadataProbeTasks[id]?.cancel()
        metadataProbeGeneration[id] = (metadataProbeGeneration[id] ?? 0) &+ 1
        metadataProbeTasks.removeValue(forKey: id)
    }

    func cancelPrepareDownload(for id: UUID) {
        prepareDownloadTasks[id]?.cancel()
        prepareDownloadGeneration[id] = (prepareDownloadGeneration[id] ?? 0) &+ 1
        prepareDownloadTasks.removeValue(forKey: id)
    }

    func clearMetadataProbeTaskIfCurrent(id: UUID, generation: UInt64) {
        guard metadataProbeGeneration[id] == generation else { return }
        metadataProbeTasks.removeValue(forKey: id)
        metadataProbeGeneration.removeValue(forKey: id)
    }

    func clearPrepareDownloadTaskIfCurrent(id: UUID, generation: UInt64) {
        guard prepareDownloadGeneration[id] == generation else { return }
        prepareDownloadTasks.removeValue(forKey: id)
        prepareDownloadGeneration.removeValue(forKey: id)
    }

    @discardableResult
    func enqueueMetadataProbe(for id: UUID) -> Task<Void, Never> {
        metadataProbeTasks[id]?.cancel()
        let generation = (metadataProbeGeneration[id] ?? 0) &+ 1
        metadataProbeGeneration[id] = generation
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.probeMetadata(for: id, generation: generation)
        }
        metadataProbeTasks[id] = task
        return task
    }

    func enqueuePrepareDownload(id: UUID, url: URL) {
        prepareDownloadTasks[id]?.cancel()
        let generation = (prepareDownloadGeneration[id] ?? 0) &+ 1
        prepareDownloadGeneration[id] = generation
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.prepareAndStartDownload(id: id, url: url, generation: generation)
        }
        prepareDownloadTasks[id] = task
    }

    func isProbeableStatus(_ status: DownloadStatus) -> Bool {
        status == .received || status == .pendingConfirmation
    }
}
