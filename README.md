# Code App
Bringing desktop-like editing expereince to iPad, available on App Store: https://apps.apple.com/us/app/code-app/id1512938504

![Code App Screenshot](https://thebaselab.com/code/clang.png)

## About the repository
This repository contains the source code of the app.  We also work on issues, listen to your feedback and publish our development plan here.

## Documentation
See [Wiki](https://github.com/thebaselab/codeapp/wiki)

## The Plan
Use [VS Code](https://github.com/microsoft/vscode) as a design template while providing key functionalities with native code:
- Version Control (Git clone, commits, diff editor, push, pull and gutter indicator) ✅
- Embeded terminal (70+ commands avaliable) ✅
- Local web development environment (Node + PHP) ✅
- Built in Python runtime ✅
- C/C++ Runtime with WebAssembly (with clang support) ✅
- SSH Support 🏃
- [LSP](https://microsoft.github.io/language-server-protocol) support 🏃

### Building the project
- `sh downloadFrameworks.sh`
- Open Code.xcworkspace
- Select project from file navigator
- Signing & Capabilities -> select your own team
- Change Bundle Identifier if needed
- Build and install on a real device
