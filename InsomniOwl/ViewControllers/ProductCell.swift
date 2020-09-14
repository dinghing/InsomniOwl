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

import UIKit
import StoreKit

class ProductCell: UITableViewCell {

  // MARK: - IBOutlets
  @IBOutlet weak var imgRandom: UIImageView!
  @IBOutlet weak var lblProductName: UILabel!
  @IBOutlet weak var lblPrice: UILabel!
  @IBOutlet weak var btnBuy: UIButton!
  @IBOutlet weak var imgCheckmark: UIImageView!
  
  // MARK: - Properties
  static let priceFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.formatterBehavior = .behavior10_4
    formatter.numberStyle = .currency
    return formatter
  }()

  var buyButtonHandler: ((_ product: SKProduct) -> ())?

  var product: SKProduct? {
    didSet {
      guard let product = product else { return }
      
      // Set button handler
      if btnBuy.allTargets.count == 0 {
        btnBuy.addTarget(self, action: #selector(buyButtonTapped), for: .touchUpInside)
      }
      
      // See if Random product
      imgRandom.isHidden = (product.productIdentifier != OwlProducts.randomProductID)
      
      lblProductName.text = product.localizedTitle
      
      if OwlProducts.store.isPurchased(product.productIdentifier) {
        btnBuy.isHidden = true
        imgCheckmark.isHidden = false
      } else if OwlProducts.productIDsNonRenewing.contains(product.productIdentifier) {
        btnBuy.isHidden = false
        imgCheckmark.isHidden = true
        
        if OwlProducts.daysRemainingOnSubscription() > 0 {
          btnBuy.setTitle("Renew", for: .normal)
          btnBuy.setImage(UIImage(named: "IconRenew"), for: .normal)
        } else {
          btnBuy.setTitle("Buy", for: .normal)
          btnBuy.setImage(UIImage(named: "IconBuy"), for: .normal)
        }
        
        ProductCell.priceFormatter.locale = product.priceLocale
        lblPrice.text = ProductCell.priceFormatter.string(from: product.price)
      } else if IAPHelper.canMakePayments() {
        ProductCell.priceFormatter.locale = product.priceLocale
        lblPrice.text = ProductCell.priceFormatter.string(from: product.price)
        
        btnBuy.isHidden = false
        imgCheckmark.isHidden = true
        btnBuy.setTitle("Buy", for: .normal)
        btnBuy.setImage(UIImage(named: "IconBuy"), for: .normal)
      } else {
        lblPrice.text = "Not available"
        btnBuy.isHidden = true
        imgCheckmark.isHidden = true
      }
    }
  }
  
  @objc func buyButtonTapped(_ sender: AnyObject) {
    buyButtonHandler?(product!)
  }
}
