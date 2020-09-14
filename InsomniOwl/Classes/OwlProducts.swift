/*
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Foundation
import Parse

public struct OwlProducts {

  // MARK: - Properties
  static let PurchaseNotification = "OwlProductsPurchaseNotification"
  static let randomProductID = "com.dinghing.testpurchase.RandomOwls"
  static let productIDsConsumables: Set<ProductIdentifier> = [randomProductID]
  static let productIDsNonConsumables: Set<ProductIdentifier> = [
    "com.dinghing.testpurchase.3monthsOfRandom",
    "com.dinghing.testpurchase.6monthsOfRandom",
    "com.dinghing.testpurchase.CarefreeOwl",
    "com.dinghing.testpurchase.CouchOwl",
    "com.dinghing.testpurchase.RandomOwls"]

  static let productIDsNonRenewing: Set<ProductIdentifier> = ["com.dinghing.testpurchase.3monthsOfRandom",
        "com.dinghing.testpurchase.6monthsOfRandom"]
  static let randomImages = [
    UIImage(named: "CarefreeOwl"),
//    UIImage(named: "GoodJobOwl"),
    UIImage(named: "CouchOwl")
//    UIImage(named: "NightOwl"),
//    UIImage(named: "LonelyOwl"),
//    UIImage(named: "ShyOwl"),
//    UIImage(named: "CryingOwl"),
//    UIImage(named: "GoodNightOwl"),
//    UIImage(named: "InLoveOwl")
  ]

  public static let store = IAPHelper(productIds: OwlProducts.productIDsConsumables
    .union(OwlProducts.productIDsNonConsumables)
    .union(OwlProducts.productIDsNonRenewing))

  public static func resourceName(for productIdentifier: String) -> String? {
    return productIdentifier.components(separatedBy: ".").last
  }
  
  public static func clearProducts() {
    store.purchasedProducts.removeAll()
  }
  
  public static func handlePurchase(productID: String) {
    if productIDsConsumables.contains(productID) {
      UserSettings.shared.increaseRandomRemaining(by: 5)
      setRandomProduct(with: true)
      
      NotificationCenter.default.post(name: NSNotification.Name(rawValue: PurchaseNotification), object: nil)
    } else if productIDsNonRenewing.contains(productID), productID.contains("3months") {
      handleMonthlySubscription(months: 3)
    } else if productIDsNonRenewing.contains(productID), productID.contains("6months") {
      handleMonthlySubscription(months: 6)
    } else if productIDsNonConsumables.contains(productID) {
      UserDefaults.standard.set(true, forKey: productID)
      store.purchasedProducts.insert(productID)
      
      NotificationCenter.default.post(name: NSNotification.Name(rawValue: PurchaseNotification), object: nil)
    }
  }
  
  public static func setRandomProduct(with paidUp: Bool) {
    if paidUp {
      UserDefaults.standard.set(true, forKey: OwlProducts.randomProductID)
      store.purchasedProducts.insert(OwlProducts.randomProductID)
    } else {
      UserDefaults.standard.set(false, forKey: OwlProducts.randomProductID)
      store.purchasedProducts.remove(OwlProducts.randomProductID)
    }
  }
  
  public static func daysRemainingOnSubscription() -> Int {
    if let expiryDate = UserSettings.shared.expirationDate {
      return Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day!
    }
    return 0
  }
  
  public static func getExpiryDateString() -> String {
    let remaining = daysRemainingOnSubscription()
    if remaining > 0, let expiryDate = UserSettings.shared.expirationDate {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "dd/MM/yyyy"
      return "Subscribed! \nExpires: \(dateFormatter.string(from: expiryDate)) (\(remaining) Days)"
    }
    return "Not Subscribed"
  }
  
  public static func paidUp() -> Bool {
    var paidUp = false
    if OwlProducts.daysRemainingOnSubscription() > 0 {
      paidUp = true
    } else if UserSettings.shared.randomRemaining > 0 {
      paidUp = true
    }
    setRandomProduct(with: paidUp)
    return paidUp
  }
  
  public static func syncExpiration(local: Date?, completion: @escaping (_ object: PFObject?) -> ()) {
    // Query Parse for expiration date.
    
    guard let user = PFUser.current(),
      let userID = user.objectId,
      user.isAuthenticated else {
        return
    }
    
    let query = PFQuery(className: "_User")
    query.getObjectInBackground(withId: userID) {
      object, error in

      let parseExpiration = object?[expirationDateKey] as? Date
      
      // Get to latest date between Parse and local.
      var latestDate: Date?
      if parseExpiration == nil {
        latestDate = local
      } else if local == nil {
        latestDate = parseExpiration
      } else if parseExpiration!.compare(local!) == .orderedDescending {
        latestDate = parseExpiration
      } else {
        latestDate = local
      }
      
      if let latestDate = latestDate {
        // Update local
        UserSettings.shared.expirationDate = latestDate
        
        // See if subscription valid
        if latestDate.compare(Date()) == .orderedDescending {
          setRandomProduct(with: true)
        }
      }
      
      completion(object)
    }
  }
  
  private static func handleMonthlySubscription(months: Int) {
    // Update local and Parse with new subscription.
    
    syncExpiration(local: UserSettings.shared.expirationDate) {
      object in
      
      // Increase local
      UserSettings.shared.increaseRandomExpirationDate(by: months)
      setRandomProduct(with: true)
      
      // Update Parse with extended purchase
      object?[expirationDateKey] = UserSettings.shared.expirationDate
      object?.saveInBackground()
      
      NotificationCenter.default.post(name: NSNotification.Name(rawValue: PurchaseNotification), object: nil)
    }
    
  }
}
