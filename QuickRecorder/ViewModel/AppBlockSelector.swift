//
//  BundleSelector.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/28.
//

import SwiftUI
import Foundation

struct BundleSelector: View {
    @State private var Bundles = [AppInfo]()
    @State private var isShowingFilePicker = false
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            List(Bundles, id: \.self) { item in
                HStack{
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .onTapGesture {
                            if let index = Bundles.firstIndex(of: item) {
                                _ = withAnimation { Bundles.remove(at: index) }
                            }
                        }
                    Text(item.displayName).font(.system(size: 12))
                }
            }
            HStack {
                Button(action: {
                    self.isShowingFilePicker = true
                }) {
                    Image(systemName: "plus.square.fill")
                        .foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }.padding(.top, -14.5)
        }
        .onAppear {
            if let savedData = UserDefaults.standard.data(forKey: "hiddenApps"),
               let decodedApps = try? JSONDecoder().decode([AppInfo].self, from: savedData) {
                Bundles = decodedApps
            }
        }
        .onDisappear {
            if let encodedData = try? JSONEncoder().encode(Bundles) {
                UserDefaults.standard.set(encodedData, forKey: "hiddenApps")
            }
        }
        .fileImporter(isPresented: $isShowingFilePicker, allowedContentTypes: [.application]) { result in
            do {
                guard let appID = try Bundle(url: result.get())?.bundleIdentifier else { return }
                guard let displayName = try Bundle(url: result.get())?.fileName else { return }
                let app = AppInfo(bundleID: appID, displayName: displayName)
                if !self.Bundles.contains(app) {
                    withAnimation { Bundles.append(app) }
                }
            } catch {
                print("File selection failed: \(error.localizedDescription)")
            }
        }
    }
}

struct AppInfo: Hashable, Codable {
    let bundleID: String
    let displayName: String

}

extension Bundle {
    var bundleName: String? { return object(forInfoDictionaryKey: "CFBundleName") as? String }
    var fileName: String { return self.bundleURL.lastPathComponent }
}
