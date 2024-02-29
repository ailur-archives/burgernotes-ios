//
//  SizeHelper.swift
//  Burgernotes
//
//  Created by ffqq on 28/02/2024.
//
//  SIZE HELPER
//
//  This is responsible for converting size (in bytes) to human-readable
//  sizes (eg: 85 bytes, 12 kilobytes, 8 megabytes)

import Foundation

class SizeHelper {
    func humanReadable(_ size: Int) -> String {
        ByteCountFormatter().allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        ByteCountFormatter().countStyle = .file
        return ByteCountFormatter().string(fromByteCount: Int64(size))
    }
    
    func humanReadable(_ size: String) -> String {
        return humanReadable(Int(size) ?? 0)
    }
}
