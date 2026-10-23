import Foundation
import PDFKit

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
            .sorted { $0.relPath < $1.relPath }          // Ruling R8: deterministische Reihenfolge
    }

    private func entry(_ url: URL) -> FileEntry {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        return FileEntry(relPath: relPath(of: url), name: url.lastPathComponent,
                         isFolder: values?.isDirectory ?? false,
                         byteSize: (values?.isDirectory ?? false) ? nil : values?.fileSize)   // R8
    }

    static let maxReadBytes = 200_000
    static let textExtensions: Set<String> = ["txt","md","csv","json","log","swift","py","html","xml","yml","yaml"]

    func read(_ relPath: String) throws -> String {
        guard let url = resolve(relPath) else { throw FileError.outsideSandbox }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { throw FileError.notFound }
        if isDir.boolValue { throw FileError.isFolder }
        let ext = url.pathExtension.lowercased()
        let content: String
        if ext == "pdf" {
            guard let doc = PDFDocument(url: url), let text = doc.string, !text.isEmpty else { throw FileError.unsupportedFormat }
            content = text
        } else if Self.textExtensions.contains(ext) {
            let data = FileManager.default.contents(atPath: url.path) ?? Data()
            if data.count > Self.maxReadBytes {
                return String(decoding: data.prefix(Self.maxReadBytes), as: UTF8.self)
                    + "\n[… Datei zu groß, Rest abgeschnitten]"
            }
            content = String(decoding: data, as: UTF8.self)
        } else { throw FileError.unsupportedFormat }
        if content.count > Self.maxReadBytes {
            return String(content.prefix(Self.maxReadBytes)) + "\n[… Datei zu groß, Rest abgeschnitten]"
        }
        return content
    }

    func search(nameContains: String, contentContains: String?) throws -> [FileEntry] {
        var hits: [FileEntry] = []
        for root in roots {
            let enums = FileManager.default.enumerator(at: root.url, includingPropertiesForKeys: [.isDirectoryKey])
            while let raw = enums?.nextObject() as? URL {
                let name = raw.lastPathComponent
                if name.hasPrefix(".") { continue }
                if !nameContains.isEmpty && !name.localizedCaseInsensitiveContains(nameContains) { continue }
                if let contentContains, !contentContains.isEmpty {
                    let rel = relPath(of: raw)
                    guard let text = try? read(rel), text.localizedCaseInsensitiveContains(contentContains) else { continue }
                }
                hits.append(entry(raw))
            }
        }
        return hits.sorted { $0.relPath < $1.relPath }
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

    @discardableResult
    func write(_ relPath: String, content: String, overwrite: Bool, backupDir: URL) throws -> ActionCard? {
        guard let checked = resolve(relPath) else { throw FileError.outsideSandbox }
        let url = checked.resolvingSymlinksInPath()   // R8: Operation auf exakt dem geprüften Pfad
        let exists = FileManager.default.fileExists(atPath: url.path)
        if exists && !overwrite { throw FileError.existsNeedsConfirmation }
        var backupCard: ActionCard? = nil
        if exists {
            try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            let backupURL = backupDir.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
            try FileManager.default.copyItem(at: url, to: backupURL)
            backupCard = ActionCard(id: UUID(), kind: .backup, actor: nil, title: "Sicherung vor Überschreiben",
                                    detail: backupURL.lastPathComponent, durationMS: nil, createdAt: Date())
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return backupCard
    }

    func rename(_ relPath: String, to newName: String) throws -> String {
        guard let checked = resolve(relPath) else { throw FileError.outsideSandbox }
        guard !newName.contains("/"), !newName.hasPrefix(".") else { throw FileError.outsideSandbox }
        let url = checked.resolvingSymlinksInPath()   // R8
        guard FileManager.default.fileExists(atPath: url.path) else { throw FileError.notFound }
        let target = url.deletingLastPathComponent().appendingPathComponent(newName)
        guard !FileManager.default.fileExists(atPath: target.path) else { throw FileError.existsNeedsConfirmation }
        do { try FileManager.default.moveItem(at: url, to: target) }
        catch { throw FileError.ioFailure(error.localizedDescription) }
        return self.relPath(of: target)
    }

    func move(_ relPath: String, toFolder: String) throws -> String {
        guard let checked = resolve(relPath) else { throw FileError.outsideSandbox }
        guard let checkedFolder = resolve(toFolder) else { throw FileError.outsideSandbox }
        let url = checked.resolvingSymlinksInPath()   // R8
        let folderURL = checkedFolder.resolvingSymlinksInPath()
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue else { throw FileError.notAFolder }
        let target = folderURL.appendingPathComponent(url.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: target.path) else { throw FileError.existsNeedsConfirmation }
        do { try FileManager.default.moveItem(at: url, to: target) }
        catch { throw FileError.ioFailure(error.localizedDescription) }
        return self.relPath(of: target)
    }
}
