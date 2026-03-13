//
//  CookeryRecipeOCRError.swift
//  LeapModelTesting
//
//  Created by Ben Davis on 3/13/26.
//
import Foundation

enum CookeryRecipeOCRError: Error, LocalizedError, CustomDebugStringConvertible {
    case timeout(error: Error)
    case invalidImage(error: Error)
    case unsupportedDevice(error: Error)
    case unknown(error: Error)
    case badRequest(error: Error)
    case noDocument
    
    
    var debugDescription: String {
        switch self {
        case .timeout(let error):
            return "Timeout reached for Apple Vision Photo OCR task. Received error: \(error.localizedDescription)"
        case .invalidImage(let error):
            return "Invalid image error for Apple Vision Photo OCR task. Received error: \(error.localizedDescription)"
        case .unsupportedDevice(let error):
            return "Unsupported version error for Apple Vision Photo OCR task. Received error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Uknown VisionError for Apple Vision Photo OCR task. Received error: \(error.localizedDescription)"
        case .badRequest(let error):
            return "Invalid Request VisionError received for OCR Task. Received error: \(error.localizedDescription)"
        case .noDocument:
            return "No document values returned for Apple Vision Photo OCR task."
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .timeout(let error):
            return "Vision OCR Error: Timeout reached: \(error.localizedDescription)"
        case .invalidImage(let error):
            return "Vision OCR Error: Invalid image(s): \(error.localizedDescription)"
        case .unsupportedDevice(let error):
            return "Vision OCR Error: Unsupported device: \(error.localizedDescription)"
        case .unknown(let error):
            return "Vision OCR Error: Unknown error: \(error.localizedDescription)"
        case .badRequest(let error):
            return "Vision OCR Error: Bad request: \(error.localizedDescription)"
        case .noDocument:
            return debugDescription

        }
    }
    
    var failureReason: String? {
        switch self {
        case .timeout(_):
            return "A system timeout was reached while attempting to read recipe photo text."
        case .invalidImage( _):
            return "An image error occurred while attempting to read recipe photo text."
        case .unsupportedDevice( _):
            return "An device error occurred while attempting to read recipe photo text."
        case .unknown( _):
            return "An unknown error occurred while attempting to read recipe photo text."
        case .badRequest( _):
            return "A bad request error occurred while attempting to read recipe photo text."
        case .noDocument:
            return "An document recognition error occured when attempting to read photo text."

        }
    }
    
    var recoverySuggestion: String? {
        return "Please contact support."
    }
}
