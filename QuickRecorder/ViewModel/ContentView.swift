//
//  ContentView.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/16.
//

import SwiftUI
import AVFoundation
import ScreenCaptureKit

struct ContentView: View {
    var fromStatusBar = false
    @State private var window: NSWindow?
    @State private var xmarkGlowing = false
    @State private var infoGlowing = false
    @State private var micGlowing = false
    //@State private var showSettings = false
    @State private var isPopoverShowing = false
    @State private var micList = SCContext.getMicrophone()
    @AppStorage("enableAEC") private var enableAEC: Bool = false
    @AppStorage("recordMic") private var recordMic: Bool = false
    @AppStorage("micDevice") private var micDevice: String = "default"
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
            ZStack {
                if !fromStatusBar {
                    Color.clear
                        .background(.ultraThinMaterial)
                        .environment(\.controlActiveState, .active)
                        .cornerRadius(14)
                }
                HStack {
                    Spacer()
                    if #available(macOS 13, *) {
                        ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
                            Button(action: {
                                appDelegate.closeMainWindow()
                                AppDelegate.shared.prepRecord(type: "audio", screens: SCContext.getSCDisplayWithMouse(), windows: nil, applications: nil)
                            }, label: {
                                SelectorView(title: "System Audio".local, symbol: "waveform")
                                    .cornerRadius(8)
                            }).buttonStyle(.plain)
                            Button {} label: {
                                HStack(spacing: -2) {
                                    Button {
                                        recordMic.toggle()
                                    } label: {
                                        ZStack {
                                            Image(systemName: "square.fill")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.primary)
                                                .colorInvert()
                                                .opacity(0.2)
                                            Image(systemName: recordMic ? "checkmark.square" : "square")
                                                .font(.system(size: 16, weight: .medium))
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .onChange(of: recordMic) { _ in  Task { await SCContext.performMicCheck() }}
                                    if micDevice != "default" && enableAEC && recordMic{
                                        Button {
                                            let alert = AppDelegate.shared.createAlert(
                                                title: "Compatibility Warning".local,
                                                message: "The \"Acoustic Echo Cancellation\" is enabled, but it won't work on now.\n\nIf you need to use a specific input with AEC, set it to \"Default\" and select the device you want in System Preferences.\n\nOr you can start recording without AEC.".local,
                                                button1: "OK".local, button2: "System Preferences".local)
                                            if alert.runModal() == .alertSecondButtonReturn {
                                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.sound?input")!)
                                            }
                                        } label: {
                                            ZStack {
                                                Image(systemName: "circle.fill").font(.system(size: 15))
                                                Image(systemName: "exclamationmark")
                                                    .font(.system(size: 11.5, weight: .black))
                                                    .foregroundColor(.black)
                                                    .blendMode(.destinationOut)
                                            }.compositingGroup()
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 24).fixedSize()
                                        .padding(.leading, 1)
                                    } else {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(recordMic ? .primary : .secondary)
                                            .frame(width: 24)
                                            .padding(.leading, 1)
                                    }
                                    if #available(macOS 14, *) {
                                        Picker("", selection: $micDevice) {
                                            Text("Default".local).tag("default")
                                            ForEach(micList, id: \.self) { device in
                                                Text(device.localizedName).tag(device.localizedName)
                                            }
                                        }.frame(width: 90)
                                            .background(
                                                ZStack {
                                                    Color.primary
                                                        .opacity(0.1)
                                                        .cornerRadius(4)
                                                        .padding([.top, .bottom], -1)
                                                        .padding([.leading, .trailing], 3)
                                                        .padding(.trailing, -16)
                                                    Image(systemName: "chevron.up.chevron.down")
                                                        .offset(x: 50)
                                                }
                                            )
                                            .disabled(!recordMic)
                                            .padding(.leading, -10)
                                            .frame(width: 99)
                                            .onAppear{
                                                let list = micList.map({ $0.localizedName })
                                                if !list.contains(micDevice) { micDevice = "default" }
                                            }
                                    } else {
                                        Spacer().frame(width: 6)
                                        Picker("", selection: $micDevice) {
                                            Text("Default".local).tag("default")
                                            ForEach(micList, id: \.self) { device in
                                                Text(device.localizedName).tag(device.localizedName)
                                            }
                                        }
                                        .disabled(!recordMic)
                                        .padding(.leading, -7.5)
                                        .frame(width: 100)
                                        .onAppear{
                                            let list = micList.map({ $0.localizedName })
                                            if !list.contains(micDevice) { micDevice = "default" }
                                        }
                                    }
                                }.padding(.leading, -5)
                            }.buttonStyle(.plain)
                            .scaleEffect(0.69)
                            .padding(.bottom, 4)
                            .frame(width: 110)
                            .background(.primary.opacity(0.00001))
                        }
                        Divider().frame(height: 70)
                    }
                    Button(action: {
                        appDelegate.closeMainWindow()
                        appDelegate.createNewWindow(view: ScreenSelector(), title: "Screen Selector".local)
                    }, label: {
                        SelectorView(title: "Screen".local, symbol: "tv.inset.filled")
                            .cornerRadius(8)
                    }).buttonStyle(.plain)
                    Divider().frame(height: 70)
                    Button(action: {
                        appDelegate.closeMainWindow()
                        SCContext.updateAvailableContent{
                            DispatchQueue.main.async {
                                appDelegate.showAreaSelector(size: NSSize(width: 600, height: 450))
                                var currentDisplay = SCContext.getSCDisplayWithMouse()
                                mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .rightMouseDown, .leftMouseDown, .otherMouseDown]) { event in
                                    let display = SCContext.getSCDisplayWithMouse()
                                    if display != currentDisplay {
                                        currentDisplay = display
                                        appDelegate.closeAllWindow()
                                        appDelegate.showAreaSelector(size: NSSize(width: 600, height: 450))
                                    }
                                }
                            }
                        }
                    }, label: {
                        SelectorView(title: "Screen Area".local, symbol: "viewfinder")
                            .cornerRadius(8)
                    })
                    .buttonStyle(.plain)
                    Divider().frame(height: 70)
                    Button(action: {
                        appDelegate.closeMainWindow()
                        appDelegate.createNewWindow(view: AppSelector(), title: "App Selector".local)
                    }, label: {
                        SelectorView(title: "Application".local, symbol: "app", overlayer: "App")
                            .cornerRadius(8)
                    }).buttonStyle(.plain)
                    Divider().frame(height: 70)
                    Button(action: {
                        appDelegate.closeMainWindow()
                        appDelegate.createNewWindow(view: WinSelector(), title: "Window Selector".local)
                    }, label: {
                        SelectorView(title: "Window".local, symbol: "macwindow")
                            .cornerRadius(8)
                    }).buttonStyle(.plain)
                    Divider().frame(height: 70)
                    Button(action: {
                        isPopoverShowing = true
                    }, label: {
                        SelectorView(title: "Mobile Device".local, symbol: "apps.ipad")
                            .cornerRadius(8)
                    }).buttonStyle(.plain)
                        .popover(isPresented: $isPopoverShowing, arrowEdge: .bottom) { iDevicePopoverView(closePopover: { isPopoverShowing = false })}
                    
                    /*Divider().frame(height: 70)
                    Button(action: {
                        
                    }, label: {
                        SelectorView(title: "Tools".local, symbol: "wrench.and.screwdriver")
                            .cornerRadius(8)
                    }).buttonStyle(.plain)*/
                    Divider().frame(height: 70)
                    Button(action: {
                        appDelegate.closeMainWindow()
                        appDelegate.openSettingPanel()
                        //if fromStatusBar { appDelegate.openSettingPanel() } else { showSettings = true }
                    }, label: {
                        SelectorView(title: "Preferences".local, symbol: "gearshape")
                            .cornerRadius(8)
                    })
                    .buttonStyle(.plain)
                    //.sheet(isPresented: $showSettings) { SettingsView() }
                    Spacer()
                }.padding([.top, .bottom], 10).padding([.leading, .trailing], 19.5)
            }
            if fromStatusBar {
                Button(action: {
                    NSApp.terminate(self)
                }, label: {
                    Text("Quit")
                        .font(.system(size: 8, weight: .bold))
                        .opacity(xmarkGlowing ? 1.0 : 0.4)
                        .foregroundStyle(.secondary)
                        .onHover{ hovering in xmarkGlowing = hovering }
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(.secondary.opacity(xmarkGlowing ? 1.0 : 0.4), lineWidth: 1)
                                .padding(-1).padding([.leading, .trailing], -0.7)
                        )
                })
                .buttonStyle(.plain)
                .padding([.leading, .top], 6.5)
            } else {
                Button(action: {
                    appDelegate.closeMainWindow()
                }, label: {
                    Image(systemName: "x.circle")
                        .font(.system(size: 12, weight: .bold))
                        .opacity(xmarkGlowing ? 1.0 : 0.4)
                        .foregroundStyle(.secondary)
                        .onHover{ hovering in xmarkGlowing = hovering }
                })
                .buttonStyle(.plain)
                .padding([.leading, .top], 6.5)
            }
        }
    }
    
    struct SelectorView: View {
        var title = "No Title".local
        var symbol = "app"
        var overlayer = ""
        @State private var backgroundOpacity = 0.0001
        
        var body: some View {
            VStack(spacing: 6) {
                Text(title)
                    .opacity(0.95)
                    .font(.system(size: 12))
                    .offset(y: title == "System Audio".local ? -3.5 : 0)
                ZStack {
                    if title == "System Audio".local {
                        Image(systemName: symbol)
                            .opacity(0.95)
                            .offset(y: -9.5)
                            .font(.system(size: 26, weight: .bold))
                    } else {
                        Image(systemName: symbol)
                            .opacity(0.95)
                            .font(.system(size: 36))
                    }
                    Text(overlayer)
                        .fontWeight(.bold)
                        .opacity(0.95)
                        .font(.system(size: 11))
                }
            }
            .frame(width: 110, height: 80)
            .onHover{ hovering in
                backgroundOpacity = hovering ? 0.2 : 0.0001
            }
            .background( .primary.opacity(backgroundOpacity) )
        }
    }
}

