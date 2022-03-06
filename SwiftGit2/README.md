# SwiftGit2
[![Build Status](https://travis-ci.org/SwiftGit2/SwiftGit2.svg)](https://travis-ci.org/SwiftGit2/SwiftGit2)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](#carthage)
[![GitHub release](https://img.shields.io/github/release/SwiftGit2/SwiftGit2.svg)](https://github.com/SwiftGit2/SwiftGit2/releases)
![Swift 5.3.x](https://img.shields.io/badge/Swift-5.3.x-orange.svg)

Swift bindings to [libgit2](https://github.com/libgit2/libgit2).

```swift
let URL: URL = ...
let result = Repository.at(URL)
switch result {
case let .success(repo):
    let latestCommit = repo
        .HEAD()
        .flatMap {
            repo.commit($0.oid)
        }

    switch latestCommit {
    case let .success(commit):
        print("Latest Commit: \(commit.message) by \(commit.author.name)")

    case let .failure(error):
        print("Could not get commit: \(error)")
    }

case let .failure(error):
    print("Could not open repository: \(error)")
}
```

See [our iOS example app project](https://github.com/light-tech/SwiftGit2-SampleApp) to see the code in action.

## Design
SwiftGit2 uses value objects wherever possible. That means using Swift's `struct`s and `enum`s without holding references to libgit2 objects. This has a number of advantages:

1. Values can be used concurrently.
2. Consuming values won't result in disk access.
3. Disk access can be contained to a smaller number of APIs.

This vastly simplifies the design of long-lived applications, which are the most common use case with Swift. Consequently, SwiftGit2 APIs don't necessarily map 1-to-1 with libgit2 APIs.

All methods for reading from or writing to a repository are on SwiftGit2's only `class`: `Repository`. This highlights the failability and mutation of these methods, while freeing up all other instances to be immutable `struct`s and `enum`s.

## Adding SwiftGit2 to your Project
The easiest way to add SwiftGit2 to your project is to [add our repository as a Swift package](https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app).

Note that **you need to choose `spm` branch of our fork https://github.com/light-tech/SwiftGit2 which was configured to be compatible with Swift package manager**. NEITHER the original repository https://github.com/SwiftGit2/SwiftGit2 nor other branch of our fork support Swift package manager as of this writing.

You also need to add `libz.tbd` and `libiconv.tbd` to the app target's **Frameworks, Libraries and Embedded Content**.

Before using any of the SwiftGit2 API, add
```swift
Repository.initialize_libgit2()
```
to your app initialization method.

Check out [our iOS example app project](https://github.com/light-tech/SwiftGit2-SampleApp) for a starting point.

## Contributions
We :heart: to receive pull requests! GitHub makes it easy:

1. Fork the repository
2. Create a branch with your changes
3. Send a Pull Request

All contributions should match GitHub's [Swift Style Guide](https://github.com/github/swift-style-guide).

## License
SwiftGit2 is available under the MIT license.
