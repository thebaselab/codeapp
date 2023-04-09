//
//  FileIcon.swift
//  Code App
//
//  Created by Ken Chung on 5/12/2020.
//

import SwiftUI

private let extensionNames = [
    "bsl": "bsl", "mdo": "mdo", "asm": "asm", "s": "asm", "c": "c", "h": "c", "m": "c",
    "cs": "c-sharp", "cshtml": "html", "aspx": "html", "ascx": "html", "asax": "html",
    "master": "html", "cc": "cpp", "cpp": "cpp", "cxx": "cpp", "c++": "cpp", "hh": "cpp",
    "hpp": "cpp", "hxx": "cpp", "h++": "cpp", "mm": "cpp", "clj": "clojure", "cljs": "clojure",
    "cljc": "clojure", "edn": "clojure", "cfc": "coldfusion", "cfm": "coldfusion",
    "coffee": "coffee", "litcoffee": "coffee", "config": "config", "cfg": "config",
    "conf": "config", "cr": "crystal", "ecr": "crystal_embedded", "slang": "crystal_embedded",
    "cson": "json", "css": "css", "css.map": "css", "sss": "css", "csv": "csv", "xls": "xls",
    "xlsx": "xls", "cu": "cu", "cuh": "cu", "hu": "cu", "cake": "cake", "ctp": "cake_php", "d": "d",
    "doc": "word", "docx": "word", "ejs": "ejs", "ex": "elixir", "exs": "elixir_script",
    "elm": "elm", "ico": "favicon", "fs": "f-sharp", "fsx": "f-sharp", "gitignore": "git",
    "gitconfig": "git", "gitkeep": "git", "gitattributes": "git", "gitmodules": "git", "go": "go2",
    "slide": "go", "article": "go", "gradle": "gradle", "groovy": "grails", "gsp": "grails",
    "gql": "graphql", "graphql": "graphql", "graphqls": "graphql", "haml": "haml",
    "handlebars": "mustache", "hbs": "mustache", "hjs": "mustache", "hs": "haskell",
    "lhs": "haskell", "hx": "haxe", "hxs": "haxe", "hxp": "haxe", "hxml": "haxe", "html": "html",
    "jade": "jade", "java": "java", "class": "java", "classpath": "java", "properties": "java",
    "js": "javascript", "js.map": "javascript", "spec.js": "javascript", "test.js": "javascript",
    "es": "javascript", "es5": "javascript", "es6": "javascript", "es7": "javascript",
    "jinja": "jinja", "jinja2": "jinja", "json": "json", "jl": "julia", "kt": "kotlin",
    "kts": "kotlin", "dart": "dart", "less": "less", "liquid": "liquid", "ls": "livescript",
    "lua": "lua", "markdown": "markdown", "md": "markdown", "argdown": "argdown", "ad": "argdown",
    "mustache": "mustache", "stache": "mustache", "nim": "nim", "nims": "nim",
    "github-issues": "github", "ipynb": "notebook", "njk": "nunjucks", "nunjucks": "nunjucks",
    "nunjs": "nunjucks", "nunj": "nunjucks", "njs": "nunjucks", "nj": "nunjucks",
    "npm-debug.log": "npm", "npmignore": "npm", "npmrc": "npm", "ml": "ocaml", "mli": "ocaml",
    "cmx": "ocaml", "cmxa": "ocaml", "odata": "odata", "pl": "perl", "php": "php", "php.inc": "php",
    "pddl": "pddl", "plan": "plan", "happenings": "happenings", "ps1": "powershell",
    "psd1": "powershell", "psm1": "powershell", "prisma": "prisma", "pug": "pug", "pp": "puppet",
    "epp": "puppet", "py": "python", "jsx": "react", "spec.jsx": "react", "test.jsx": "react",
    "cjsx": "react", "spec.tsx": "react", "test.tsx": "react", "re": "reasonml", "R": "R",
    "rmd": "R", "rb": "ruby", "erb": "html_erb", "erb.html": "html_erb", "html.erb": "html_erb",
    "rs": "rust", "sass": "sass", "scss": "sass", "springBeans": "spring", "slim": "slim",
    "smarty.tpl": "smarty", "tpl": "smarty", "sbt": "sbt", "scala": "scala", "sol": "ethereum",
    "styl": "stylus", "swift": "swift", "sql": "db", "tf": "terraform", "tf.json": "terraform",
    "tfvars": "terraform", "tex": "tex", "sty": "tex", "dtx": "tex", "ins": "tex", "txt": "default",
    "toml": "config", "twig": "twig", "ts": "typescript", "tsx": "typescript",
    "spec.ts": "typescript_yellow", "test.ts": "typescript_yellow", "vala": "vala", "vapi": "vala",
    "vue": "vue", "wasm": "wasm", "wat": "wat", "xml": "xml", "yml": "yml", "yaml": "yml",
    "pro": "prolog", "jar": "zip", "zip": "zip", "wgt": "wgt", "ai": "illustrator",
    "psd": "photoshop", "pdf": "pdf", "eot": "font", "ttf": "font", "woff": "font", "woff2": "font",
    "gif": "image", "jpg": "image", "jpeg": "image", "png": "image", "pxm": "image", "svg": "svg",
    "svgx": "image", "tiff": "image", "webp": "image", "sublime-project": "sublime",
    "sublime-workspace": "sublime", "code-search": "code-search", "component": "salesforce",
    "cls": "salesforce", "sh": "shell", "zsh": "shell", "fish": "shell", "zshrc": "shell",
    "bashrc": "shell", "mov": "video", "ogv": "video", "webm": "video", "avi": "video",
    "mpg": "video", "mp4": "video", "mp3": "audio", "ogg": "audio", "wav": "audio", "flac": "audio",
    "3ds": "svg", "3dm": "svg", "stl": "svg", "obj": "svg", "dae": "svg", "bat": "windows",
    "cmd": "windows", "babelrc": "babel", "babelrc.js": "babel", "babelrc.cjs": "babel",
    "bowerrc": "bower", "codeclimate.yml": "code-climate", "eslintrc": "eslint",
    "eslintrc.js": "eslint", "eslintrc.yaml": "eslint", "eslintrc.yml": "eslint",
    "eslintrc.json": "eslint", "eslintignore": "eslint", "firebaserc": "firebase",
    "jshintrc": "javascript", "config.cjs": "javascript", "jscsrc": "javascript",
    "stylelintrc": "stylelint", "stylelintrc.json": "stylelint", "stylelintrc.yaml": "stylelint",
    "stylelintrc.yml": "stylelint", "stylelintrc.js": "stylelint", "stylelintignore": "stylelint",
    "direnv": "config", "env": "config", "static": "config", "editorconfig": "config",
    "slugignore": "config", "tmp": "clock", "htaccess": "config", "key": "lock", "cert": "lock",
    "DS_Store": "ignored", "svelte": "svelte", "mjs": "javascript", "cjs": "javascript",
    "mts": "typescript", "cts": "typescript",
]
private let level2ExtensionNames = [
    "css.map": "css", "js.map": "javascript", "spec.js": "javascript_yellow",
    "test.js": "javascript", "npm-debug.log": "npm", "php.inc": "php", "spec.jsx": "react",
    "test.jsx": "react", "spec.tsx": "react", "test.tsx": "react", "erb.html": "html_erb",
    "html.erb": "html_erb", "smarty.tpl": "smarty", "tf.json": "terraform", "spec.ts": "typescript",
    "test.ts": "typescript_yellow", "babelrc.js": "babel", "babelrc.cjs": "babel",
    "codeclimate.yml": "code-climate", "eslintrc.js": "eslint", "eslintrc.yaml": "eslint",
    "eslintrc.yml": "eslint", "eslintrc.json": "eslint", "config.cjs": "javascript",
    "stylelintrc.json": "stylelint", "stylelintrc.yaml": "stylelint",
    "stylelintrc.yml": "stylelint", "stylelintrc.js": "stylelint",
]
private let fileNames = [
    "license": "license", "licence": "license", "license.txt": "license", "licence.txt": "license",
    "license.md": "license", "licence.md": "license", "readme.txt": "info", "readme.md": "info",
    "readme": "info",
]

