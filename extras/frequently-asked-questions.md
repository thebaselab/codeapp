# Frequently Asked Questions

### Local runtime

#### My favourite NPM / Python module doesn't work!

Many NPM / Python modules contain native components that need to be compiled when installing. These modules cannot be installed due to iOS's limitation. In addition, some modules only support desktop environment as some APIs are not available on iOS. However, you may create an issue if you want a specific module to be supported.

#### My PHP code is not running in the web privew.

The default web preview only serves static documents and does not run PHP code. To run a local PHP development server, run `php -S localhost:8000` in the terminal and visit localhost:8000 in Safari or other browsers.

### Server-side execution

#### What is server-side code execution and where do we host our server?

Server-side execution allows users to run simple programs in a large variety of programming languages. Our server is hosted on Google Cloud Platform and is based on an open source project called [judge0](https://github.com/judge0/judge0). Nothing is persisted and we don't store or access your code.

It comes with the purchase of the app as we don’t feel like a monthly subscription model suits the nature of development tools or competes with other existing services. That being said, we are shifting the focus of the app from remote to local execution. Currently, you can run Python, Node.js, PHP, C, C++ code locally. We are working on adding local support for more languages like Java.

### Version Control

#### I can't clone or push to a private repository.

You'll need to set your credentials at `Settings > Version Control > Authentication`. In many cases, you need to use a personal access token instead of the regular password. For GitHub, see [https://docs.github.com/en/github/authenticating-to-github/keeping-your-account-and-data-secure/creating-a-personal-access-token](https://docs.github.com/en/github/authenticating-to-github/keeping-your-account-and-data-secure/creating-a-personal-access-token)

#### How to clone another repository?

You'll need to set the editor's root folder to another location. You can do this by selecting the configure folder tool located in file explorer. (Folder icon with a gear)

### Remote Connection

**I can't connect to a macOS Ventura SSH server using key authentication**

Currently, there is a compatibility issue with macOS Ventura and additional configuration is needed. Please refer to [https://github.com/thebaselab/codeapp/issues/715#issuecomment-1368351403](https://github.com/thebaselab/codeapp/issues/715#issuecomment-1368351403)

### Others

#### How to change display language?

Go to iOS Settings App > Code and select a new language. Currently English, German, Korean and Chinese (_简化字)_ are supported.

**I cannot access folders in OneDrive, Dropbox or other cloud providers**

Due to a limitation of Files App's API, it is only possible to access individual files (instead of the entire folder) in cloud providers. To access these files, use the `open file` function instead of `open folder`.
