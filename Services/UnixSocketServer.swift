import Foundation
import Darwin

/// Kleine lokale server waar agents (via hun hook-script) gebeurtenissen naartoe sturen.
/// Alleen jijzelf kunt erbij: het socketbestand is 0600 en elke verbinding wordt op gebruikers-ID gecontroleerd.
final class UnixSocketServer {
    private let path: String
    private var listenFD: Int32 = -1
    private let acceptQueue = DispatchQueue(label: "nl.imdigital.nook.hub.accept")
    private let clientQueue = DispatchQueue(label: "nl.imdigital.nook.hub.client", attributes: .concurrent)

    /// Wordt aangeroepen met één regel JSON. Roep de tweede closure aan om te antwoorden (of met nil om zonder antwoord af te sluiten).
    var onMessage: ((Data, @escaping (Data?) -> Void) -> Void)?

    init(path: String) {
        self.path = path
    }

    func start() throws {
        signal(SIGPIPE, SIG_IGN)
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw NookError("Socket maken mislukt.") }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8CString)
        guard bytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            close(fd)
            throw NookError("Pad naar de socket is te lang.")
        }
        withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            for (index, byte) in bytes.enumerated() {
                raw[index] = UInt8(bitPattern: byte)
            }
        }

        let length = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, length) }
        }
        guard bound == 0 else {
            close(fd)
            throw NookError("Socket koppelen mislukt (\(String(cString: strerror(errno)))).")
        }
        chmod(path, 0o600)

        guard listen(fd, 16) == 0 else {
            close(fd)
            throw NookError("Luisteren op de socket mislukt.")
        }
        listenFD = fd
        acceptQueue.async { [weak self] in self?.acceptLoop(fd) }
    }

    func stop() {
        if listenFD >= 0 {
            close(listenFD)
            listenFD = -1
        }
        unlink(path)
    }

    private func acceptLoop(_ fd: Int32) {
        while true {
            let client = accept(fd, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                break
            }
            clientQueue.async { [weak self] in self?.handle(client) }
        }
    }

    private func handle(_ fd: Int32) {
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard getpeereid(fd, &uid, &gid) == 0, uid == getuid() else {
            close(fd)
            return
        }

        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 65_536)
        while buffer.count < 4_000_000 {
            let count = read(fd, &chunk, chunk.count)
            if count <= 0 { break }
            buffer.append(chunk, count: count)
            if chunk[0..<count].contains(10) { break }
        }

        guard !buffer.isEmpty, let handler = onMessage else {
            close(fd)
            return
        }

        handler(buffer) { response in
            if var data = response {
                data.append(10)
                data.withUnsafeBytes { raw in
                    guard let base = raw.baseAddress else { return }
                    var offset = 0
                    while offset < raw.count {
                        let written = write(fd, base + offset, raw.count - offset)
                        if written <= 0 { break }
                        offset += written
                    }
                }
            }
            close(fd)
        }
    }
}
