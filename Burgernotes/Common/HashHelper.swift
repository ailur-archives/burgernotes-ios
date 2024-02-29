//
//  HashHelper.swift
//  Burgernotes
//
//  Created by ffqq on 27/02/2024.
//
//  HASH HELPER
//
//  This contains frontends for hashing required by login() in ContentView

import Foundation
import CryptoKit

class HashHelper {
    func hashPassword_sha3(_ password: String) -> String? {
        guard var hashedPassword = SHA3_512(password) else {return nil}
        
        for _ in 1..<128 { // Iterate 128 times (I might add iterations directly into sha3_512 one day)
            hashedPassword = SHA3_512(hashedPassword)
        }
        return String(cString: hashedPassword)
    }
    
    func hashPassword_sha512(_ password: String) -> String {
        let passwordData = Data(password.utf8)
        let passwordSHA512 = SHA512.hash(data: passwordData)
        return passwordSHA512.compactMap { String(format: "%02x", $0) }.joined()
    }
}
