import Darwin
import Foundation

let homeDirectory = ProcessInfo.processInfo.environment["HOME"]
    .map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? FileManager.default.homeDirectoryForCurrentUser
let socketPath = homeDirectory.appendingPathComponent("Library/Application Support/DayTrace/Spike/daytrace.sock").path

func readExactly(_ length: Int) -> Data? {
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: length)
    while result.count < length {
        let count = read(STDIN_FILENO, &buffer, length - result.count)
        guard count > 0 else { return nil }
        result.append(buffer, count: count)
    }
    return result
}

func writeMessage(_ object: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
    var length = UInt32(data.count).littleEndian
    withUnsafeBytes(of: &length) { _ = write(STDOUT_FILENO, $0.baseAddress!, $0.count) }
    data.withUnsafeBytes { _ = write(STDOUT_FILENO, $0.baseAddress!, $0.count) }
}

func connectToApp() -> Int32? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
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
    let result = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    guard result == 0 else {
        close(fd)
        return nil
    }
    return fd
}

func isSafeDomainToken(_ domain: String) -> Bool {
    if ["Browser Internal", "Local File", "Unknown"].contains(domain) { return true }
    guard domain.count <= 253, !domain.isEmpty else { return false }
    return domain.split(separator: ".").allSatisfy { label in
        !label.isEmpty && label.count <= 63 && label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}

while let header = readExactly(4) {
    let length = header.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
    guard length > 0, length <= 64 * 1024, let body = readExactly(Int(length)),
          let object = try? JSONSerialization.jsonObject(with: body),
          let payload = object as? [String: Any],
          Set(payload.keys) == ["schemaVersion", "type", "domain"],
          payload["schemaVersion"] as? Int == 1,
          payload["type"] as? String == "activeDomainChanged",
          let domain = payload["domain"] as? String,
          isSafeDomainToken(domain) else {
        writeMessage(["schemaVersion": 1, "type": "ack", "accepted": false])
        continue
    }

    guard let fd = connectToApp() else {
        writeMessage(["schemaVersion": 1, "type": "ack", "accepted": false, "reason": "hostUnavailable"])
        continue
    }
    // Rebuild the payload so unexpected fields (including a full URL) never cross the IPC boundary.
    let message: [String: Any] = [
        "schemaVersion": 1,
        "type": "activeDomainChanged",
        "domain": domain
    ]
    if let data = try? JSONSerialization.data(withJSONObject: message) {
        var line = data
        line.append(10)
        line.withUnsafeBytes { _ = write(fd, $0.baseAddress!, $0.count) }
        writeMessage(["schemaVersion": 1, "type": "ack", "accepted": true])
    } else {
        writeMessage(["schemaVersion": 1, "type": "ack", "accepted": false])
    }
    close(fd)
}
