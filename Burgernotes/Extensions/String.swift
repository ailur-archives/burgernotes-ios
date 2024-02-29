//
//  String.swift
//  Burgernotes
//
//  Created by ffqq on 27/02/2024.
//
//  STRING EXTENSIONS
//
//  This file will define String.encrypt and String.decrypt (using
//  crypto.js because upstream isn't documented enough)

import Foundation
import JavaScriptCore

extension String {
    func encrypt(password: String) -> String {
        let context = JSContext()!
        
        // Load the CryptoJS library
        let cryptoJSPath = Bundle.main.path(forResource: "crypto-js.min", ofType: "js")!
        let cryptoJSScript = try! String(contentsOfFile: cryptoJSPath)
        context.evaluateScript(cryptoJSScript)

        // Embed the javascript code
        let jsCode = """
        function encryptString(content, password) {
            try {
                var contentWithNewline = content.replace(/NEWLINEHERETHISISHACKY/g, '\\n');
                var encrypted = CryptoJS.AES.encrypt(contentWithNewline, password).toString();
                return encrypted;
            } catch (error) {
                return error.message;
            }
        }

        encryptString('\(self)', '\(password)');
        """
        let encryptedValue = context.evaluateScript(jsCode)?.toString() // Run and output as a string
        
        return encryptedValue ?? "" // Return the string output
    }

    func decrypt(password: String) -> String {
        let context = JSContext()!
        
        // Load the CryptoJS library
        let cryptoJSPath = Bundle.main.path(forResource: "crypto-js.min", ofType: "js")!
        let cryptoJSScript = try! String(contentsOfFile: cryptoJSPath)
        context.evaluateScript(cryptoJSScript)

        // Embed the javascript code
        let jsCode = """
        function decryptString(content, password) {
            try {
                var decrypted = CryptoJS.AES.decrypt(content, password).toString(CryptoJS.enc.Utf8);
                return decrypted;
            } catch (error) {
                return error.message;
            }
        }

        decryptString('\(self)', '\(password)');
        """
        let decryptedValue = context.evaluateScript(jsCode)?.toString() // Run and output as a string
        
        return decryptedValue ?? "" // Return the string output
    }
}
