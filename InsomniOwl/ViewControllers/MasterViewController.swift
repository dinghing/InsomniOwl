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
import Parse
import StoreKit

class MasterViewController: UIViewController {

  // MARK: - IBOutlets
  @IBOutlet weak var tableView: UITableView!

  // MARK: - Properties
  let showDetailSegueIdentifier = "showDetail"
  let randomImageSegueIdentifier = "randomImage"
	var products: [SKProduct] = []
  let refreshControl = UIRefreshControl()

  // MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    refreshControl.addTarget(self, action: #selector(requestAllProducts), for: .valueChanged)
    tableView.addSubview(refreshControl)
    refreshControl.beginRefreshing()
    requestAllProducts()

    setupNavigationBarButtons()
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(handlePurchaseNotification),
                                           name: NSNotification.Name(rawValue: OwlProducts.PurchaseNotification),
                                           object: nil)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if let user = PFUser.current(), user.isAuthenticated {
      navigationItem.leftBarButtonItem?.title = "Sign Out"
    } else {
      navigationItem.leftBarButtonItem?.title = "Sign In"
    }

    tableView.reloadData()
  }

  func setupNavigationBarButtons() {
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Restore", style: .plain, target: self, action: #selector(restoreTapped))
    navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Sign Out", style: UIBarButtonItem.Style.plain, target: self, action: #selector(signOutTapped))
  }

  @objc func signOutTapped() {
    PFUser.logOut()
    OwlProducts.clearProducts()
    _ = navigationController?.popViewController(animated: true)
  }

  @objc func requestAllProducts() {
    OwlProducts.store.requestProducts { [unowned self] success, products in
      if success, let products = products {
        self.products = products
        DispatchQueue.main.async {//add by dinghing
        self.tableView.reloadData()
        }
      }
      DispatchQueue.main.async {
      self.refreshControl.endRefreshing()
      }
    }
  }

  @objc func restoreTapped(_ sender: AnyObject) {
    // Restore Consumables from Apple
    OwlProducts.store.restorePurchases()

    // Restore Non-Renewing Subscriptions Date saved in Parse
    OwlProducts.syncExpiration(local: UserSettings.shared.expirationDate) { [weak self]  object in

      DispatchQueue.main.async { [weak self] in
        self?.tableView.reloadData()
      }
    }
  }
  
  @objc func handlePurchaseNotification(_ notification: Notification) {
    DispatchQueue.main.async { [weak self] in
      self?.tableView.reloadData()
    }
  }

  // MARK: - Navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == showDetailSegueIdentifier {
      guard let viewController = segue.destination as? DetailViewController,
        let product = sender as? SKProduct else {
          return
      }

      // See if user purchased product
      if OwlProducts.store.isPurchased(product.productIdentifier) {
        let name = OwlProducts.resourceName(for: product.productIdentifier) ?? "default"
        viewController.productName = product.localizedTitle
        viewController.image = UIImage(named: name)
      } else {
        viewController.productName = "No Owl"
        viewController.image = nil
      }
    }
  }
}

// MARK: - Table view data source

extension MasterViewController: UITableViewDelegate, UITableViewDataSource {
  
  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return products.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "cellProduct", for: indexPath) as! ProductCell
    
    let product = products[(indexPath as NSIndexPath).row]
    cell.product = product
    cell.buyButtonHandler = { product in
      OwlProducts.store.buyProduct(product)
    }
    
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let product = products[indexPath.row]
    if OwlProducts.productIDsConsumables.contains(product.productIdentifier)
      || OwlProducts.productIDsNonRenewing.contains(product.productIdentifier) {
        performSegue(withIdentifier: randomImageSegueIdentifier, sender: product)
    } else {
      performSegue(withIdentifier: showDetailSegueIdentifier, sender: product)
    }
  }
}
