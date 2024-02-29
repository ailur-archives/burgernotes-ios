//
//  ContentView.swift
//  Burgernotes
//
//  Created by ffqq on 23/02/2024.
//
//  CONTENT VIEW
//
//  This is where the app lives. Everything that happens,
//  happens here.
//
//  (This'll need a rewrite some day)

import SwiftUI
import CryptoKit
import SafariServices
import KeychainSwift
import JavaScriptCore

struct ContentView: View {
    // Initialize everything
    @State private var username = ""
    @State private var password = ""
    @State private var notes: [Note] = []
    @State private var noteContent = ""
    @State private var selectedNote = ""
    @State private var showAddNote = false
    
    // User info
    @State private var noteCount: Int = 0
    @State private var sessionID: Int = 0
    @State private var maxStorage = ""
    @State private var usedStorage = ""

    // UI activators
    @State private var isEditing = false
    @State private var usingSettings = false
    @State private var isOnline = Reach().isConnectedToNetwork()
    @State private var loggingIn = true
    @State private var signingUp = false
    @State private var showErrorLabel = false
    @State private var errorMessage = ""
    
    @AppStorage("Username") var storedUsername: String? // Usernames are stored in UserDefaults for the sake of convenience
    let keychain = KeychainSwift()
    
    func login() {
        let hashHelper = HashHelper()
        // Use HashHelper to hash our password
        let hashedPassword = hashHelper.hashPassword_sha3(password)
        let SHA512key = hashHelper.hashPassword_sha512(password)
        
        if password.count < 8 {
            showErrorLabel = true
            errorMessage = "Password must be 8+ characters!"
            return
        }
        
        if loggingIn {
            // Prepare data
            let parameters = ["username": username, "password": hashedPassword, "passwordchange": "no", "newpass": "null"] // Legacy accounts should be migrated from Argon2 through the browser.
            
            // Create the URL request
            guard let url = URL(string: "https://notes.hectabit.org/api/login") else {
                showErrorLabel = true
                errorMessage = "Invalid URL" // Usually we'd do `guard let url = URL(string: "https://foo.bar/api/foo") else { return }`, but we will display a user-visible error for the sake of UX.
                return
            }
            
            JSONHelper.sendJSONRequest(url: url, parameters: parameters as [String : Any]) { result in
                switch result {
                case .success(let data):
                    if let data = data {
                        // Handle the response
                        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let keyValue = JSONHelper.processJSONResponse(json: json, key: "key") {
                            let secretKey = keyValue
                            keychain.delete("secretKey")
                            keychain.set(secretKey, forKey: "secretKey")
                            storedUsername = username // This will also trigger SwiftUI to change vstacks
                            keychain.delete("encryptionKey")
                            keychain.set(SHA512key, forKey: "encryptionKey")
                            password = ""
                        }
                    } else {
                        // Show error label
                        showErrorLabel = true
                        errorMessage = "Unknown error"
                    }
                    
                case .failure(let error):
                    if (error as NSError).code == 401 {
                        showErrorLabel = true
                        errorMessage = "Invalid username or password."
                    } else {
                        // Show error label
                        showErrorLabel = true
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        
        if signingUp {
            // Prepare data
            let parameters = ["username": username, "password": hashedPassword] // Legacy accounts should be migrated from Argon2 through the browser.
            
            // Create the URL request
            guard let url = URL(string: "https://notes.hectabit.org/api/signup") else {
                showErrorLabel = true
                errorMessage = "Invalid URL" // Usually we'd do `guard let url = URL(string: "https://foo.bar/api/foo") else { return }`, but we will display a user-visible error for the sake of UX.
                return
            }
            
            JSONHelper.sendJSONRequest(url: url, parameters: parameters as [String : Any]) { result in
                switch result {
                case .success(let data):
                    if let data = data {
                        // Handle the response
                        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let keyValue = JSONHelper.processJSONResponse(json: json, key: "key") {
                            let secretKey = keyValue
                            keychain.delete("secretKey")
                            keychain.set(secretKey, forKey: "secretKey")
                            storedUsername = username // This will also trigger SwiftUI to change vstacks
                            keychain.delete("encryptionKey")
                            keychain.set(SHA512key, forKey: "encryptionKey")
                            signingUp = false
                            loggingIn = true
                            password = ""
                        }
                    } else {
                        // Show error label
                        showErrorLabel = true
                        errorMessage = "Unknown error"
                    }
                    
                case .failure(let error):
                    if (error as NSError).code == 409 {
                        // Show error label
                        showErrorLabel = true
                        errorMessage = "Username already taken!"
                    } else {
                        // Show error label
                        showErrorLabel = true
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    var body: some View {
        if storedUsername != nil {
            // Note list
            let secretKey = keychain.get("secretKey")
            let encryptionKey = keychain.get("encryptionKey")
            VStack {
                HStack {
                    // Refresh notes
                    Button(action: {
                        fetchNotes() // Refresh notes
                    }) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.title)
                    }
                    .disabled(isEditing) .disabled(usingSettings) .disabled(!isOnline) // Make the buttons disabled while the note editor (or settings) is open, or while offline.
                    Spacer()
                    
                    // Settings
                    Button(action: {
                        if usingSettings == false {
                            fetchUserInfo()
                            usingSettings = true
                        } else {
                            usingSettings = false
                        }
                    }) {
                        Image(systemName: "gear")
                            .font(.title)
                    }
                    .disabled(isEditing) .disabled(!isOnline) // Make the buttons disabled while the note editor is open, or while offline.
                    
                    // New note
                    Button(action: {
                        // New note creation
                        let dialog = UIAlertController(title: "New Note", message: "Enter note name", preferredStyle: .alert)
                        dialog.addTextField { $0.placeholder = "My Diary" }
                        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                        let createAction = UIAlertAction(title: "Create", style: .default) { _ in
                            if let noteName = dialog.textFields?.first?.text, let url = URL(string: "https://notes.hectabit.org/api/newnote") {
                                let parameters = ["secretKey": "\(secretKey ?? "bum")", "noteName": "\(noteName.encrypt(password: encryptionKey ?? "this bum ain't got an encryption key!!!"))"]
                                
                                JSONHelper.sendJSONRequest(url: url, parameters: parameters) { result in
                                    switch result {
                                    case .success:
                                        fetchNotes()
                                    case .failure(let error):
                                        print("Error sending JSON request: \(error)")
                                    }
                                }
                            }
                            fetchNotes()
                        }
                        dialog.addAction(cancelAction);dialog.addAction(createAction)
                        if let topVC = UIApplication.shared.keyWindow?.rootViewController { topVC.present(dialog, animated: true) } // We can keep using keyWindow, it's not a big deal for this specific usecase that it's deprecated
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.title)
                    }
                    .disabled(isEditing) .disabled(usingSettings) .disabled(!isOnline) // Make the buttons disabled while the note editor (or settings) is open, or while offline.
                }
                .padding()
                
                Text("Burgernotes")
                    .font(.title)
                    .padding()
                
                Group {
                    if isOnline {
                        if !usingSettings {
                            if !isEditing {
                                List {
                                    ForEach(notes, id: \.id) { note in
                                        let noteTitle = note.title.decrypt(password: encryptionKey ?? "this bum ain't got an encryption key!!!")
                                        Button(action: {
                                            fetchNoteContent(note: note)
                                        }) {
                                            Text(noteTitle)
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(action: {
                                                guard let url = URL(string: "https://notes.hectabit.org/api/removenote") else { return }
                                                let parameters = ["secretKey": "\(secretKey ?? "bum")", "noteId": "\(note.id)"]
                                                
                                                JSONHelper.sendJSONRequest(url: url, parameters: parameters) { result in
                                                    switch result {
                                                    case .success(_):
                                                        print("Note deleted successfully.")
                                                        withAnimation {
                                                            notes.removeAll(where: { $0.id == note.id })
                                                        }
                                                        
                                                    case .failure(let error):
                                                        print("Error: \(error)")
                                                    }
                                                }
                                            }) {
                                                Image(systemName: "trash")
                                            }
                                            .tint(.red)
                                            .animation(.default, value: notes)
                                        }
                                    }
                                }
                                .listStyle(.plain)
                                Spacer()
                            }
                        }
                    }
                    
                    if !isOnline {
                        Text("You are currently offline.")
                            .foregroundStyle(Color.red)
                        Button(action: {
                            isOnline = Reach().isConnectedToNetwork()
                            if isOnline {
                                fetchNotes()
                            }
                        }) {
                            Text("Refresh connection status")
                                .padding()
                                .foregroundStyle(Color.blue)
                        }
                        Spacer()
                    }
                    
                    if isEditing {
                        TextEditor(text: $noteContent)
                            .padding()
                        HStack {
                            Button(action: {
                                isEditing = false
                                noteContent = ""
                            }) {
                                Image(systemName: "chevron.left")
                                    .imageScale(.large)
                            }
                            .padding()
                            Spacer()
                            Button(action: {
                                saveEditedNoteContent()
                            }) {
                                Text("Save")
                            }
                            .padding()
                        }
                    } else {
                        Text(noteContent)
                            .padding()
                            .onTapGesture {
                                isEditing = true
                            }
                    }
                }
                .padding()
                .onAppear {
                    fetchNotes()
                }
            }
            
            if usingSettings {
                List {
                    Section {
                        Text((storedUsername ?? "No stored username :("))
                    } header: {
                        Text("Username")
                    }
                    Section {
                        Text(maxStorage)
                    } header: {
                        Text("Maximum available storage")
                    }
                    Section {
                        Text(usedStorage)
                    } header: {
                        Text("Used storage")
                    }
                    Button(action: {
                        let dialog = UIAlertController(title: "Sign out", message: "Are you sure you want to sign out?", preferredStyle: .alert)
                        // In the case of a signout:
                        let signOut = UIAlertAction(title: "Yes", style: .destructive) { _ in
                            fetchSessionID()
                            guard let url = URL(string: "https://notes.hectabit.org/api/sessions/remove") else { return }
                            let parameters = ["secretKey": "\(secretKey ?? "bum")", "sessionId": sessionID]
                            JSONHelper.sendJSONRequest(url: url, parameters: parameters) { result in
                                switch result {
                                case .success:
                                    keychain.delete("secretKey")
                                    UserDefaults.standard.removeObject(forKey: "Username") // This will also trigger SwiftUI to change vstacks
                                    keychain.delete("encryptionKey")
                                    usingSettings = false
                                case .failure(let error):
                                    print("Failed to sign out: \(error)") // This is not supposed to happen under any circumstances unless the session was deauthorized remotely
                                }
                            }
                        }
                        let no = UIAlertAction(title: "No", style: .default)
                        dialog.addAction(signOut);dialog.addAction(no)
                        if let topVC = UIApplication.shared.keyWindow?.rootViewController { topVC.present(dialog, animated: true) } // We can keep using keyWindow, it's not a big deal for this specific usecase that it's deprecated
                    }) {
                        Text("Sign out")
                            .foregroundStyle(Color.red) // Set the text color to red
                    }
                }
            }
        } else {
            // Login screen
            VStack {
                Image("org.hectabit.burgernotes")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .padding(.bottom, 16)
                
                Text("Burgernotes")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Secure, encrypted notes.")
                    .padding(.bottom, 16)
                VStack(spacing: 16) {
                    TextField("Username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    
                    Button(action: login) {
                        Text(loggingIn ? "Sign In" : (signingUp ? "Sign Up" : ""))
                            .foregroundColor(.white)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }

                    HStack {
                        Button(action: {
                            if signingUp {
                                signingUp = false
                                loggingIn = true
                            } else if loggingIn {
                                loggingIn = false
                                signingUp = true
                            }
                        }) {
                            Text(loggingIn ? "Sign up instead" : (signingUp ? "Sign in instead" : ""))
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                        Text("|")
                            .font(.body)
                            .foregroundColor(.blue)
                        Button(action: {
                            if let url = URL(string: "https://notes.hectabit.org/privacy") {
                                let safariViewController = SFSafariViewController(url: url)
                                UIApplication.shared.windows.first?.rootViewController?.present(safariViewController, animated: true, completion: nil)
                            }
                        }) {
                            Text("Privacy Policy")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .opacity(showErrorLabel ? 1 : 0)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }
            .padding()
            .background(Color(.systemBackground))
            .edgesIgnoringSafeArea(.all)
        }
    }

    // Fetch notes
    private func fetchNotes() {
        let secretKey = keychain.get("secretKey")
        guard let url = URL(string: "https://notes.hectabit.org/api/listnotes") else { return }
        let parameters = ["secretKey": "\(secretKey ?? "bum")"]
        
        // Call a JSON request
        JSONHelper.sendJSONRequest(url: url, parameters: parameters) { result in
            switch result {
            case .success(let data):
                if let data = data {
                    // Decode the received notes
                    if let remoteNotes = try? JSONDecoder().decode([Note].self, from: data) {
                        DispatchQueue.main.async {
                            // Remove notes that are not present remotely
                            notes = notes.filter { note in
                                remoteNotes.contains { $0.id == note.id }
                            }
                            
                            // Filter new notes from existing notes
                            let newNotes = remoteNotes.filter { newNote in
                                !notes.contains { $0.id == newNote.id }
                            }
                            
                            // Append the new notes to the existing array
                            notes.append(contentsOf: newNotes)
                        }
                    }
                }
            case .failure(let error):
                print("Error: \(error)") // Aww shit!
            }
        }
    }
    
    private func fetchNoteContent(note: Note) {
        // We need to get the secret and encryptionkeys again here
        let secretKey = keychain.get("secretKey")
        let encryptionKey = keychain.get("encryptionKey")
        guard let url = URL(string: "https://notes.hectabit.org/api/readnote") else { return }
        let parameters = ["secretKey": "\(secretKey ?? "bum")", "noteId": "\(note.id)"]
        
        // Call a JSON request
        JSONHelper.sendJSONRequest(url: url, parameters: parameters) { result in
            switch result {
            case .success(let data):
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    if let responseDict = json as? [String: Any],
                       let encryptedContent = responseDict["content"] as? String {
                        let decryptedContent = encryptedContent.decrypt(password: encryptionKey ?? "this bum ain't got an encryption key!!!")
                        DispatchQueue.main.async {
                            // Set up & open the text editor
                            noteContent = decryptedContent
                            selectedNote = "\(note.id)"
                            isEditing = true
                        }
                    }
                } catch {
                    print("Error decoding JSON response 🙁: \(error)")
                }
                
            case .failure(let error):
                print("Error: \(error)") // Aww shit!
            }
        }
    }

    // Fetch user info (for the settings page)
    private func fetchUserInfo() {
        let secretKey = keychain.get("secretKey")
        guard let url = URL(string: "https://notes.hectabit.org/api/userinfo") else { return }
        let parameters = ["secretKey": "\(secretKey ?? "bum")"]
        
        // Call a JSON request
        JSONHelper.sendJSONRequest(url: url, parameters: parameters) { result in
            switch result {
            case .success(let data):
                if let data = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                        fetchSessionID()
                        DispatchQueue.main.async {
                            // Update the States ('MURICA!!! 🇺🇸🇺🇸🦅) to match that of the API response
                            noteCount = json?["notecount"] as? Int ?? 0
                            maxStorage = SizeHelper().humanReadable(json?["storagemax"] as? String ?? "") // Why is this a string?
                            usedStorage = SizeHelper().humanReadable(json?["storageused"] as? Int ?? 0)
                        }
                    } catch {
                        print("Error decoding JSON response 🙁: \(error)")
                    }
                }
            case .failure(let error):
                print("Error: \(error)") // Aww shit!
            }
        }
    }
    
    // Fetch session ID (for logging out)
    private func fetchSessionID() {
        let secretKey = keychain.get("secretKey")
        guard let url = URL(string: "https://notes.hectabit.org/api/sessions/list") else { return }
        let parameters = ["secretKey": "\(secretKey ?? "bum")"]

        // Call a JSON request
        JSONHelper.sendJSONRequest(url: url, parameters: parameters) { result in
            switch result {
            // In the case of a successful JSON response
            case .success(let data):
                if let data = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
                        // Search for an entry with "thisSession" set to true
                        if let session = json?.first(where: { $0["thisSession"] as? Bool == true }) {
                            DispatchQueue.main.async {
                                // Set our sessionID state to "id" from this response
                                sessionID = session["id"] as? Int ?? 0
                            }
                        } else {
                            // HOW was this called when the user was logged off? (I mean, this will be used for session authorization)
                            print("Is this guy even logged in?")
                        }
                    } catch {
                        print("Error decoding JSON response 🙁: \(error)")
                    }
                }
            // In the case of a failed json response
            case .failure(let error):
                print("Error: \(error)") // Aww shit!
            }
        }
    }
    
    private func saveEditedNoteContent() {
        // We need to get the secret and encryptionkeys again here
        let secretKey = keychain.get("secretKey")
        let encryptionKey = keychain.get("encryptionKey")
        guard let url = URL(string: "https://notes.hectabit.org/api/editnote") else { return }
        
        let formattedContent = noteContent.replacingOccurrences(of: "\n", with: "NEWLINEHERETHISISHACKY") // Hacky solution to a real problem
        let encryptedContent = formattedContent.encrypt(password: encryptionKey ?? "this bum ain't got an encryption key!!!")
        
        let parameters = ["secretKey": "\(secretKey ?? "bum")", "noteId": "\(selectedNote)", "content": encryptedContent]

        // Call a JSON request
        JSONHelper.sendJSONRequest(url: url, parameters: parameters) { result in
            switch result {
                case .success(_):
                    print("Note edited and saved successfully")
                    
                    // Close the text editor
                    DispatchQueue.main.async {
                        isEditing = false
                        noteContent = ""
                    }
                    
                case .failure(let error):
                    print("Error: \(error)") // Aww shit!
            }
        }
    }
}

struct Note: Codable, Equatable {
    let id: Int
    let title: String
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(ColorScheme.allCases, id: \.self, content: ContentView().preferredColorScheme)
    }
}
