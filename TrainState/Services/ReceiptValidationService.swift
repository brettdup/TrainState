import Foundation
import StoreKit

enum ReceiptValidationError: Error {
    case invalidReceipt
    case verificationFailed
    case noReceiptFound
}

class ReceiptValidationService {
    static let shared = ReceiptValidationService()
    
    private init() {}
    
    func validateReceipt() async throws -> Bool {
        // Get the current app transaction
        guard let appTransaction = try? await AppTransaction.shared else {
            throw ReceiptValidationError.noReceiptFound
        }
        
        // Verify the transaction
        switch appTransaction {
        case .verified:
            // App transaction is verified
            return true
            
        case .unverified:
            throw ReceiptValidationError.verificationFailed
        }
    }
    
    func validateTransaction(_ transaction: Transaction) async throws -> Bool {
        // For StoreKit 2, transactions are already verified when we receive them
        // We just need to check if they're still valid
        
        // Check if the transaction is still valid
        let isValid = !transaction.isUpgraded && 
                     (transaction.expirationDate == nil || 
                      transaction.expirationDate?.compare(Date()) == .orderedDescending)
        
        return isValid
    }
} 