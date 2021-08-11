//
//  newFile.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

struct newFileView: View {
    
    @EnvironmentObject var App: MainApp
    
    @State var targetUrl: String
    @State private var name = ""
    
    @Environment(\.presentationMode) var presentationMode
    
    func returnFileName(defaultName: String, extensionName: String) -> String{
        var num = 2
        
        func checkFileExist(fileName: String) -> Bool{
            
            let url = URL(string: targetUrl)?.appendingPathComponent(fileName)
            return FileManager.default.fileExists(atPath: url!.path)
        }
        
        if(checkFileExist(fileName: (defaultName + "." + extensionName))){
            while(num < 100){
                if(checkFileExist(fileName: (defaultName + "(\(num))" + "." + extensionName))){
                    num += 1
                }else{
                    break
                }
            }
        }else{
            return (defaultName + "." + extensionName)
        }
        return (defaultName + "(\(num))" + "." + extensionName)
    }
    
    func checkNameValidity() -> Bool {
        if name.contains(":") || name.contains("/"){
            return false
        }else{
            return true
        }
    }
    
    func loadNewFile(lang:Int){
        var content = ""
        
        if !checkNameValidity(){
            return
        }
        
        switch lang {
        case 0:
            name = returnFileName(defaultName: "default", extensionName: "py")
            content = """
            # Created on \(UIDevice.current.name).
            
            print ('Hello World!')
            
            """
        case 1:
            name = returnFileName(defaultName: "default", extensionName: "js")
            content = """
            // Created on \(UIDevice.current.name).
            
            console.log("Hello, World!")
            """
        case 3:
            name = returnFileName(defaultName: "default", extensionName: "cpp")
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
            name = returnFileName(defaultName: "default", extensionName: "c")
            content = """
            // Created on \(UIDevice.current.name).
            
            #include <stdio.h>
            
            int main() {
               // printf() displays the string inside quotation
               printf("Hello, World!");
               return 0;
            }
            """
        case 4:
            name = returnFileName(defaultName: "default", extensionName: "php")
            content = """
            // Created on \(UIDevice.current.name).
            
            <?php
            echo "Hello world!\n"
            ?>
            """
        case 62:
            name = returnFileName(defaultName: "Main", extensionName: "java")
            content = """
            // Created on \(UIDevice.current.name).
            
            class Main {
                public static void main(String[] args) {
                    System.out.println("Hello, World!");
                }
            }
            """
        case 83:
            name = returnFileName(defaultName: "default", extensionName: "swift")
            content = """
            // Created on \(UIDevice.current.name).
            
            import Swift
            print("Hello, World!")
            """
        case -2:
            name = returnFileName(defaultName: "index", extensionName: "html")
            content = """
            <!doctype html>
            <html>
              <head>
                <title>Title</title>
              </head>
              <body>
                <h1>Hello, World</h1>
              </body>
            </html>
            """
        case -3:
            name = returnFileName(defaultName: "style", extensionName: "css")
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
            if name.contains("."){
                name = returnFileName(defaultName: name.components(separatedBy: ".").dropLast().joined(), extensionName: name.components(separatedBy: ".").last ?? "")
            }
            content = ""
        }
        
        let url = URL(string: targetUrl)!.appendingPathComponent(name)
        do {
            App.workSpaceStorage.write(at: url, content: content.data(using: .utf8)!, atomically: true, overwrite: false){ error in
                if let error = error {
                    App.notificationManager.showErrorMessage(error.localizedDescription)
                    return
                }
                DispatchQueue.main.async {
                    let newEditor = EditorInstance(url: url.absoluteString, content: content, type: .file)
                    App.editors.append(newEditor)
                    App.activeEditor = newEditor
                    App.monacoInstance.newModel(url: url.absoluteString, content: content)
                    App.git_status()
                    App.updateCompilerCode(pathExtension: name.components(separatedBy: ".").last ?? "")
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    func getRootDirectory() -> String{
        if let documentsPathURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentsPathURL.absoluteString
        }else{
            return ""
        }
    }
    
    var body: some View {
        VStack(alignment: .leading){
            NavigationView {
                Form {
                    
                    Section(header: Text(NSLocalizedString("Templates", comment: ""))) {
                        ScrollView(.horizontal, showsIndicators: false){
                            HStack(){
                                Group{
                                    Text("Python").onTapGesture {
                                        self.loadNewFile(lang: 0)
                                    }
                                    Text("Javascript").onTapGesture {
                                        self.loadNewFile(lang: 1)
                                    }
                                    Text("C").onTapGesture {
                                        self.loadNewFile(lang: 2)
                                    }
                                    Text("C++").onTapGesture {
                                        self.loadNewFile(lang: 3)
                                    }
                                    Text("PHP").onTapGesture {
                                        self.loadNewFile(lang: 4)
                                    }
                                }.padding().background(Color.init("B3_A")).cornerRadius(12)
                                Group{
                                    Text("Java").onTapGesture {
                                        self.loadNewFile(lang: 62)
                                    }
                                    Text("Swift").onTapGesture {
                                        self.loadNewFile(lang: 83)
                                    }
                                    Text("HTML").onTapGesture {
                                        self.loadNewFile(lang: -2)
                                    }
                                    Text("CSS").onTapGesture {
                                        self.loadNewFile(lang: -3)
                                    }
                                }.padding().background(Color.init("B3_A")).cornerRadius(12)
                            }
                        }
                        
                    }
                    
                    Section(header: Text(NSLocalizedString("Custom", comment: ""))) {
                        HStack(){
                            fileIcon(url: name, iconSize: 14, type: .file)
                                .frame(width: 16)
                                .fixedSize()
                            TextField("example.py", text: $name, onCommit: {
//                                self.name = self.name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
                                self.loadNewFile(lang: -1)
                            }).autocapitalization(.none).disableAutocorrection(true)
                            Spacer()
                            Button(action: {
//                                self.name = self.name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
                                if !name.isEmpty{
                                    self.loadNewFile(lang: -1)
                                }
                            }){
                                Text(NSLocalizedString("Add File", comment: ""))
                            }
                            
                        }
                        
                    }
                    
                    if !checkNameValidity() && name != ""{
                        Text("File name '\(name)' contains invalid character.")
                    }
                    
                    
                    
                    Section(header: Text(NSLocalizedString("Where", comment: ""))) {
                        Text("\(targetUrl.last == "/" ? targetUrl.dropLast().components(separatedBy: "/").last!.removingPercentEncoding! : targetUrl.components(separatedBy: "/").last!.removingPercentEncoding!)")
                    }
                    
                }.navigationBarTitle(NSLocalizedString("New File", comment: ""))
            }
            Spacer()
        }
        
        
    }
}
