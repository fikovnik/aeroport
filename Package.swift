import PackageDescription

let package = Package(
    name: "aeroport",
        dependencies: [
            .Package(url: "https://github.com/kylef/Spectre.git", majorVersion: 0, minor: 7),
            .Package(url: "https://github.com/kylef/Commander.git", majorVersion: 0, minor: 6),
            .Package(url: "https://github.com/kylef/Stencil.git", majorVersion: 0, minor: 8),
            .Package(url: "https://github.com/sharplet/Regex", majorVersion: 0, minor: 4)
        ]
)
