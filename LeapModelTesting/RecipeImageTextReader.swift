//
//  RecipeImageTextReader.swift
//  LeapModelTesting
//
//  Created by Ben Davis on 3/13/26.
//


//
//  RecipeImageTextReader.swift
//  Cookery
//
//  Created by Ben Davis on 8/28/25.
//

import Foundation
import Vision
import OSLog
import SwiftUI
//import FoundationModels

@available(iOS, introduced: 26.0, message: "Available on iOS 26+")
@available(macOS, introduced: 26.0, message: "Available on macOS 26+")
actor RecipeImageTextReader {
    
    
    var observations: [VNRecognizedTextObservation] = []
    
    var candidates: [String] = []
    
    lazy var log: Logger = {
        Logger(subsystem: "LeapModelTesting", category: "RecipeImageTextReader")
    }()
    
    let imageData: [Data]
    
    let splitFractions = Array("½¼⅓⅔¾⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞⅐⅑⅒").map(String.init)
    
    let measurements = ["g", "g.", "kg", "KG", "kg.", "mg", "ml", "ML", "ml.", "l", "cup", "cups", "qt", "pt", "lb", "lbs", "lb.", "lbs.", "fl oz", "fl. oz", "gal", "cm", "mm", "°F", "°C", "°f", "°c", "oz.", "tbsp.", "tsp.", "1/2\"", "1/4\"", "3/4\"", "1\"", "2\"", "1/2", "1/4", "3/4"]
    
    let cookingMethods = ["sauté", "broil", "braise", "roast", "poach", "blanch", "simmer", "whisk", "knead", "marinate"]
    
    let culinaryShorthand = ["pkg", "pkgs", "env", "can", "cans", "jar", "jars", "clove", "cloves", "dash", "pinch", "bbq", "BBQ"]
    
    let otherAbbreviations = ["min", "mins", "hr", "hrs", "sec", "secs", "prep", "preheat", "serves"]
    
    let loanwords = ["crème brûlée", "café", "soufflé", "à la", "côte", "niçoise", "jalapeño", "piñata", "queso", "chorizo", "aioli", "béchamel", "pâté", "ragoût", "hors d’oeuvre", "tortilla", "gnocchi", "risotto", "frittata", "crudo", "ceviche", "de árbol", "crème fraiche"]
    
    let brandStyleWords = ["Crock-Pot", "Instapot", "Instant Pot", "Dutch Oven", "Parmasean", "Chocolate", "Cheddar", "Monterey Jack", "AP Flour", "all-purpose"]
    let problemWords = ["I"]
    
    lazy var customWords: [String] = {
       return splitFractions + measurements + cookingMethods + culinaryShorthand + otherAbbreviations + loanwords + brandStyleWords + problemWords
    }()
    
    init?(imageData: [Data]) async {
        self.imageData = imageData
    }
    
    func generate() async throws {
        let words = self.customWords
        var request = RecognizeDocumentsRequest()
        request.barcodeDetectionOptions.enabled = false
        request.textRecognitionOptions.automaticallyDetectLanguage = true
        request.textRecognitionOptions.useLanguageCorrection = true
        request.textRecognitionOptions.maximumCandidateCount = 1
        
        request.textRecognitionOptions.customWords = words

        
        for data in imageData {
            
            // Perform the request on the image data and return the results.
            do {
                let observations = try await request.perform(on: data)
                
                // Get the first observation from the array.
                guard let document = observations.first?.document else {
                    throw CookeryRecipeOCRError.noDocument
                }
                log.debug("document title: \(document.title?.transcript ?? "N/A")")
                
                
                let paragraphs = document.paragraphs
                
                
                let result = paragraphs.map({ $0.transcript })
                candidates += result
                print("result: \(result)")
                
            }
            catch let error as VisionError {
                if case .unsupportedComputeDevice(_) = error {
                    throw CookeryRecipeOCRError.unsupportedDevice(error: error)
                } else if case VisionError.unsupportedRequest(_) = error {
                    throw CookeryRecipeOCRError.badRequest(error: error)
                }
                else if case VisionError.timeout(_) =  error {
                    throw CookeryRecipeOCRError.timeout(error: error)
                } else if case VisionError.invalidImage(_) = error {
                    throw CookeryRecipeOCRError.invalidImage(error: error)
                } else {
                    throw CookeryRecipeOCRError.unknown(error: error)
                }
            }
            catch let error {
                throw CookeryRecipeOCRError.unknown(error: error)
            }
        }
    }
}
