import Foundation

struct FileEntry: Codable, Sendable, Equatable {
    let relPath: String
    let name: String
    let isFolder: Bool
    let byteSize: Int?
}

enum FileError: Error, Equatable {
    case outsideSandbox, notFound, notAFolder, isFolder
    case unsupportedFormat, existsNeedsConfirmation, ioFailure(String)
}

struct FileTools: Sendable {
    let roots: [Grant]

    /// Löst „FreigabeName/rest/pfad" zu einer URL **innerhalb** dieser Freigabe auf.
    /// Liefert nil bei Fluchtversuch („..", absoluter Pfad, unbekannte Freigabe, Symlink nach außen).
    func resolve(_ relPath: String) -> URL? {
        var comps = relPath.split(separator: "/").map(String.init)
        guard let firstName = comps.first,
              let root = roots.first(where: { $0.name == firstName })
        else { return nil }
        comps.removeFirst()
        var stack: [String] = []
        for c in comps {
            if c == "." { continue }
            if c == ".." { guard !stack.isEmpty else { return nil }; stack.removeLast() }
            else { stack.append(c) }
        }
        let url = stack.reduce(root.url) { $0.appendingPathComponent($1) }
        // ponytail: Containment doppelt – lexikalisch oben, hier real (dekodiert, Symlinks aufgelöst)
        let rootPath = root.url.resolvingSymlinksInPath().path
        let realPath = url.resolvingSymlinksInPath().path
        guard realPath == rootPath || realPath.hasPrefix(rootPath + "/") else { return nil }
        return url
    }

    func list(folder relPath: String) throws -> [FileEntry] {
        guard let url = resolve(relPath) else { throw FileError.outsideSandbox }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { throw FileError.notFound }
        guard isDir.boolValue else { throw FileError.notAFolder }
        let items = try FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])
        return items
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .map { entry($0) }
    }

    private func entry(_ url: URL) -> FileEntry {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        return FileEntry(relPath: relPath(of: url), name: url.lastPathComponent,
                         isFolder: values?.isDirectory ?? false, byteSize: values?.fileSize)
    }

    func relPath(of url: URL) -> String {
        let real = url.resolvingSymlinksInPath().path
        for root in roots {
            let rootPath = root.url.resolvingSymlinksInPath().path
            guard real == rootPath || real.hasPrefix(rootPath + "/") else { continue }
            let sub = real == rootPath ? "" : String(real.dropFirst(rootPath.count + 1))
            return sub.isEmpty ? root.name : "\(root.name)/\(sub)"
        }
        return url.lastPathComponent
    }
}
