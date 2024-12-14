//
//  SurpriseView.swift
//  QuickRecorder
//
//  Created by apple on 2024/12/12.
//

import SwiftUI

func isChineseNewYear() -> Bool {
    let currentDate = Date()
    let chineseCalendar = Calendar(identifier: .chinese)
    let currentComponents = chineseCalendar.dateComponents([.month, .day], from: currentDate)
    if currentComponents.month == 12 {
        guard let nextDate = chineseCalendar.date(byAdding: .day, value: 1, to: currentDate),
              let nextComponents = chineseCalendar.dateComponents([.month], from: nextDate).month else {
            return false
        }
        if nextComponents == 1 { return true }
    }
    if currentComponents.month == 1 && currentComponents.day == 1 { return true }
    return false
}

func isAllowChineseNewYear() -> Bool {
    let allwoedRegions: Set<String> = ["CN", "HK", "MO", "TW", "SG", "MY", "ID", "KR", "VN", "PH"]
    let currentRegionCode = Locale.current.regionCode ?? ""
    return allwoedRegions.contains(currentRegionCode)
}

func isTodayChristmas() -> Bool {
    let calendar = Calendar.current
    let today = Date()
    let components = calendar.dateComponents([.month, .day], from: today)
    return (components.month == 12 && components.day == 24) || (components.month == 12 && components.day == 25)
}

func isAllowChristmas() -> Bool {
    let disallowedRegions: Set<String> = [
        "SA", "AE", "SY", "YE", "LY", "DZ", "OM", "BN", "KP",
        "SO", "MA", "TN", "QA", "DJ", "MR", "BH", "IL", "AL",
        "AF", "AZ", "PK", "BF", "GM", "GN", "GW", "KM", "KW",
        "ML", "BD", "NE", "SL", "SN", "TR", "IR", "ID", "MV",
        "TD", "TM", "UZ", "SR", "GY", "TJ", "TG"
    ]
    let currentRegionCode = Locale.current.regionCode ?? ""
    return !disallowedRegions.contains(currentRegionCode)
}

struct SurpriseView: NSViewRepresentable {
    var snowflakes: [String]
    var width: CGFloat
    var height: CGFloat
    var velocity: CGFloat = 12
    var birthRate: Float = 1
    var lifetime: Float = 24
    var alphaSpeed: Float = -0.07
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        
        let emitterLayer = CAEmitterLayer()
        emitterLayer.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        emitterLayer.emitterShape = .line
        emitterLayer.emitterPosition = CGPoint(x: width / 2, y: height + 50)
        emitterLayer.emitterSize = CGSize(width: width, height: 40) // 横向扩展整个屏幕
        
        emitterLayer.emitterMode = .surface
        emitterLayer.renderMode = .oldestLast
        
        //let snowflakes = ["snowflake1", "snowflake2", "snowflake3", "christmasTree1", "christmasTree2"]
        let cells = snowflakes.map { imageName -> CAEmitterCell in
            let cell = CAEmitterCell()
            cell.birthRate = birthRate
            cell.lifetime = lifetime
            cell.velocity = velocity
            cell.velocityRange = 5
            cell.scale = 0.4
            cell.scaleRange = 0.5
            cell.spin = 0.5
            cell.spinRange = 0.3
            cell.alphaRange = 0.6
            cell.alphaSpeed = alphaSpeed
            cell.emissionRange = CGFloat.pi / 2.5
            cell.contents = NSImage(named: imageName)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            return cell
        }
        
        emitterLayer.emitterCells = cells
        view.layer?.addSublayer(emitterLayer)
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // 在需要时更新视图
    }
}
