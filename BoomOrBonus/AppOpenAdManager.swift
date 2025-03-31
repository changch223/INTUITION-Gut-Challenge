//
//  Untitled.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

//
//  AppOpenAdManager.swift
//  Reverse2048
//
//  Created by chang chiawei on 2025-03-29.
//

import GoogleMobileAds
import UIKit

class AppOpenAdManager: NSObject, FullScreenContentDelegate {
    static let shared = AppOpenAdManager()
    
    private var appOpenAd: AppOpenAd? // 廣告實體
    private var isLoadingAd = false  // 是否正在載入中
    private var isAdBeingShown = false // 廣告是否正在顯示中
    private let adUnitID = "ca-app-pub-9275380963550837/4495279208"
    
    func loadAd() {
        // 如果正在載入中就直接返回
        guard !isLoadingAd else { return }
        isLoadingAd = true
        print("loadAd")
        
        AppOpenAd.load(
            with: adUnitID,
            request: Request(),
            completionHandler: { [weak self] (ad: AppOpenAd?, error: Error?) in
                self?.isLoadingAd = false
                if let error = error {
                    print("Ad failed to load: \(error.localizedDescription)")
                    // 延遲 65 秒後重試 → 如果有錯誤，就不自動重試，錯誤處理可以交由外部決定
                    // DispatchQueue.main.asyncAfter(deadline: .now() + 65) {
                    //    self?.loadAd()
                    //}
                    
                    return
                }
                self?.appOpenAd = ad
                self?.appOpenAd?.fullScreenContentDelegate = self // 廣告委託（callback）
                
                print("self?.appOpenAd = ad")
                // 這裡可以直接展示廣告，或根據情況決定是否立即展示
                // self?.showAdIfAvailable()
            }
        )
    }
    
    // 顯示廣告（如果有準備好），並最多重試5次
    func showAdIfAvailable(tryCount: Int = 0) {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController,
              let ad = appOpenAd else {
            if tryCount < 5 {
                print("Ad not ready or already being shown. Retrying (\(tryCount + 1)/5)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.showAdIfAvailable(tryCount: tryCount + 1)
                }
            } else {
                print("Retry limit reached, no ad available")
            }
            return
        }
        
        isAdBeingShown = true
        
        ad.present(from: rootVC) // 顯示廣告
        self.appOpenAd = nil // 用完清空
        print("Ad Finish")
        // AppOpenAd の delegate を設定して、表示完了後にフラグを戻すのも◎
        ad.fullScreenContentDelegate = self
    }
    
}

extension AppOpenAdManager {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        isAdBeingShown = false
        print("AppOpenAdManager Open")
    }
}



