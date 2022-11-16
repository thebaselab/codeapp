//
//  shortcutsMapping.swift
//  Code
//
//  Created by Ken Chung on 23/1/2022.
//

import Foundation
import GameController

let shortcutsMapping: [GCKeyCode: (Int, String)] = [
    .leftGUI: (2048, "command"),  // Command Key
    .rightGUI: (2048, "command"),
    .deleteOrBackspace: (1, "delete.backward"),
    .tab: (2, "tab"),
    .returnOrEnter: (3, "return"),
    .leftShift: (4, "shift"),
    .rightShift: (4, "shift"),
    .leftControl: (5, "control"),
    .rightControl: (5, "control"),
    .leftAlt: (6, "option"),
    .rightAlt: (6, "option"),
    .capsLock: (8, "capslock"),
    .escape: (9, "esc"),
    .spacebar: (10, "space"),
    .pageUp: (11, "page up"),
    .pageDown: (12, "page down"),
    .end: (13, "end"),
    .home: (14, "home"),
    .leftArrow: (15, "arrow.left"),
    .upArrow: (16, "arrow.up"),
    .rightArrow: (17, "arrow.right"),
    .downArrow: (18, "arrow.down"),
    .insert: (19, "insert"),
    .deleteForward: (20, "delete.forward"),
    .zero: (21, "0"),
    .one: (22, "1"),
    .two: (23, "2"),
    .three: (24, "3"),
    .four: (25, "4"),
    .five: (26, "5"),
    .six: (27, "6"),
    .seven: (28, "7"),
    .eight: (29, "8"),
    .nine: (30, "9"),
    .keyA: (31, "A"),
    .keyB: (32, "B"),
    .keyC: (33, "C"),
    .keyD: (34, "D"),
    .keyE: (35, "E"),
    .keyF: (36, "F"),
    .keyG: (37, "G"),
    .keyH: (38, "H"),
    .keyI: (39, "I"),
    .keyJ: (40, "J"),
    .keyK: (41, "K"),
    .keyL: (42, "L"),
    .keyM: (43, "M"),
    .keyN: (44, "N"),
    .keyO: (45, "O"),
    .keyP: (46, "P"),
    .keyQ: (47, "Q"),
    .keyR: (48, "R"),
    .keyS: (49, "S"),
    .keyT: (50, "T"),
    .keyU: (51, "U"),
    .keyV: (52, "V"),
    .keyW: (53, "W"),
    .keyX: (54, "X"),
    .keyY: (55, "Y"),
    .keyZ: (56, "Z"),
    //    .Meta : (57,""),
    //    .ContextMenu : (58,""),
    .F1: (59, "F1"),
    .F2: (60, "F2"),
    .F3: (61, "F3"),
    .F4: (62, "F4"),
    .F5: (63, "F5"),
    .F6: (64, "F6"),
    .F7: (65, "F7"),
    .F8: (66, "F8"),
    .F9: (67, "F9"),
    .F10: (68, "F10"),
    .F11: (69, "F11"),
    .F12: (70, "F12"),
    .F13: (71, "F13"),
    .F14: (72, "F14"),
    .F15: (73, "F15"),
    .F16: (74, "F16"),
    .F17: (75, "F17"),
    .F18: (76, "F18"),
    .F19: (77, "F19"),
    .keypadNumLock: (78, "num lock"),
    .scrollLock: (79, "scroll lock"),
    /**
    .    * Used for miscellaneous characters; it can vary by keyboard.
    .    * For the US standard keyboard,""), the ';:' key
    .    */
    .semicolon: (80, ";"),
    /**
    .    * For any country/region,""), the '+' key
    .    * For the US standard keyboard,""), the ':+' key
    .    */
    .equalSign: (81, "+"),
    /**
    .    * For any country/region,""), the ',""),' key
    .    * For the US standard keyboard,""), the ',""),<' key
    .    */
    .comma: (82, ","),
    /**
    .    * For any country/region,""), the '-' key
    .    * For the US standard keyboard,""), the '-_' key
    .    */
    .hyphen: (83, "-"),
    /**
    .    * For any country/region,""), the '.' key
    .    * For the US standard keyboard,""), the '.>' key
    .    */
    .period: (84, "."),
    /**
    .    * Used for miscellaneous characters; it can vary by keyboard.
    .    * For the US standard keyboard,""), the '/?' key
    .    */
    .slash: (85, "/"),
    /**
    .    * Used for miscellaneous characters; it can vary by keyboard.
    .    * For the US standard keyboard,""), the '`~' key
    .    */
    .graveAccentAndTilde: (86, "`"),
    /**
    .    * Used for miscellaneous characters; it can vary by keyboard.
    .    * For the US standard keyboard,""), the '[{' key
    .    */
    .openBracket: (87, "["),
    /**
    .    * Used for miscellaneous characters; it can vary by keyboard.
    .    * For the US standard keyboard,""), the '\|' key
    .    */
    .backslash: (88, #"\"#),
    /**
    .    * Used for miscellaneous characters; it can vary by keyboard.
    .    * For the US standard keyboard,""), the ']}' key
    .    */
    .closeBracket: (89, "]"),
    /**
    .    * Used for miscellaneous characters; it can vary by keyboard.
    .    * For the US standard keyboard,""), the ''"' key
    .    */
    .quote: (90, "'"),
    /**
    * Used for miscellaneous characters; it can vary by keyboard.
    */
    //    .OEM_8 : (91,""),
    /**
    * Either the angle bracket key or the backslash key on the RT 102-key keyboard.
    */
    .nonUSBackslash: (92, #"\"#),
    .keypad0: (93, "0"),
    .keypad1: (94, "1"),
    .keypad2: (95, "2"),
    .keypad3: (96, "3"),
    .keypad4: (97, "4"),
    .keypad5: (98, "5"),
    .keypad6: (99, "6"),
    .keypad7: (100, "7"),
    .keypad8: (101, "8"),
    .keypad9: (102, "9"),
    .keypadAsterisk: (103, "*"),
    .keypadPlus: (104, "+"),
    .keypadEnter: (105, "enter"),
    .keypadHyphen: (106, "-"),
    .keypadPeriod: (107, "."),
    .keypadSlash: (108, "/"),
    /**
    * Cover all key codes when IME is processing input.
    */
    //    .KEY_IN_COMPOSITION : 109,
    //    .ABNT_C1 : 110,
    //    .ABNT_C2 : 111,
    //    .AudioVolumeMute : 112,
    //    .AudioVolumeUp : 113,
    //    .AudioVolumeDown : 114,
    //    .BrowserSearch : 115,
    //    .BrowserHome : 116,
    //    .BrowserBack : 117,
    //    .BrowserForward : 118,
    //    .MediaTrackNext : 119,
    //    .MediaTrackPrevious : 120,
    //    .MediaStop : 121,
    //    .MediaPlayPause : 122,
    //    .LaunchMediaPlayer : 123,
    //    .LaunchMail : 124,
    //    .LaunchApp2 : 125,
    //

]
