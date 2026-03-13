//
//  ChatViewModel.swift
//  LeapModelTesting
//
//  Created by Ben Davis on 3/13/26.
//


import LeapSDK
import LeapModelDownloader
import SwiftUI

@Generatable("A converted recipe")
struct Recipe: Codable, Sendable, Hashable, Equatable {
    
    @Guide("The recipe name.")
    let title: String?
    
    @Guide("The recipe description. Ignore if empty.")
    let recipeDescription: String?
    
    @Guide("Recipe ingredients. Each ingredient, quantity, and unit of measurement should occupy the same ingredient string.")
    let ingredients: [String]
    
    @Guide("The recipe instructions. Do not join separate instructions.")
    let instructions: [String]
    
    let id = UUID()

    init(title: String?, recipeDescription: String?, ingredients: [String], instructions: [String]) {
        self.title = title
        self.recipeDescription = recipeDescription
        self.ingredients = ingredients
        self.instructions = instructions
    }
    
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.ingredients = (try container.decodeIfPresent([String].self, forKey: .ingredients) ?? [])
        self.instructions = (try container.decodeIfPresent([String].self, forKey: .instructions) ?? [])
        self.recipeDescription = try container.decodeIfPresent(String.self, forKey: .recipeDescription)

    }

    
    
    enum CodingKeys: CodingKey {
        case title
        case ingredients
        case instructions
        case recipeDescription
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.ingredients, forKey: .ingredients)
        try container.encode(self.instructions, forKey: .instructions)
        try container.encode(self.recipeDescription, forKey: .recipeDescription)

    }
}


@MainActor @Observable
final class ChatViewModel {
    var isLoading = false
    var conversation: Conversation?
    var output: String?
    var recipe: Recipe?
    
    
    @ObservationIgnored private var modelRunner: ModelRunner?
    @ObservationIgnored private var generationTask: Task<Void, Never>?

    func loadModel() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // LEAP will download the model if needed or reuse a cached copy.
            let modelRunner = try await Leap.load(model: "LFM2.5-VL-1.6B", quantization: "Q4_0", downloadProgressHandler: { progress, speed in
                // progress: Double (0...1)
                // speed: bytes per second
            })
            conversation = modelRunner.createConversation(systemPrompt: "You receive OCR text extracted from recipe photos and return a formatted JSON Recipe object. Ingredient strings should not be split. ")
            self.modelRunner = modelRunner
        } catch {
            print("Failed to load model: \(error)")
        }
    }

    func send(_ text: String) {
        guard let conversation else { return }
        generationTask?.cancel()
        let userMessage = ChatMessage(role: .user, content: [.text(text)])
        generationTask = Task { [weak self] in
            do {
                var options = GenerationOptions()
                options.temperature = 0.1
                try options.setResponseFormat(type: Recipe.self)
                
                for try await response in conversation.generateResponse(
                    message: userMessage,
                    generationOptions: options,
                ) {
                    self?.handle(response)
                }
            } catch {
                print("Generation failed: \(error)")
            }
        }
    }
    

    func stopGeneration() {
        generationTask?.cancel()
    }

    @MainActor
    private func handle(_ response: MessageResponse) {
        switch response {
        case .chunk(let delta):
            if output == nil {
                output = ""
            }
            output! += delta
            print(delta, terminator: "") // Update UI binding here
        case .reasoningChunk(let thought):
            print("Reasoning:", thought)
        case .audioSample(let samples, let sr):
            print("Received audio samples \(samples.count) at sample rate \(sr)")
        case .functionCall(let calls):
            print("Requested calls: \(calls)")
        case .complete(let completion):
            let jsonFragments = completion.message.content.compactMap { part -> String? in
                if case .text(let value) = part { return value }
                return nil
            }
            var jsonText = jsonFragments.joined()
            do {
                print("FINAL JSON TEXT: \n$$$\n\(jsonText)\n$$$\n")
                
                if let range = jsonText.range(of: "```json") {
                    jsonText.removeSubrange(range)
                }
                if let range = jsonText.range(of: #""recipe": {"#) {
                    jsonText.removeSubrange(range)
                }
                
                let regex =  Regex(/]\s+}\s+}/)
                
                /*
                 
                 
                           "
                         ]
                       }
                     }
                     
                 */
                if let range = try regex.ignoresCase().firstMatch(in: jsonText)?.range {
                    jsonText.removeSubrange(jsonText.index(after: range.lowerBound) ..< range.upperBound)
                    jsonText.append("\n}")
                }
                if let range = jsonText.range(of: "```") {
                    jsonText.removeSubrange(range)
                }
                let recipe = try parseRecipe(jsonText)
                self.recipe = recipe
                print("recipe: \(recipe?.title ?? "<N/A>")")
            }
            catch let error {
                fatalError("Failed to handle response with error: \(error.localizedDescription)")
            }
//            if let stats = completion.stats {
//                print("Finished with \(stats.totalTokens) tokens")
//            }
//            
//            let text = completion.message.content.compactMap { part -> String? in
//                if case .text(let value) = part { return value }
//                return nil
//            }.joined()
//            print("Final response:", text)
//            output = text
            // completion.message.content may also include `.audio` entries you can persist or replay
        @unknown default:
            fatalError("Unhandled MessageResponse enum category.")
        }
    }
    
    func parseRecipe(_ recipe: String) throws -> Recipe? {
        guard let data = recipe.data(using: .utf8) else { return nil }
        let recipe = try JSONDecoder().decode(Recipe.self, from: data)
        return recipe
    }
}
