//
//  NMInAppPurchase.swift
//  NMInAppPurchase
//
//  Created by Nicolas Mahé on 16/09/16.
//  Copyright © 2016 Nicolas Mahé. All rights reserved.
//

import UIKit
import SwiftyStoreKit
import StoreKit
import NMLocalize

//@TODO: add a NMInAppPurchasePremiumable protocol. So a User class can be generic with the protocol and the setNewLastExpirationDate also

public class NMInAppPurchase: NSObject {
  
  public struct Config {
    var availablePurchase: [String]
    var group: String
    var sharedSecret: String
    var setNewLastExpirationDate: (Date?) -> Void
    
    public init(
      availablePurchase: [String],
      group: String,
      sharedSecret: String,
      setNewLastExpirationDate: @escaping (Date?) -> Void
    ) {
      self.availablePurchase = availablePurchase
      self.group = group
      self.sharedSecret = sharedSecret
      self.setNewLastExpirationDate = setNewLastExpirationDate
    }
  }
  
  public static var config: Config = Config(
    availablePurchase: [String](),
    group: "",
    sharedSecret: "",
    setNewLastExpirationDate: { (lastExpirationDate: Date?) -> Void in
      print("setNewLastExpirationDate is not implemented")
    }
  )
  
  /**
   Open subscription management page
   */
  public class func openSubscriptionManagementPage() {
    UIApplication.shared.openURL(URL(string: "itms-apps://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/manageSubscriptions")!)
    //old url: https://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/manageSubscriptions
  }
  
  /**
   Retrieve products info
   */
  public class func retrieveProductsInfo(
    of productIds: [String],
    success: @escaping (_ products: [SKProduct]) -> Void,
    error: @escaping (_ message: String, _ error: Error?) -> Void
  ) {
    SwiftyStoreKit.retrieveProductsInfo(Set(productIds)) { result in
      
      if let errorV = result.error {
        return error(
          errorV.localizedDescription,
          errorV
        )
      }
      
      if result.invalidProductIDs.isEmpty == false {
        let invalidProductIds = result.invalidProductIDs.reduce(
          "",
          { (prev, actu) -> String in
            return prev + ", " + actu
          }
        )
        return error(
          "Invalid product identifier: " + invalidProductIds,
          nil
        )
      }
      
      guard result.retrievedProducts.isEmpty == false else {
        return error(
          "No product available",
          nil
        )
      }
      
      success(Array(result.retrievedProducts))
    }
  }

  /**
   Check and refresh the IAP
   */
  public class func refreshIAPStatus() {
    
    SwiftyStoreKit.completeTransactions { (products: [Product]) -> Void in
//      transactions
//        .filter {
//          return $0.transactionState == .Purchased || $0.transactionState == .Restored
//        }
//        .forEach { (trans) in
//          print("purchased: \(trans.productId)")
//          
//          IAP.purchase(
//            productId: trans.productId,
//            forUser: User.authenticatedUser
//          )
//      }
      
      self.verifyReceipt()
    }
    
    //Verify that the user is premium
    self.verifyReceipt()
    
  }
  
  /**
   Restore all IAP and purchase them if success
   */
  public class func restore(
    success: ((_ message: String, _ productIds: [Product]) -> Void)? = nil,
    error: ((_ message: String, _ reason: [(Error, String?)]?) -> Void)? = nil
  ) {
    SwiftyStoreKit.restorePurchases() { results in
      if results.restoreFailedProducts.count > 0 {
        error?(
          L("iap.restore.failed"),
          results.restoreFailedProducts
        )
      }
      else if results.restoredProducts.count > 0 {
        success?(
          L("iap.restore.complete"),
          results.restoredProducts
        )
        self.verifyReceipt()
      }
      else {
        error?(
          L("iap.restore.nothing"),
          nil
        )
      }
    }
  }
  
