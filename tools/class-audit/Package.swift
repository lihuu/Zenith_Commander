// swift-tools-version: 5.9
// tools/zc-class-audit/Package.swift

import PackageDescription

let package = Package(
    name: "ZCClassAudit",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ZCClassAudit", targets: ["ZCClassAudit"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "510.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ZCClassAudit",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        )
    ]
)
