//
//  NewFileView.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

struct NewFileView: View {

    @EnvironmentObject var App: MainApp

    @State var targetUrl: String
    @State private var name = ""
    @FocusState private var filenameFieldIsFocused: Bool

    @Environment(\.presentationMode) var presentationMode

    func checkNameValidity() -> Bool {
        if name.contains(":") || name.contains("/") {
            return false
        } else {
            return true
        }
    }

    func createNewFile(lang: Int, useTemplate: Bool = true) async throws {
        var content = ""

        if !useTemplate && (!checkNameValidity() || name.isEmpty) {
            filenameFieldIsFocused = true
            return
        }

        switch lang {
        case 0:
            name = "default.py"
            content = """
                # Created on \(UIDevice.current.name).

                print ('Hello World!')

                """
        case 1:
            name = "default.js"
            content = """
                // Created on \(UIDevice.current.name).

                console.log("Hello, World!")
                """
        case 3:
            name = "default.cpp"
            content = """
                // Created on \(UIDevice.current.name).

                #include <iostream>
                using namespace std;

                int main() {
                    cout << "Hello World!";
                    return 0;
                }
                """
        case 2:
            name = "default.c"
            content = """
                // Created on \(UIDevice.current.name).

                #include <stdio.h>

                int main() {
                   setbuf(stdout, NULL);
                   printf("Hello, World!");
                   return 0;
                }
                """
        case 4:
            name = "default.php"
            content = """
                // Created on \(UIDevice.current.name).

                <?php
                echo "Hello world!\n"
                ?>
                """
        case 62:
            name = "Main.java"
            content = """
                // Created on \(UIDevice.current.name).

                class Main {
                    public static void main(String[] args) {
                        System.out.println("Hello, World!");
                    }
                }
                """
        case 83:
            name = "default.swift"
            content = """
                // Created on \(UIDevice.current.name).

                import Swift
                print("Hello, World!")
                """
        case -2:
            name = "index.html"
            content = """
                <!doctype html>
                <html>
                  <head>
                    <title>Title</title>
                    <meta charset="utf-8">
                  </head>
                  <body>
                    <h1>Hello, World</h1>
                  </body>
                </html>
                """
        case -3:
            name = "style.css"
            content = """
                /* Applies to the entire body of the HTML document (except where overridden by more specific
                selectors). */
                body {
                  margin: 25px;
                  background-color: rgb(240,240,240);
                  font-family: arial, sans-serif;
                  font-size: 14px;
                }

                /* Applies to all <h1>...</h1> elements. */
                h1 {
                  font-size: 35px;
                  font-weight: normal;
                  margin-top: 5px;
                }

                /* Applies to all elements with <... class="someclass"> specified. */
                .someclass { color: red; }

                /* Applies to the element with <... id="someid"> specified. */
                #someid { color: green; }
                """
        default:
            break
        }

        guard let targetURL = URL(string: targetUrl)?.appendingPathComponent(name) else {
            throw WorkSpaceStorage.FSError.UnableToFindASuitableName
        }
        let destinationURL = try await App.workSpaceStorage.urlWithSuffixIfExistingFileExist(
            url: targetURL)

        do {
            try await App.workSpaceStorage.write(
                at: destinationURL, content: content.data(using: .utf8)!, atomically: true,
                overwrite: true
            )
            try await App.openFile(url: destinationURL)
            self.presentationMode.wrappedValue.dismiss()
        } catch {
            App.notificationManager.showErrorMessage(error.localizedDescription)
        }
    }

    struct LanguageTemplateMapping {
        let code: Int
        let name: String
    }

    let languageMapping: [LanguageTemplateMapping] = [
        .init(code: 0, name: "Python"),
        .init(code: 1, name: "JavaScript"),
        .init(code: 2, name: "C"),
        .init(code: 3, name: "C++"),
        .init(code: 4, name: "PHP"),
        .init(code: 62, name: "Java"),
        .init(code: 83, name: "Swift"),
        .init(code: -2, name: "HTML"),
        .init(code: -3, name: "CSS"),
    ]

    var body: some View {
        VStack(alignment: .leading) {
            NavigationView {
                Form {
                    Section(header: Text(NSLocalizedString("Templates", comment: ""))) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(languageMapping, id: \.code) { language in
                                    Text(language.name)
                                        .onTapGesture {
                                            Task {
                                                try await createNewFile(lang: language.code)
                                            }
                                        }
                                        .padding()
                                        .background(Color.init("B3_A"))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }

                    Section(header: Text(NSLocalizedString("Custom", comment: ""))) {
                        HStack {
                            FileIcon(url: name, iconSize: 14)
                                .frame(width: 16)
                                .fixedSize()
                            TextField(
                                "example.py", text: $name,
                                onCommit: {
                                    Task {
                                        try await createNewFile(lang: -1, useTemplate: false)
                                    }
                                }
                            )
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($filenameFieldIsFocused)

                            Spacer()
                            Button(action: {
                                Task {
                                    try await createNewFile(lang: -1, useTemplate: false)
                                }
                            }) {
                                Text(NSLocalizedString("Add File", comment: ""))
                            }

                        }

                    }

                    if !checkNameValidity() && name != "" {
                        Text("File name '\(name)' contains invalid character.")
                    }

                    Section(header: Text(NSLocalizedString("Where", comment: ""))) {
                        Text(
                            "\(targetUrl.last == "/" ? targetUrl.dropLast().components(separatedBy: "/").last!.removingPercentEncoding! : targetUrl.components(separatedBy: "/").last!.removingPercentEncoding!)"
                        )
                    }

                }.navigationBarTitle(NSLocalizedString("New File", comment: ""))
            }
            Spacer()
        }.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                filenameFieldIsFocused = true
            }
        }

    }
}
