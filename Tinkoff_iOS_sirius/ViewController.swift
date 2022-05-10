//
//  ViewController.swift
//  Tinkoff_iOS_sirius
//
//  Created by Alexander Popov on 08.02.2022.
//

import UIKit
import SystemConfiguration

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    
    @IBOutlet weak var companyNameLabel: UILabel!
    @IBOutlet weak var companySymbolLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var companyImage: UIImageView!
    
    @IBOutlet weak var companyPickerView: UIPickerView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var companies: [String:String] = [:]
    
    override func viewDidLoad(){
        super.viewDidLoad()
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator.startAnimating()
        self.companyNameLabel.text = "Tinkoff"
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        AppDelegate.AppUtility.lockOrientation(UIInterfaceOrientationMask.portrait, andRotateTo: UIInterfaceOrientation.portrait)
        if Reachability.isConnectedToNetwork(){
            self.getCompaniesNames()
        }else{
            self.activityIndicator.stopAnimating()
            self.showAlert(state: "load")
        }
    }

    func clearScreen(){
        self.companyNameLabel.text = "—"
        self.companySymbolLabel.text = "—"
        self.priceLabel.text = "—"
        self.priceChangeLabel.text = "—"
        self.priceChangeLabel.textColor = UIColor.black
        self.companyImage.image =  nil
    }
    
    func showAlert(state: String){
        self.activityIndicator.stopAnimating()
        self.clearScreen()
        let alert =  UIAlertController(title: "Connection error", message: "Check your internet connection and try again", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: {
            action in
            
            state == "work" ? self.requestQuoteUpdate() : self.getCompaniesNames()
            
        }))
        
        present(alert, animated: true)
    }
        
    func getCompaniesNames(){
        
        if !Reachability.isConnectedToNetwork(){
            self.activityIndicator.stopAnimating()
            if (self.companies.count == 0) {
                self.showAlert(state: "load")
            } else {
                self.showAlert(state: "work")
            }
        }
        else{
            
        let dispatch = DispatchGroup()
        dispatch.enter()
        let url = URL(string: "https://cloud.iexapis.com/stable/stock/market/list/mostactive?&token=pk_0b22397a1da047e49544ecfca0a2f555")!
        let dataTask = URLSession.shared.dataTask(with: url) {
            data, response, error in
            guard
                error==nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
            else {
                return
            }
            do{
                
                let infoJson = try JSONSerialization.jsonObject(with: data)
                
                guard
                    let json = infoJson as? [Any]
                else {
                    print("❗️Invalid JSON format")
                    return
                }
                
                for elem in json {
                    let string = elem as? [String:Any]
                    let symbol = string?["symbol"] as? String
                    let companyName = string?["companyName"] as? String
                    self.companies[companyName!] = symbol!
                }
                dispatch.leave()
            }
            catch {
                print("JSON parsing error: " + error.localizedDescription)
                
            }
        }
        
        dataTask.resume()
        dispatch.notify(queue: .main){
        self.companyPickerView.dataSource = self
        self.companyPickerView.delegate = self
        self.requestQuoteUpdate()
        }
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.companies.keys.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return Array(self.companies.keys)[row]
    }
    
    private func requestQuote(for symbol: String){
        
        self.clearScreen()
        
        if Reachability.isConnectedToNetwork(){
            let url = URL(string: "https://cloud.iexapis.com/stable/stock/\(symbol)/quote?&token=pk_0b22397a1da047e49544ecfca0a2f555")!
            let dataTask = URLSession.shared.dataTask(with: url) {
                data, response, error in
                guard
                    error==nil,
                    (response as? HTTPURLResponse)?.statusCode == 200,
                    let data = data
                else {
                    self.showAlert(state: "work")
                            return
                }
                
                let imageUrl = URL(string: "https://cloud.iexapis.com/stable/stock/\(symbol)/logo?&token=pk_0b22397a1da047e49544ecfca0a2f555")!
                
            let imageTask = URLSession.shared.dataTask(with: imageUrl) {image, response, error in
                    guard
                        error==nil,
                        (response as? HTTPURLResponse)?.statusCode == 200,
                        let image = image
                    else {
                                print("❗️Network Error")
                                return
                    }
               
                self.parseQuote(data:data, image: image)
            }
                imageTask.resume()
            }
            dataTask.resume()
        }else{
            self.showAlert(state: "work")
        }
                
    }

    private func parseQuote(data: Data, image: Data){
        
        do{
            
            let imageJson = try JSONSerialization.jsonObject(with: image)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            guard
                let json = jsonObject as? [String: Any],
                let image = imageJson as? [String: Any],
                let companyName = json["companyName"] as? String,
                let companySymbol = json["symbol"] as? String,
                let price = json["latestPrice"] as? Double,
                let priceChange = json["change"] as? Double,
                let imageUrl = image["url"] as? String
                
            else {
                print("❗️Invalid JSON format")
                return
            }
           
            
            DispatchQueue.main.async {
                self.displayStockInfo(companyName: companyName,
                                      symbol: companySymbol,
                                      price: price,
                                      priceChange:priceChange,
                                      image:imageUrl)
            }
        }
        catch {
            print("JSON parsing error: " + error.localizedDescription)
        }
        
    }

    
    private func displayStockInfo(companyName: String, symbol: String, price: Double, priceChange: Double, image: String){
        
        if (priceChange.description.contains("-")) {
            priceChangeLabel.textColor = UIColor.red
        }
        else if (Double(priceChange.description)! > 0){
            priceChangeLabel.textColor = UIColor.green
        }
        
        self.activityIndicator.stopAnimating()
        self.companyNameLabel.text = companyName.count > 20 ? "\(companyName.prefix(20))..." : companyName
        self.companySymbolLabel.text = symbol
        self.priceLabel.text = "\(price)"
        self.priceChangeLabel.text = "\(priceChange)"
        
        let url = URL(string:image)
            if let data = try? Data(contentsOf: url!)
            {
                companyImage.image = UIImage(data: data)
            }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.activityIndicator.startAnimating()
        let selectedSymbol = Array(self.companies.values)[row]
        self.requestQuote(for: selectedSymbol)
    }
    
    private func requestQuoteUpdate(){
        clearScreen()
        self.activityIndicator.startAnimating()
        let selectedRow = self.companyPickerView.selectedRow(inComponent: 0)
        let selectedSymbol = Array(self.companies.values)[selectedRow]
        self.requestQuote(for: selectedSymbol)
        priceChangeLabel.textColor = UIColor.black
        
    }
}

public class Reachability {

    class func isConnectedToNetwork() -> Bool {

        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)

        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }

        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
            return false
        }

        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        let ret = (isReachable && !needsConnection)

        return ret

    }
}

