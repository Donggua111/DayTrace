import Combine
import Darwin
import Foundation

final class UnixSocketBridge: ObservableObject {
    @Published private(set) var status: IPCStatus = .waiting
    var onStatusChanged: ((IPCStatus) -> Void)?

    private let queue = DispatchQueue(label: "com.daytrace.spike.unix-socket", qos: .utility)
    private let messageHandler: (String) -> Void
    private var serverSocket: Int32 = -1
    private var socketPath: String { DayTraceStorageLocations.socketURL.path }

    init(messageHandler: @escaping (String) -> Void) {
        self.messageHandler = messageHandler
    }

    deinit { stop() }

    func start() {
        DispatchQueue.main.async { [weak self] in
            self?.status = self?.hostManifestExists == true ? .waiting : .notConfigured
        }
        queue.async { [weak self] in self?.runServer() }
    }

    func stop() {
        let socket = serverSocket
        if socket >= 0 { Darwin.close(socket) }
        serverSocket = -1
        unlink(socketPath)
        publishStatus(.waiting)
    }

    private var hostManifestExists: Bool {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome/NativeMessagingHosts/com.daytrace.spike.json")
        return FileManager.default.fileExists(atPath: path.path)
    }

    private func runServer() {
        let directory = URL(fileURLWithPath: socketPath).deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        } catch {
            publishStatus(.error)
            return
        }

        unlink(socketPath)
        let socketFD = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            publishStatus(.error)
            return
        }
        serverSocket = socketFD

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.utf8) + [0]
        let sunPathCapacity = MemoryLayout.size(ofValue: address.sun_path)
        withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: UInt8.self, capacity: sunPathCapacity) { destination in
                for (index, byte) in pathBytes.prefix(sunPathCapacity).enumerated() {
                    destination[index] = byte
                }
            }
        }

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0, Darwin.listen(socketFD, 4) == 0 else {
            publishStatus(.error)
            Darwin.close(socketFD)
            serverSocket = -1
            return
        }
        chmod(socketPath, 0o600)
        publishStatus(hostManifestExists ? .waiting : .notConfigured)

        while serverSocket == socketFD {
            let client = accept(socketFD, nil, nil)
            guard client >= 0 else { break }
            handle(client: client)
            Darwin.close(client)
            publishStatus(hostManifestExists ? .waiting : .notConfigured)
        }
    }

    private func handle(client: Int32) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var data = Data()
        while true {
            let count = read(client, &buffer, buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
            while let newline = data.firstIndex(of: 10) {
                let line = data.prefix(upTo: newline)
                data.removeSubrange(...newline)
                guard let object = try? JSONSerialization.jsonObject(with: line),
                      let payload = object as? [String: Any],
                      Set(payload.keys) == ["schemaVersion", "type", "domain"],
                      payload["schemaVersion"] as? Int == 1,
                      payload["type"] as? String == "activeDomainChanged",
                      let domain = payload["domain"] as? String else { continue }
                publishStatus(.connected)
                messageHandler(domain)
            }
        }
    }

    private func publishStatus(_ value: IPCStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.status = value
            self.onStatusChanged?(value)
        }
    }
}
