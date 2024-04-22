//
//  MousePointer.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/21.
//
import SwiftUI
import Foundation
import Cocoa

struct MousePointerView: View {
    @AppStorage("showMouse") private var showMouse: Bool = true
    var event: NSEvent!
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .overlay(
                    ZStack {
                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 4))
                            .foregroundColor(getStrokeColor(event).opacity(0.2))
                            .padding(4)
                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 4))
                            .foregroundColor(getColor(event).opacity(getOpacity(event)))
                            .padding(8)
                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 1))
                            .foregroundColor(.gray)
                            .opacity([.rightMouseDown, .rightMouseDragged, .leftMouseDown, .leftMouseDragged, .otherMouseDown, .otherMouseDragged].contains(event.type) ? 0.3 : 0.0)
                            .padding(10)
                    }
                )
            if !showMouse {
                Circle()
                    .fill(getColor(event).opacity(getOpacity(event)))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    func getOpacity(_ event: NSEvent) -> Double {
        switch event.type {
        case .rightMouseDown, .rightMouseDragged, .leftMouseDown, .leftMouseDragged, .otherMouseDown, .otherMouseDragged:
            return 0.8
        default:
            return 0.2
        }
    }
    
    func getColor(_ event: NSEvent) -> Color {
        switch event.type {
        case .rightMouseDown, .rightMouseDragged:
            return .purple
        case .leftMouseDown, .leftMouseDragged:
            return .blue
        case .otherMouseDown, .otherMouseDragged:
            return .orange
        default:
            return .gray
        }
    }
    
    func getStrokeColor(_ event: NSEvent) -> Color {
        switch event.type {
        case .leftMouseUp, .rightMouseUp, .otherMouseUp, .mouseMoved:
            return .black
        default:
            return .clear
        }
    }
}
