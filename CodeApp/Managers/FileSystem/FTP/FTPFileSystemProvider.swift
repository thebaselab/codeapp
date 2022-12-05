//
//  FTPFileSystemProvider.swift
//  Code
//
//  Created by Ken Chung on 10/4/2022.
//

import FilesProvider
import Foundation

class FTPFileSystemProvider: FileSystemProvider {

    static var registeredScheme: String = "ftp"
    var gitServiceProvider: GitServiceProvider? = nil
    var searchServiceProvider: SearchServiceProvider? = nil
    var terminalServiceProvider: TerminalServiceProvider? = nil

    private var fs: FTPFileProvider

    init?(baseURL: URL, cred: URLCredential) {
        guard baseURL.scheme == "ftp" || baseURL.scheme == "ftps" else {
            return nil
        }
        if let fs = FTPFileProvider(baseURL: baseURL, credential: cred) {
            //            fs.serverTrustPolicy = .disableEvaluation
            self.fs = fs
        } else {
            return nil
        }
    }

    func write(
        at: URL, content: Data, atomically: Bool, overwrite: Bool,
        completionHandler: @escaping (Error?) -> Void
    ) {
        fs.writeContents(
            path: at.path, contents: content, atomically: atomically, overwrite: overwrite,
            completionHandler: completionHandler)
    }

    func contentsOfDirectory(at url: URL, completionHandler: @escaping ([URL]?, Error?) -> Void) {
        fs.contentsOfDirectory(path: url.path) { files, error in
            completionHandler(
                files.map {
                    if $0.isDirectory {
                        return $0.url.appendingPathComponent("", isDirectory: true)
                    } else {
                        return $0.url
                    }
                }, error)
        }
    }

    func fileExists(at url: URL, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }

    func createDirectory(
        at: URL, withIntermediateDirectories: Bool, completionHandler: @escaping (Error?) -> Void
    ) {
        fs.create(folder: at.lastPathComponent, at: at.path, completionHandler: completionHandler)
    }

    func copyItem(at: URL, to: URL, completionHandler: @escaping (Error?) -> Void) {
        fs.copyItem(path: at.path, to: to.path, completionHandler: completionHandler)
    }

    func moveItem(at: URL, to: URL, completionHandler: @escaping (Error?) -> Void) {
        fs.moveItem(path: at.path, to: to.path, completionHandler: completionHandler)
    }

    func removeItem(at: URL, completionHandler: @escaping (Error?) -> Void) {
        fs.removeItem(path: at.path, completionHandler: completionHandler)
    }

    func contents(at: URL, completionHandler: @escaping (Data?, Error?) -> Void) {
        print("FTP: Loading contents of \(at.path)")
        fs.contents(path: at.path) { data, error in
            print("FTP: Finished loading contents of \(at.absoluteString)")
            DispatchQueue.main.async {
                completionHandler(data, error)
            }
        }
    }

    func attributesOfItem(
        at: URL, completionHandler: @escaping ([FileAttributeKey: Any?]?, Error?) -> Void
    ) {
        fs.attributesOfItem(path: at.path) { file, error in
            if let error {
                completionHandler(nil, error)
                return
            }
            guard let file else {
                completionHandler(nil, WorkSpaceStorage.FSError.Unknown)
                return
            }
            completionHandler(
                [
                    .size: file.size,
                    .modificationDate: file.modifiedDate,
                    .creationDate: file.creationDate,
                ], nil)
        }
    }

}
