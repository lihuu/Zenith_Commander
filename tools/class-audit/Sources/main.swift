// tools/zc-class-audit/Sources/ZCClassAudit/main.swift
import Foundation
import SwiftParser
import SwiftSyntax

// MARK: - Models

struct Finding: Codable {
    let file: String
    let lineStart: Int
    let lineEnd: Int

    let name: String
    let kind: String  // "class"

    let isFinal: Bool
    let inherits: [String]
    let conforms: [String]

    let hasDeinit: Bool
    let hasObjCAttribute: Bool
    let hasMainActor: Bool
    let isNSObjectLike: Bool
    let isObservableObjectLike: Bool

    let storedLetCount: Int
    let storedVarCount: Int
    let weakCount: Int
    let unownedCount: Int

    let usesTask: Bool
    let usesContinuation: Bool

    let heuristicScore: Int
    let notes: [String]
}

struct Report: Codable {
    let generatedAt: String
    let root: String
    let swiftFilesScanned: Int
    let findings: [Finding]
}

// MARK: - CLI args

struct Args {
    let root: String
    let out: String

    static func parse() -> Args {
        var root: String?
        var out: String?

        var it = CommandLine.arguments.dropFirst().makeIterator()
        while let a = it.next() {
            switch a {
            case "--root":
                root = it.next()
            case "--out":
                out = it.next()
            default:
                break
            }
        }

        let defaultRoot = FileManager.default.currentDirectoryPath
        return Args(
            root: root ?? defaultRoot,
            out: out ?? "class_audit.json"
        )
    }
}

// MARK: - Utilities

func collectSwiftFiles(root: String) -> [String] {
    let fm = FileManager.default
    let rootURL = URL(fileURLWithPath: root)

    guard
        let en = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
    else { return [] }

    var paths: [String] = []
    for case let url as URL in en {
        if url.pathExtension == "swift" {
            paths.append(url.path)
        }
    }
    return paths
}

func lineMap(for source: String) -> [Int] {
    // returns array of offsets where each line starts
    var starts: [Int] = [0]
    var idx = 0
    for ch in source {
        idx += ch.utf8.count
        if ch == "\n" {
            starts.append(idx)
        }
    }
    return starts
}

func offsetToLine(_ offset: Int, lineStarts: [Int]) -> Int {
    // 1-based line number
    // binary search last lineStart <= offset
    var lo = 0
    var hi = lineStarts.count - 1
    while lo <= hi {
        let mid = (lo + hi) / 2
        if lineStarts[mid] <= offset {
            lo = mid + 1
        } else {
            hi = mid - 1
        }
    }
    return max(1, hi + 1)
}

func nodeLineRange(_ node: SyntaxProtocol, sourceUTF8Count: Int, lineStarts: [Int]) -> (Int, Int) {
    let pos = node.position.utf8Offset
    let end = node.endPosition.utf8Offset
    let ls = offsetToLine(min(pos, sourceUTF8Count), lineStarts: lineStarts)
    let le = offsetToLine(min(end, sourceUTF8Count), lineStarts: lineStarts)
    return (ls, le)
}

func typeNames(from inheritanceClause: InheritanceClauseSyntax?) -> [String] {
    guard let inheritanceClause else { return [] }
    return inheritanceClause.inheritedTypes.map { inherited in
        inherited.type.trimmedDescription
    }
}

// MARK: - Visitor

final class ClassCollector: SyntaxVisitor {
    let filePath: String
    let source: String
    let lineStarts: [Int]
    let sourceUTF8Count: Int

    var findings: [Finding] = []

