//
//  ContentView.swift
//  LeapModelTesting
//
//  Created by Ben Davis on 3/13/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var model = ChatViewModel()
    @State private var query = "Write a short (200 word) story about a dog on an adventure."
    @State private var modelOutput: String?
    @State private var showPhotoLibrary: Bool = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var ocrStrings = [String]()
    @State private var ocrError: CookeryRecipeOCRError?
    @State private var showOCRAlert: Bool = false

    
    
    var body: some View {
        VStack {
//            TextField("Query", text: $query, axis: .vertical)
//                .fixedSize(horizontal: false, vertical: true)
//                .multilineTextAlignment(.leading)
            
            HStack {
                Button("Pick Photo") {
                    showPhotoLibrary.toggle()
                }.disabled(model.isLoading)
                    
                Button("Submit") {
                    if let first = photoSelection.first {
                        photoSelection.removeAll()
                        Task {
                            if let data = try? await first.loadTransferable(type: Data.self) {
                                do {
                                    let candidates = try await Task.detached { [data] in
                                        return try await convert(images: [data])
                                    }.value
                                    
                                    
                                    let ocrStrings = candidates ?? []
                                    
                                    if let match = ocrStrings.first {
                                        model.send(match)
                                    }
                                    
                                }
                                catch let error as CookeryRecipeOCRError {
                                    self.ocrError = error
                                    self.showOCRAlert = true
                                }
                                catch let error {
                                    fatalError("Failed to generate Vision candidates for recipe image with error: \(error.localizedDescription)")
                                }
                                
                                
//                                if let jpegData = CGImage.downscaledImage(from: data, maxDimension: 900)?.jpegData() {
//                                    
//                                    model.send(jpegData)
//                                }

                            }

                        }
                    }
                }.disabled(model.isLoading)
            }
            GroupBox("Output") {
                ScrollView(.vertical) {
                    if let r = model.recipe {
                        if let title = r.title {
                            Text(title)
                        }
                        if let description = r.recipeDescription {
                            Text(description)
                        }
                        
                        ForEach(r.ingredients, id: \.self) { ingredient in
                            Text(ingredient)
                        }
                        ForEach(r.instructions, id: \.self) { ingredient in
                            Text(ingredient)
                        }
                    }
                }
            }
        }
        .id(model.recipe)
        .animation(.spring, value: modelOutput)
        .padding()
        .alert(isPresented: $showOCRAlert, error: ocrError, actions: { error in
            Button("OK") {
                showOCRAlert.toggle()
            }
        }, message: { error in
            Text("\(error.failureReason!) \(error.recoverySuggestion!)")
        })
        .photosPicker(
            isPresented: $showPhotoLibrary,
            selection: $photoSelection,
            maxSelectionCount: 1,
            matching:  .playbackStyle(.image),
            preferredItemEncoding: .automatic
        )
        .task {
            await model.loadModel()
            
        }
        .onChange(of: model.output) { oldValue, newValue in
            if let newValue {
                modelOutput = newValue
            }
        }
    }
    
    /// Runs Vision on images, returning OCR document text candidates as a strings array.
    /// - Parameter images: CGImage array
    /// - Returns: Optional Strings array.
    nonisolated func convert(images: [Data]) async throws -> [String]? {
        print("Import Task Start")
        print("-----------------")
        
        let importer = await RecipeImageTextReader(imageData: images)
        
        try await importer?.generate()
        if let candidates = await importer?.candidates {
            return candidates
        }
        return nil
    }
    
}

#Preview {
    ContentView()
}
