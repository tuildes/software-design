// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocacaoEspacos",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "LocacaoEspacos", targets: ["LocacaoEspacos"]),
        .executable(name: "locacao-espacos", targets: ["App"]),
    ],
    targets: [
        .target(
            name: "LocacaoEspacos",
            path: "src",
            exclude: ["App", "README.md"],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .executableTarget(
            name: "App",
            dependencies: ["LocacaoEspacos"],
            path: "src/App"
        ),
        .testTarget(
            name: "LocacaoEspacosTests",
            dependencies: ["LocacaoEspacos"],
            path: "Tests/LocacaoEspacosTests"
        ),
    ]
)
