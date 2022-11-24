---
description: >-
  Code App is a MIT-licensed desktop-class code editor for iPadOS with built-in
  Node.js, Python, C, C++, PHP runtime.
---

# Code App Documentation

We built it because there is nothing else on the App Store provides all these features in one app:

* A robust, high-performance text editor (Monaco Editor from Visual Studio Code)
* First class local file system support
* Embedded emulated terminal
* Local backend development environment (Node and PHP)
* Local Python Runtime
* Local Clang compiler
* Git Version Control
* Package manager support (Pip and NPM)
* Remote connection support (Files and terminal)

{% hint style="info" %}
**Good to know:** While we want to make the editing experience as close as a desktop offers, Code App is still bounded by iOS's limitations. For example, you cannot download arbitary commands or modules with native components. Spawning subprocesses is also not possible.
{% endhint %}

![Compiling a C++ file with Clang](<.gitbook/assets/image (1) (1) (1) (1).png>)

## Getting Started

### Installation

You can either install the app from App Store or TestFlight.

{% embed url="https://apps.apple.com/us/app/code-app/id1512938504" %}
Link to App Store ($5.99)
{% endembed %}

{% embed url="https://testflight.apple.com/join/EgZ8sE2P" %}
Link to TestFlight (Free)
{% endembed %}

Or if you'd like to get your hands dirty (Requires a Mac with Xcode installed) :&#x20;

{% content-ref url="extras/building-code-from-source.md" %}
[building-code-from-source.md](extras/building-code-from-source.md)
{% endcontent-ref %}

{% embed url="https://github.com/thebaselab/codeapp" %}
Link to our repo
{% endembed %}

### Jump right in

Follow these guides to get started on the basics:

{% content-ref url="guides/your-first-program-in-python.md" %}
[your-first-program-in-python.md](guides/your-first-program-in-python.md)
{% endcontent-ref %}

{% content-ref url="guides/version-control.md" %}
[version-control.md](guides/version-control.md)
{% endcontent-ref %}

{% content-ref url="guides/connecting-to-a-remote-server-ssh-ftp.md" %}
[connecting-to-a-remote-server-ssh-ftp.md](guides/connecting-to-a-remote-server-ssh-ftp.md)
{% endcontent-ref %}
