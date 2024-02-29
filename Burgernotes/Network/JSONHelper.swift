//
//  sendJSONRequest.swift
//  Burgernotes
//
//  Created by ffqq on 27/02/2024.
//
//  JSON REQUEST HANDLER
//
//  This will export the sendJSONRequest() function for
//  use in the main project.
//
//  This was made mainly to avoid boilerplate code

import Foundation

class JSONHelper {
    static func sendJSONRequest(url: URL, parameters: [String: Any], completion: @escaping (Result<Data?, Error>) -> Void) {
        do {
            // Serialize parameters into JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: parameters)
            
            // Initialize the request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-type")
            request.httpBody = jsonData
            
            // Send the request
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error)) // 😱
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 { // 😃
                        completion(.success(data))
                    } else { // 🙁
                        let error = NSError(domain: "HTTPErrorDomain", code: httpResponse.statusCode, userInfo: nil)
                        completion(.failure(error))
                    }
                }
            }.resume()
        } catch {
            // JSON serialization error
            completion(.failure(error))
        }
    }
    
    // JSON response processor
    static func processJSONResponse(json: [String: Any], key: String) -> String? {
        return json[key] as? String
    }
}
