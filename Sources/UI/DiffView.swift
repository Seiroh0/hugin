import SwiftUI

struct DiffLine: Equatable {
    let sign: Character   // " ", "+", "-"
    let text: String
}

struct DiffView: View {
    let old: String?
    let new: String

    static func compute(old: String?, new: String) -> [DiffLine] {
        // UI-Schutz: LLM-Output ist untrusted – Diff kappen statt Dialog einfrieren
        let maxLines = 300
        let maxCharsPerLine = 1_000
        func cap(_ s: String) -> [String] {
            let lines = s.components(separatedBy: "\n")
            var capped = lines.prefix(maxLines).map { line in
                line.count > maxCharsPerLine
                    ? String(line.prefix(maxCharsPerLine)) + " …" : line
            }
            if lines.count > maxLines { capped.append("… (\(lines.count - maxLines) weitere Zeilen gekürzt)") }
            return Array(capped)
        }
        let oldLines = old.map { cap($0) } ?? []
        let newLines = cap(new)
        // Gemeinsamen Präfix/SUFFIX kappen (ponytail: einfacher Zeilen-Diff, kein LCS)
        var prefix = 0
        while prefix < oldLines.count && prefix < newLines.count && oldLines[prefix] == newLines[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < oldLines.count - prefix && suffix < newLines.count - prefix
                && oldLines[oldLines.count - 1 - suffix] == newLines[newLines.count - 1 - suffix] {
            suffix += 1
        }
        var result: [DiffLine] = []
        for i in 0..<prefix { result.append(DiffLine(sign: " ", text: newLines[i])) }
        for i in prefix..<(oldLines.count - suffix) { result.append(DiffLine(sign: "-", text: oldLines[i])) }
        for i in prefix..<(newLines.count - suffix) { result.append(DiffLine(sign: "+", text: newLines[i])) }
        for i in (newLines.count - suffix)..<newLines.count { result.append(DiffLine(sign: " ", text: newLines[i])) }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Self.compute(old: old, new: new).enumerated()), id: \.offset) { _, line in
                HStack(spacing: 14) {
                    Text(String(line.sign)).frame(width: 10)
                    Text(line.text)
                }
                .font(HuginFont.geistMono(13))
                // Design §5.4: − Text hell (Rost-Ton), + Text Knochen, Kontext Asche; Tint nur im Hintergrund
                .foregroundStyle(line.sign == "-" ? HuginColor.rostText
                                 : line.sign == "+" ? HuginColor.knochen
                                 : HuginColor.asche)
                .padding(.horizontal, 18).padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(line.sign == "-" ? HuginColor.rost.opacity(0.10)
                           : line.sign == "+" ? HuginColor.frost.opacity(0.07) : .clear)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x0F1013))
            .stroke(HuginColor.border1))
    }
}
