//
//  LocaleArgs.swift
//  BoomOrBonusUITests
//
//  Most UI tests assert zh-Hant text, but the dedicated simulator may be set to another language. Every launch
//  passes these arguments so the app runs in zh-Hant (Taiwan) no matter what the simulator uses.
//  LocalizationUITests passes its own per-locale arguments instead.
//

import XCTest

enum LocaleArgs {
    static let zhHant = ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_TW"]

    static func args(language: String, locale: String) -> [String] {
        ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
    }
}