struct FileIcon: View {
    let url: String
    let iconSize: CGFloat

    @Environment(\.sizeCategory) var sizeCategory

    var body: some View {
        let fileName = url.components(separatedBy: "/").last?.lowercased() ?? ""
        if let image = fileNames[fileName] {
            Image(image)
                .resizable()
                .frame(width: iconSize + 6, height: iconSize + 6)
        } else if let image = level2ExtensionNames[
            fileName.components(separatedBy: ".").suffix(2).joined(separator: ".")]
        {
            Image(image)
                .resizable()
                .frame(width: iconSize + 6, height: iconSize + 6)
        } else if fileName.contains(".") {
            switch fileName.components(separatedBy: ".").last ?? "" {
            case "swift":
                Image(systemName: "swift")
                    .foregroundColor(.orange)
                    .font(.system(size: iconSize))
                    .frame(width: iconSize + 6, height: iconSize + 6)
            case "txt":
                Image(systemName: "text.alignleft")
                    .foregroundColor(.gray)
                    .font(.system(size: iconSize - 2))
                    .frame(width: iconSize + 6, height: iconSize + 6)
            case "jpg", "png", "jpeg", "gif":
                Image(systemName: "photo")
                    .foregroundColor(.gray)
                    .font(.system(size: iconSize - 2))
                    .frame(width: iconSize + 6, height: iconSize + 6)
            case "icloud":
                Image(systemName: "icloud.and.arrow.down")
                    .foregroundColor(.gray)
                    .font(.system(size: iconSize - 2))
            case let x:
                if let image = extensionNames[x] {
                    Image(image)
                        .resizable()
                        .frame(width: iconSize + 6, height: iconSize + 6)
                } else {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.gray)
                        .font(.system(size: iconSize - 2))
                }
            }
        } else {
            Image(systemName: "text.alignleft")
                .foregroundColor(.gray)
                .font(.system(size: iconSize - 2))
        }
    }
}
