import SwiftUI
import Combine

struct ContentView: View {
    // 基础数据状态
    @State private var address: String = "FF00D400"
    @State private var memoryData: [UInt8] = Array(repeating: 0, count: 256)
    
    // 编辑弹窗状态
    @State private var isShowingEditSheet = false
    @State private var editingIndex: Int = 0
    @State private var newValueString: String = ""
    
    // 自动刷新逻辑
    @State private var isAutoRefresh: Bool = false
    @State private var refreshInterval: Double = 1.0
    @State private var timerSubscription: AnyCancellable? = nil
    
    let bridge = PhysMemBridge()
    
    // 自定义颜色：适配 macOS 11 (11.0 没有 Color.cyan)
    let myCyan = Color(red: 0.0, green: 0.8, blue: 0.8)
    
    // 网格布局定义
    let hexColumns = Array(repeating: GridItem(.fixed(32), spacing: 4), count: 16)
    let asciiColumns = Array(repeating: GridItem(.fixed(12), spacing: 2), count: 16)

    var body: some View {
        VStack(spacing: 0) {
            // --- 顶部工具栏 (11.0 兼容风格) ---
            VStack(spacing: 10) {
                HStack(spacing: 20) {
                    HStack {
                        Text("Address: 0x").foregroundColor(.green).font(.system(.body, design: .monospaced))
                        TextField("Hex", text: $address)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(5).background(Color.black.opacity(0.5)).cornerRadius(4)
                            .foregroundColor(.white).frame(width: 100)
                    }
                    
                    // 手动刷新按钮：替代 macOS 12 的样式
                    Button(action: loadMemory) {
                        Text("Refresh")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(5)
                    }.buttonStyle(PlainButtonStyle())

                    Toggle(isOn: $isAutoRefresh) {
                        Text("Auto Refresh").foregroundColor(.white)
                    }
                    .onChange(of: isAutoRefresh) { _ in setupTimer() }
                }

                HStack {
                    Text("Interval:").foregroundColor(.gray).font(.caption)
                    Slider(value: $refreshInterval, in: 0.1...5.0, step: 0.1)
                        .frame(width: 150)
                        .onChange(of: refreshInterval) { _ in setupTimer() }
                    Text(String(format: "%.1f s", refreshInterval)).foregroundColor(.white).font(.caption).frame(width: 40)
                    Spacer()
                }
            }
            .padding().background(Color(white: 0.15))

            // --- 核心显示区 ---
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                HStack(alignment: .top, spacing: 25) {
                    // 左侧：16x16 Hex 矩阵
                    VStack(alignment: .leading) {
                        Text("HEX VIEW").font(.caption).foregroundColor(.gray).padding(.bottom, 5)
                        LazyVGrid(columns: hexColumns, spacing: 4) {
                            ForEach(0..<256, id: \.self) { index in
                                Text(String(format: "%02X", memoryData[index]))
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(memoryData[index] == 0 ? .white.opacity(0.2) : myCyan)
                                    .frame(width: 32, height: 32)
                                    .background(Color(white: 0.12)).cornerRadius(2)
                                    .onTapGesture(count: 2) {
                                        startEditing(at: index)
                                    }
                            }
                        }
                    }

                    // 右侧：ASCII 预览
                    VStack(alignment: .leading) {
                        Text("ASCII").font(.caption).foregroundColor(.gray).padding(.bottom, 5)
                        LazyVGrid(columns: asciiColumns, spacing: 4) {
                            ForEach(0..<256, id: \.self) { index in
                                Text(formatASCII(memoryData[index]))
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(memoryData[index] == 0 ? .white.opacity(0.2) : .green)
                                    .frame(width: 12, height: 32)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 820, height: 750)
        .onAppear { loadMemory() }
        // 修改弹窗
        .sheet(isPresented: $isShowingEditSheet) {
            EditSheetView(
                targetAddr: getTargetAddr(),
                hexValue: $newValueString,
                onCancel: { isShowingEditSheet = false },
                onSave: { commitWrite() }
            )
        }
    }

    // --- 逻辑函数 ---
    
    func formatASCII(_ byte: UInt8) -> String {
        (byte >= 32 && byte <= 126) ? String(UnicodeScalar(byte)) : "."
    }

    func loadMemory() {
        // 如果正在弹窗编辑，停止刷新防止 UI 抖动
        guard !isShowingEditSheet else { return }
        
        guard let addr = UInt64(address, radix: 16) else { return }
        if bridge.connect() {
            var temp = [UInt8]()
            for i in 0..<256 {
                temp.append(bridge.read(at: addr + UInt64(i)))
            }
            self.memoryData = temp
        }
    }

    func setupTimer() {
        timerSubscription?.cancel()
        if isAutoRefresh {
            timerSubscription = Timer.publish(every: refreshInterval, on: .main, in: .common)
                .autoconnect()
                .sink { _ in loadMemory() }
        }
    }

    func startEditing(at index: Int) {
        self.editingIndex = index
        self.newValueString = String(format: "%02X", memoryData[index])
        self.isShowingEditSheet = true
    }

    func getTargetAddr() -> String {
        let base = UInt64(address, radix: 16) ?? 0
        return String(format: "%X", base + UInt64(editingIndex))
    }

    func commitWrite() {
        if let val = UInt8(newValueString, radix: 16),
           let base = UInt64(address, radix: 16) {
            bridge.write(at: base + UInt64(editingIndex), value: val)
            isShowingEditSheet = false
            loadMemory()
        }
    }
}

// --- 适配 11.0 的弹窗子视图 ---
struct EditSheetView: View {
    let targetAddr: String
    @Binding var hexValue: String
    var onCancel: () -> Void
    var onSave: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Modify Physical Memory").font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Address: 0x\(targetAddr)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Byte (Hex):")
                    TextField("00", text: $hexValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60)
                }
            }
            .padding()
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)

            HStack(spacing: 20) {
                Button("Cancel", action: onCancel)
                
                // 适配 11.0：手动模拟高亮按钮
                Button(action: onSave) {
                    Text("Write Data")
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(5)
                }.buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .frame(width: 300, height: 220)
    }
}
