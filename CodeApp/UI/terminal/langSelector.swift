//
//  langSelector.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

let languageList = [
    0: ["Python (3.9.2)", "py"],
    1: ["JavaScript (Node.js 16.14.2)", "js"],
    2: ["C (Clang 13.0.0)", "c"],
    3: ["C++ (Clang 13.0.0)", "cpp"],
    4: ["PHP (8.0.8)", "php"],
    62: ["Java (OpenJDK 13.0.1)", "java"],
    45: ["Assembly (NASM 2.14.02)", "asm"],
    //                    46:["Bash (5.0.0)", "sh"],
    47: ["Basic (FBC 1.07.1)", "bas"],
    75: ["C (Clang 7.0.1)", "c"],
    76: ["C++ (Clang 7.0.1)", "cpp"],
    48: ["C (GCC 7.4.0)", "c"],
    52: ["C++ (GCC 7.4.0)", "cpp"],
    49: ["C (GCC 8.3.0)", "c"],
    53: ["C++ (GCC 8.3.0)", "cpp"],
    50: ["C (GCC 9.2.0)", "c"],
    54: ["C++ (GCC 9.2.0)", "cpp"],
    51: ["C# (Mono 6.6.0.161)", "cs"],
    86: ["Clojure (1.10.1)", "clj"],
    77: ["COBOL (GnuCOBOL 2.2)", "cob"],
    55: ["Common Lisp (SBCL 2.0.0)", "lsp"],
    56: ["D (DMD 2.089.1)", "di"],
    57: ["Elixir (1.9.4)", "ex"],
    58: ["Erlang (OTP 22.2)", "erl"],
    //                    44:["Executable", "exe"],
    59: ["Fortran (GFortran 9.2.0)", "f90"],
    60: ["Go (1.13.5)", "go"],
    88: ["Groovy (3.0.3)", "groovy"],
    61: ["Haskell (GHC 8.8.1)", "hs"],
    //                    63:["JavaScript (Node.js 12.14.0)", "js"],
    78: ["Kotlin (1.3.70)", "kt"],
    64: ["Lua (5.3.5)", "lua"],
    79: ["Objective-C (Clang 7.0.1)", "m"],
    65: ["OCaml (4.09.0)", "ml"],
    66: ["Octave (5.1.0)", "oct"],
    67: ["Pascal (FPC 3.0.4)", "pas"],
    //                    68:["PHP (7.4.1)", "php"],
    //                    43:["Plain Text", "txt"],
    69: ["Prolog (GNU Prolog 1.4.5)", "pl"],
    //                    70:["Python (2.7.17)", "py"],
    //                    71:["PythonML (3.7.7)", "py"],
    80: ["R (4.0.0)", "r"],
    72: ["Ruby (2.7.0)", "rb"],
    73: ["Rust (1.40.0)", "rs"],
    81: ["Scala (2.13.2)", "scala"],
    82: ["SQL (SQLite 3.27.2)", "sql"],
    74: ["TypeScript (3.7.4)", "ts"],
    83: ["Swift (5.2.3)", "swift"],
    84: ["Visual Basic.Net (vbnc 0.0.0.5943)", "vb"],
]

struct languageSelector: View {

    @EnvironmentObject var App: MainApp

    @State var showSheet = false
    @State var buttons: [ActionSheet.Button] = [ActionSheet.Button.cancel()]

    var body: some View {
        Menu {
            Picker(selection: $App.compilerCode, label: Text("Compiler Language")) {
                ForEach(Array(languageList.keys), id: \.self) { value in
                    if App.languageEnabled[value] {
                        Text("\(languageList[value]![0])").tag(value)
                    }
                }
            }

        } label: {
            Text(languageList[App.compilerCode]?[0] ?? "").foregroundColor(Color.init("T1")).font(
                .system(size: 12, weight: .light)
            ).padding(.top, 2).padding(.bottom, 2).padding(.leading, 4)
            Image(systemName: "chevron.down").foregroundColor(Color.init("T1")).font(
                .system(size: 8, weight: .light)
            ).padding(.trailing, 4)
        }
        .frame(height: 18)
        .background(Color.init(id: "dropdown.background"))
        .cornerRadius(5)
        .padding(.trailing)

        //        HStack(){
        //            Text(languageList[App.compilerCode]?[0] ?? "").foregroundColor(Color.init("T1")).font(.system(size: 12, weight: .light)).padding(.top, 2).padding(.bottom, 2).padding(.leading, 4)
        //            Image(systemName: "chevron.down").foregroundColor(Color.init("T1")).font(.system(size: 8, weight: .light)).padding(.trailing, 4)
        //        }.onTapGesture {
        //            buttons.removeAll()
        //            for i in App.languageEnabled.indices{
        //                if(App.languageEnabled[i]){
        //                    buttons.append(ActionSheet.Button.default(Text(languageList[i]?[0] ?? ""), action: {App.compilerCode = i}))
        //                }
        //            }
        //            buttons += [ActionSheet.Button.cancel()]
        //            showSheet.toggle()
        //        }
        //        .actionSheet(isPresented: $showSheet, content: {
        //            ActionSheet(title: Text("Compiler Language"), buttons: buttons)
        //        })
        //        .background(Color.init("sideBar.background"))
        //        .cornerRadius(5)
        //        .padding(.trailing)
    }
}
