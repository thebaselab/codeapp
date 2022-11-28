//
//  Encoding.swift
//  Code
//
//  Created by Ken Chung on 26/11/2022.
//

import Foundation

struct CodeAppEncoding: Identifiable {
    let id = UUID()
    let encoding: String.Encoding
    let name: String
}

let AVAILABLE_ENCODING: [CodeAppEncoding] = [
    CodeAppEncoding(encoding: .utf8, name: "UTF-8"),
    CodeAppEncoding(encoding: .gb_18030_2000, name: "GB 18030-2000"),
    CodeAppEncoding(encoding: .EUC_KR, name: "EUC-KR"),
    CodeAppEncoding(encoding: .ascii, name: "ASCII"),
    CodeAppEncoding(encoding: .nextstep, name: "NextStep"),
    CodeAppEncoding(encoding: .japaneseEUC, name: "Japanese EUC"),
    CodeAppEncoding(encoding: .isoLatin1, name: "ISO Latin 1"),
    CodeAppEncoding(encoding: .symbol, name: "Symbol"),
    CodeAppEncoding(encoding: .nonLossyASCII, name: "Non Lossy ASCII"),
    CodeAppEncoding(encoding: .shiftJIS, name: "Shift JIS"),
    CodeAppEncoding(encoding: .isoLatin2, name: "ISO Latin 2"),
    CodeAppEncoding(encoding: .unicode, name: "Unicode"),
    CodeAppEncoding(encoding: .windowsCP1250, name: "Windows CP1250"),
    CodeAppEncoding(encoding: .windowsCP1251, name: "Windows CP1251"),
    CodeAppEncoding(encoding: .windowsCP1252, name: "Windows CP1252"),
    CodeAppEncoding(encoding: .windowsCP1253, name: "Windows CP1253"),
    CodeAppEncoding(encoding: .windowsCP1254, name: "Windows CP1254"),
    CodeAppEncoding(encoding: .iso2022JP, name: "ISO 2022 JP"),
    CodeAppEncoding(encoding: .macOSRoman, name: "Mac OS Roman"),
    CodeAppEncoding(encoding: .utf16, name: "UTF-16"),
    CodeAppEncoding(encoding: .utf16BigEndian, name: "UTF-16 Big Endian"),
    CodeAppEncoding(encoding: .utf16LittleEndian, name: "UTF-16 Little Endian"),
    CodeAppEncoding(encoding: .utf32, name: "UTF-32"),
    CodeAppEncoding(encoding: .utf32BigEndian, name: "UTF-32 Big Endian"),
    CodeAppEncoding(encoding: .utf32LittleEndian, name: "UTF-32 Little Endian"),
]
