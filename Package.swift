import PackageDescription

let package = Package(
    name: "aeroport",
        dependencies: [
            .Package(url: "https://github.com/Ponyboy47/Commander.git", majorVersion: 0, minor: 7),
            .Package(url: "https://github.com/kylef/Stencil.git", majorVersion: 0, minor: 8),
            .Package(url: "https://github.com/sharplet/Regex.git", majorVersion: 0, minor: 4)
        ]
)