struct CountdownView: View {
    @State var countdownValue: Int = 00
    @State private var timer: Timer?
    var atEnd: () -> Void

    var body: some View {
        ZStack {
            Color.mypurple.environment(\.colorScheme, .dark)
            Text("\(countdownValue)")
                .font(.system(size: 72))
                .foregroundColor(.white)
                .offset(y: -10)
            Button(action: {
                timer?.invalidate()
                for w in NSApp.windows.filter({
                    $0.title == "Countdown Panel".local ||
                    $0.title == "Area Overlayer".local
                }) { w.close() }
            }, label: {
                ZStack {
                    Color.white.opacity(0.2)
                    Text("Cancel").foregroundColor(.white)
                }.frame(width: 120, height: 24)
            })
            .buttonStyle(.plain)
            .padding(.top, 96)
        }
        .frame(width: 120, height: 120)
        .cornerRadius(10)
        .onAppear{
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                if countdownValue > 1 {
                    countdownValue -= 1
                } else {
                    timer.invalidate()
                    if let w = NSApp.windows.first(where: { $0.title == "Countdown Panel".local }) { w.close() }
                    atEnd()
                }
            }
        }
    }
}


extension AppDelegate {
    
    func closeMainWindow() { for w in NSApplication.shared.windows.filter({ $0.title == "QuickRecorder".local }) { w.close() } }
    