    init(filePath: String, source: String) {
        self.filePath = filePath
        self.source = source
        self.lineStarts = lineMap(for: source)
        self.sourceUTF8Count = source.utf8.count
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let (lineStart, lineEnd) = nodeLineRange(
            node, sourceUTF8Count: sourceUTF8Count, lineStarts: lineStarts)

        let modifiers = node.modifiers.map { $0.name.text }
        let isFinal = modifiers.contains("final")

        let inherited = typeNames(from: node.inheritanceClause)
        let inherits = inherited  // base + protocols mixed; we’ll heuristically split below
        let conforms = inherited

        // Attributes: @MainActor, @objc
        let attrs =
            node.attributes.compactMap { attr -> String? in
                if let a = attr.as(AttributeSyntax.self) {
                    return a.attributeName.trimmedDescription
                }
                return nil
            }

        let hasObjC = attrs.contains("objc") || attrs.contains("objcMembers")
        let hasMainActor = attrs.contains("MainActor")

        // Body scan: deinit, stored properties, weak/unowned, Task, continuation
        var hasDeinit = false
        var storedLet = 0
        var storedVar = 0
        var weakCount = 0
        var unownedCount = 0
        var usesTask = false
        var usesContinuation = false

        if let members = node.memberBlock.members as MemberBlockItemListSyntax? {
            for m in members {
                if m.decl.is(DeinitializerDeclSyntax.self) { hasDeinit = true }

                if let v = m.decl.as(VariableDeclSyntax.self) {
                    let bindingSpec = v.bindingSpecifier.text  // "let" or "var"
                    let isStored = v.bindings.contains { b in
                        // stored if no accessor block (computed has accessor)
                        b.accessorBlock == nil
                    }
                    if isStored {
                        if bindingSpec == "let" { storedLet += v.bindings.count }
                        if bindingSpec == "var" { storedVar += v.bindings.count }
                    }

                    // weak/unowned
                    let vmods = v.modifiers.map { $0.name.text }
                    weakCount += vmods.filter { $0 == "weak" }.count
                    unownedCount += vmods.filter { $0 == "unowned" }.count
                }

                // crude but effective token scan inside member decl text
                let text = m.decl.trimmedDescription
                if text.contains("Task {") || text.contains("Task.detached") { usesTask = true }
                if text.contains("withCheckedContinuation")
                    || text.contains("withCheckedThrowingContinuation")
                {
                    usesContinuation = true
                }
            }
        }

        let isNSObjectLike =
            inherits.contains("NSObject") || inherits.contains("NSResponder")
            || inherits.contains("NSView") || inherits.contains("NSViewController")
        let isObservableObjectLike = inherits.contains("ObservableObject")

        // Heuristic score (higher => more likely "can be struct")
        // This is only ranking; final decision is semantic.
        var score = 0
        var notes: [String] = []

        if isFinal { score += 2 } else { notes.append("非 final class：若无继承需求，考虑标 final 或改 struct") }
        if inherits.isEmpty {
            score += 3
            notes.append("无继承/协议列表：更像纯工具类")
        } else {
            // still can be struct if only protocol conforms, but not if NSObject-like
            notes.append("存在继承/协议：需要结合语义判断")
        }
        if !hasDeinit { score += 3 } else { notes.append("存在 deinit：通常说明需要生命周期清理，class 更合理") }
        if storedVar == 0 { score += 3 } else { notes.append("存在存储 var：可能是共享可变状态（不一定，但需人工确认）") }
        if weakCount == 0 && unownedCount == 0 {
            score += 2
        } else {
            notes.append("存在 weak/unowned：高度依赖引用语义，不建议改 struct")
        }
        if !hasObjC { score += 2 } else { notes.append("存在 @objc：通常需要 class/ObjC runtime") }
        if !hasMainActor { score += 1 } else { notes.append("@MainActor：可能是 UI/状态对象，改 struct 要谨慎") }

        if isNSObjectLike {
            score -= 10
            notes.append("NSObject/AppKit 体系：通常必须 class")
        }
        if isObservableObjectLike {
            score -= 10
            notes.append("ObservableObject：通常必须 class")
        }

        if usesTask { notes.append("包含 Task：注意捕获/生命周期与 Sendable") }
        if usesContinuation { notes.append("包含 continuation：必须保证 exactly-once resume") }

        let finding = Finding(
            file: filePath,
            lineStart: lineStart,
            lineEnd: lineEnd,
            name: name,
            kind: "class",
            isFinal: isFinal,
            inherits: inherits,
            conforms: conforms,
            hasDeinit: hasDeinit,
            hasObjCAttribute: hasObjC,
            hasMainActor: hasMainActor,
            isNSObjectLike: isNSObjectLike,
            isObservableObjectLike: isObservableObjectLike,
            storedLetCount: storedLet,
            storedVarCount: storedVar,
            weakCount: weakCount,
            unownedCount: unownedCount,
            usesTask: usesTask,
            usesContinuation: usesContinuation,
            heuristicScore: score,
            notes: notes
        )

        findings.append(finding)
        return .skipChildren
    }
}

// MARK: - Main

let args = Args.parse()
let root = URL(fileURLWithPath: args.root).standardizedFileURL.path
let files = collectSwiftFiles(root: root)

var all: [Finding] = []

for path in files {
    guard let data = FileManager.default.contents(atPath: path),
        let src = String(data: data, encoding: .utf8)
    else { continue }

    let tree = Parser.parse(source: src)
    let collector = ClassCollector(filePath: path, source: src)
    collector.walk(tree)
    all.append(contentsOf: collector.findings)
}

// Sort by score desc, then file/name
all.sort {
    if $0.heuristicScore != $1.heuristicScore { return $0.heuristicScore > $1.heuristicScore }
    if $0.file != $1.file { return $0.file < $1.file }
    return $0.name < $1.name
}

let report = Report(
    generatedAt: ISO8601DateFormatter().string(from: Date()),
    root: root,
    swiftFilesScanned: files.count,
    findings: all
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let outURL = URL(fileURLWithPath: args.out, isDirectory: false)

do {
    let json = try encoder.encode(report)
    try json.write(to: outURL)
    print("✅ Wrote report: \(outURL.path)")
    print("   Swift files scanned: \(files.count)")
    print("   Classes found: \(all.count)")
} catch {
    fputs("❌ Failed to write report: \(error)\n", stderr)
    exit(1)
}
