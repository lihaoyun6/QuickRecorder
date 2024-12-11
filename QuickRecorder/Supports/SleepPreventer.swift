//
//  SleepPreventer.swift
//  QuickRecorder
//
//  Created by apple on 2024/12/9.
//

import Foundation
import IOKit.pwr_mgt

class SleepPreventer {
    static let shared = SleepPreventer()
    private var assertionID: IOPMAssertionID = 0
    
    func preventSleep(reason: String) {
        let type = "PreventUserIdleDisplaySleep" as CFString
        let reason = reason as CFString
        let result = IOPMAssertionCreateWithName(type, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &assertionID)
        if result != kIOReturnSuccess { print("Failure to prevent sleep, error: \(result)") }
    }
    
    func allowSleep() {
        let result = IOPMAssertionRelease(assertionID)
        if result != kIOReturnSuccess { print("Failed to release assertion, error: \(result)") }
    }
}
