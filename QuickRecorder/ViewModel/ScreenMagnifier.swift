//
//  ScreenMagnifier.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/25.
//
import SwiftUI

struct ScreenMagnifier: View {
    @State var screenShot: NSImage!
    @State var scaleFactor = SCContext.getScreenWithMouse()?.backingScaleFactor ?? 1.0
    var event: NSEvent!
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 2))
                        .padding(1)
                        .foregroundColor(.blue.opacity(0.5))
                )
                .background(
                    Image(nsImage: screenShot!)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: (screenShot?.size.width)!*3, height: (screenShot?.size.height)!*3)
                )
        }
    }
    
    func getOpacity(_ event: NSEvent) -> Double {
        switch event.type {
        case .rightMouseDown, .rightMouseDragged, .leftMouseDown, .leftMouseDragged, .otherMouseDown, .otherMouseDragged:
            return 0.8
        default:
            return 0.3
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