  /**
   Purchase a product for a specific user
   */
  public class func purchase(
    productId: String,
    success: ((_ productId: Product) -> Void)? = nil,
    error: ((_ message: String, _ error: PurchaseError) -> Void)? = nil,
    cancel: ((_ error: SKError) -> Void)? = nil
  ) {
    guard self.config.availablePurchase.contains(productId) else {
      error?(
        "Product id is not valid",
        PurchaseError.invalidProductId(productId: productId)
      )
      return
    }
    
    SwiftyStoreKit.purchaseProduct(productId) { (result: PurchaseResult) in
      switch result {
      case .success(let productId):
        success?(productId)
        self.verifyReceipt()
        
      case .error(let errorV):
        var message = L("iap.purchase.failed")
        
        switch errorV {
        case .failed(let error2):
          let errorT = error2 as NSError
          message = errorT.localizedDescription
          
          if let errorSK = error2 as? SKError {
            switch errorSK.code {
            case .paymentCancelled:
              //user cancelled, do nothing
              cancel?(errorSK)
              return
            default:
              break
            }
          }
          
        case .invalidProductId(_)://(let productId):
          message = L("iap.purchase.error.invalid")
        case .noProductIdentifier:
          message = L("iap.purchase.error.invalid.no_product_identifier")
        case .paymentNotAllowed:
          message = L("iap.purchase.error.payment_not_allowed")
        }
        error?(
          message,
          errorV
        )
      }
    }
  }
  
  /**
   Verify the that the user is premium on the receipt
   */
  fileprivate class func verifyReceipt() {
    self.getLastExpirationDateOnReceipt(
      success: { (lastExpirationDate: Date?) in
        self.config.setNewLastExpirationDate(lastExpirationDate)
      }
    )
  }
  
  /**
   Check the purchases on the receipt to determine if the user is premium
   */
  fileprivate class func getLastExpirationDateOnReceipt(
    success: @escaping (_ expirationDate: Date?) -> Void,
    error: ((_ error: ReceiptError) -> Void)? = nil
  ) {
    
    SwiftyStoreKit.verifyReceipt(password: self.config.sharedSecret) { (result) in
      switch result {
        
      case .success(let receipt):
        
        var premiumExpiration: Date?
        let validUntil = Date()
        
        //helper
        let verifyForProductId = { (productId: String) -> Void in
          let subscriptionResult = SwiftyStoreKit.verifySubscription(
            productId: productId,
            inReceipt: receipt,
            validUntil: validUntil
          )
          switch subscriptionResult {
          case .purchased(let expiresDate):
            print(productId + " valid " + expiresDate.description)
            if let _premiumExpiration = premiumExpiration {
              premiumExpiration = (expiresDate as NSDate).laterDate(_premiumExpiration)
            }
            else {
              premiumExpiration = expiresDate
            }
          case .expired(let expiresDate):
            print(productId + " expire " + expiresDate.description)
          case .notPurchased:
            print(productId + " not purchased")
          }
        }
        
        //check available purchase
        self.config.availablePurchase.forEach { purchase in
          verifyForProductId(purchase)
        }
        
        success(premiumExpiration)
        
      case .error(let errorV):
        print(errorV)
        error?(errorV)
//        let errorT = errorV as NSError
//        switch errorV {
//        case .NoReceiptData:
//          ()
//        case .JSONDecodeError(let string):
//          ()
//        case .NetworkError(let error):
//          ()
//        case .NoRemoteData:
//          ()
//        case .ReceiptInvalid(let receipt, let status):
//          ()
//        case.RequestBodyEncodeError(let error):
//          ()
//        default:
//          ()
//        }
      }
    }
    
  }
  
//  /**
//   Refresh the receipt
//   */
//  private func refreshReceipt() {
//    SwiftyStoreKit.refreshReceipt { result in
//      switch result {
//      case .Success:
//        print("Receipt refresh success")
//      case .Error(let error):
//        print("Receipt refresh failed: \(error)")
//      }
//    }
//  }

}