    func closeAllWindow(except: String = "") {
        for w in NSApp.windows.filter({
            $0.title != "Item-0" && $0.title != ""
            && !$0.title.lowercased().contains(".qma")
            && !$0.title.contains(except) }) { w.close() }
    }
    
    func showAreaSelector(size: NSSize, noPanel: Bool = false) {
        guard let scDisplay = SCContext.getSCDisplayWithMouse() else { return }
        guard let screen = scDisplay.nsScreen else { return }
        let screenshotWindow = ScreenshotWindow(contentRect: screen.frame, backing: .buffered, defer: false, size: size, force: noPanel)
        screenshotWindow.title = "Area Selector".local
        //screenshotWindow.orderFront(self)
        screenshotWindow.orderFrontRegardless()
        if !noPanel {
            let wX = (screen.frame.width - 700) / 2 + screen.frame.minX
            let wY = screen.visibleFrame.minY + 80
            let contentView = NSHostingView(rootView: AreaSelector(screen: scDisplay))
            contentView.frame = NSRect(x: wX, y: wY, width: 780, height: 110)
            contentView.focusRingType = .none
            let areaPanel = NSPanel(contentRect: contentView.frame, styleMask: [.fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
            areaPanel.collectionBehavior = [.canJoinAllSpaces]
            areaPanel.setFrame(contentView.frame, display: true)
            areaPanel.level = .screenSaver
            areaPanel.title = "Start Recording".local
            areaPanel.contentView = contentView
            areaPanel.backgroundColor = .clear
            areaPanel.titleVisibility = .hidden
            areaPanel.isReleasedWhenClosed = false
            areaPanel.titlebarAppearsTransparent = true
            areaPanel.isMovableByWindowBackground = true
            //areaPanel.setFrameOrigin(NSPoint(x: wX, y: wY))
            areaPanel.orderFront(self)
        }
    }
    
    func createCountdownPanel(screen: SCDisplay, action: @escaping () -> Void) {
        guard let screen = screen.nsScreen else { return }
        let countdown = ud.integer(forKey: "countdown")
        if countdown == 0 {
            action()
        } else {
            let wX = (screen.frame.width - 120) / 2 + screen.frame.minX
            let wY = (screen.frame.height - 120) / 2 + screen.frame.minY
            let frame =  NSRect(x: wX, y: wY, width: 120, height: 120)
            let contentView = NSHostingView(rootView: CountdownView(countdownValue: countdown, atEnd: action))
            contentView.frame = frame
            countdownPanel.contentView = contentView
            countdownPanel.setFrame(frame, display: true)
            countdownPanel.makeKeyAndOrderFront(self)
        }
    }
    
    func createNewWindow(view: some View, title: String, random: Bool = false) {
        guard let screen = SCContext.getScreenWithMouse() else { return }
        closeAllWindow()
        var seed = 0.0
        if random { seed = CGFloat(Int(arc4random_uniform(401)) - 200) }
        let wX = (screen.frame.width - 780) / 2 + seed + screen.frame.minX
        let wY = (screen.frame.height - 555) / 2 + 100 + seed + screen.frame.minY
        let contentView = NSHostingView(rootView: view)
        contentView.frame = NSRect(x: wX, y: wY, width: 780, height: 555)
        let window = NSWindow(contentRect: contentView.frame, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = title
        window.contentView = contentView
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(self)
        window.orderFrontRegardless()
    }

    func createAlert(title: String, message: String, button1: String, button2: String = "") -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title.local
        alert.informativeText = message.local
        alert.addButton(withTitle: button1.local)
        if button2 != "" {
            alert.addButton(withTitle: button2.local)
        }
        alert.alertStyle = .critical
        return alert
    }
}

extension View {
    func needScale() -> some View {
        if #available(macOS 13, *) {
            return self.scaleEffect(0.8).padding(.leading, -4)
        } else {
            return self
        }
    }
}


/*#Preview {
    ContentView()
}
*/
