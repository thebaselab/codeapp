//
//  Java.swift
//  extension
//
//  Created by Ken Chung on 02/07/2024.
//

import Foundation

// Java attempts to re-run main() on first run:
// https://github.com/PojavLauncherTeam/openjdk-multiarch-jdk8u/blob/99f3f8bf37150677058ab00b76f9b17a1ab23a70/jdk/src/macosx/bin/java_md_macosx.c#L311
@_cdecl("main")
public func JavaEntrance(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    JavaLauncher.shared.launchJava(
        args: JavaLauncher.shared.lastArgs,
        frameworkDirectory: JavaLauncher.shared.lastFrameworkDir,
        currentDirectory: JavaLauncher.shared.lastCurrentDirectory
    )
    return 0
}

class JavaLauncher {
    static let shared = JavaLauncher()
    
    var lastFrameworkDir: URL!
    var lastCurrentDirectory: URL!
    var lastArgs: [String] = []
    var javaString: NSString = "java"
    var openJDKString: NSString = "openjdk"
    var versionStringFull: NSString = "1.8.0-internal"
    var versionString: NSString = "1.8.0"
    static let javaHome = "\(Bundle.main.resourcePath!)/java-8-openjdk"
    let defaultArgs = [
        "\(javaHome)/bin/java",
        "-XstartOnFirstThread",
        "-Djava.library.path=\(Bundle.main.bundlePath)/Frameworks",
        "-Djna.boot.library.path=\(Bundle.main.bundlePath)/Frameworks",
        "-Dorg.lwjgl.glfw.checkThread0=false",
        "-Dorg.lwjgl.system.allocator=system",
        "-Dlog4j2.formatMsgNoLookups=true",
        "-XX:+UnlockExperimentalVMOptions",
        "-XX:+DisablePrimordialThreadGuardPages",
        "-Djava.awt.headless=false",
        "-XX:-UseCompressedClassPointers",
        "-jre-restrict-search"
    ]
    
    typealias JLI_Launch = @convention(c) (
        Int32,
        UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?,
        Int32,
        UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?,
        Int32,
        UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?,
        UnsafeMutablePointer<CChar>?,
        UnsafeMutablePointer<CChar>?,
        UnsafeMutablePointer<CChar>?,
        UnsafeMutablePointer<CChar>?,
        Int32,
        Int32,
        Int32,
        Int32
    ) -> CInt
    
    func launchJava(args: [String], frameworkDirectory: URL, currentDirectory: URL){
        lastFrameworkDir = frameworkDirectory
        lastCurrentDirectory = currentDirectory
        lastArgs = args
        
        let libjlipath = "\(frameworkDirectory.path)/libjli.framework/libjli"
        setenv("JAVA_HOME", JavaLauncher.javaHome, 1)
        setenv("INTERNAL_JLI_PATH", libjlipath, 1)
        setenv("HACK_IGNORE_START_ON_FIRST_THREAD", "1", 1)
        
//        For debug:
//        setenv("_JAVA_LAUNCHER_DEBUG", "1", 1)
        
        for lib in ["libffi.8", "libjvm", "libverify", "libjava", "libnet"]{
            let handle = dlopen("\(frameworkDirectory.path)/\(lib).framework/\(lib)", RTLD_GLOBAL)
            if (handle == nil) {
                if let error = dlerror(),
                    let str = String(validatingUTF8: error) {
                    print(str)
                }
                fatalError()
            }
        }
        
        let libjli = dlopen(libjlipath, RTLD_GLOBAL)
        if (libjli == nil){
            if let error = dlerror(),
                let str = String(validatingUTF8: error) {
                print(str)
            }
            return
        }
        
        let pJLI_Launch = dlsym(libjli, "JLI_Launch")
        let f = unsafeBitCast(pJLI_Launch, to: JLI_Launch.self)
        
        let realArgs = {
            if args.first == "java" {
                return (defaultArgs + args.dropFirst())
            }else if args.first == "javac" {
                return (
                    defaultArgs +
                    ["-cp",
                     "\(Bundle.main.resourcePath!)/tools.jar:\(currentDirectory.path)",
                     "com.sun.tools.javac.Main"
                    ]
                    + args.dropFirst()
                )
            }else {
                return defaultArgs
            }
        }()
        var cargs = realArgs.map{strdup($0) }
        
        let javaStringPtr = UnsafeMutablePointer<CChar>(mutating: javaString.utf8String)
        let openJDKStringPtr = UnsafeMutablePointer<CChar>(mutating: openJDKString.utf8String)
        let versionStringFullPtr = UnsafeMutablePointer<CChar>(mutating: versionStringFull.utf8String)
        let versionStringPtr = UnsafeMutablePointer<CChar>(mutating: versionString.utf8String)
        
        let result = f(
            Int32(cargs.count), &cargs,
            0, nil,
            0, nil,
            versionStringFullPtr,
            versionStringPtr,
            javaStringPtr,
            openJDKStringPtr,
            0,
            1,
            0,
            1
        )
        dlclose(libjli)
    }
    
}
