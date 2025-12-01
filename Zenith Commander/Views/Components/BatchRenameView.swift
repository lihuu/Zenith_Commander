//
//  BatchRenameView.swift
//  Zenith Commander
//
//  批量重命名模态窗口
//

import SwiftUI

struct BatchRenameView: View {
    @Binding var isPresented: Bool
    @Binding var findText: String
    @Binding var replaceText: String
    @Binding var useRegex: Bool
    
    let selectedFiles: [FileItem]
    let onApply: () -> Void
    var onDismiss: (() -> Void)? = nil  // 关闭时的回调
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "pencil.line")
                    .foregroundColor(Theme.accent)
                Text("Batch Rename")
                    .font(.system(size: 14, weight: .semibold))
                Text("(\(selectedFiles.count) items)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
                
                Spacer()
                
                Button(action: { dismissView() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() }
                    else { NSCursor.pop() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.backgroundTertiary)
            
            Divider()
                .background(Theme.border)
            
            // 输入区域
            VStack(spacing: 16) {
                // 查找
                VStack(alignment: .leading, spacing: 6) {
                    Text("Find (Match string)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                    
                    TextField("e.g. IMG_", text: $findText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Theme.background)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.borderLight, lineWidth: 1)
                        )
                }
                
                // 替换
                VStack(alignment: .leading, spacing: 6) {
                    Text("Replace with")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                    
                    TextField("e.g. Photo_{n}", text: $replaceText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Theme.background)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.borderLight, lineWidth: 1)
                        )
                }
                
                // 选项
                HStack(spacing: 12) {
                    // Regex 开关
                    Toggle(isOn: $useRegex) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 10))
                            Text("Regex")
                                .font(.system(size: 11))
                        }
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    
                    Spacer()
                    
                    // 动态变量按钮
                    Button(action: { replaceText += "{n}" }) {
                        Text("+ {n}")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(SmallButtonStyle())
                    
                    Button(action: { replaceText += "{date}" }) {
                        Text("+ {date}")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(SmallButtonStyle())
                }
            }
            .padding(16)
            .background(Theme.backgroundSecondary)
            
            Divider()
                .background(Theme.border)
            
            // 预览区域
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
                
                ScrollView {
                    VStack(spacing: 0) {
                        // 表头
                        HStack {
                            Text("Original Name")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("New Name Preview")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.backgroundTertiary)
                        
                        // 文件列表
                        ForEach(Array(selectedFiles.enumerated()), id: \.element.id) { index, file in
                            let newName = previewNewName(file: file, index: index)
                            let hasChange = newName != file.name
                            
                            HStack {
                                Text(file.name)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text(newName)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(hasChange ? Theme.success : Theme.textTertiary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(index % 2 == 0 ? Theme.background : Theme.backgroundSecondary.opacity(0.5))
                        }
                    }
                }
                .frame(height: 150)
                .background(Theme.background)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Theme.borderLight, lineWidth: 1)
                )
            }
            .padding(16)
            .background(Theme.backgroundSecondary)
            
            Divider()
                .background(Theme.border)
            
            // 底部按钮
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismissView()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Apply Rename") {
                    onApply()
                    dismissView()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(findText.isEmpty)
            }
            .padding(16)
            .background(Theme.backgroundTertiary)
        }
        .frame(width: 550)
        .background(Theme.backgroundSecondary)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.borderLight, lineWidth: 1)
        )
    }
    
    // MARK: - 辅助方法
    
    /// 关闭视图并调用回调
    private func dismissView() {
        isPresented = false
        onDismiss?()
    }
    
    // MARK: - 预览新文件名
    
    private func previewNewName(file: FileItem, index: Int) -> String {
        guard !findText.isEmpty else { return file.name }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        
        let processedReplace = replaceText
            .replacingOccurrences(of: "{n}", with: String(format: "%03d", index + 1))
            .replacingOccurrences(of: "{date}", with: dateString)
        
        if useRegex {
            if let regex = try? NSRegularExpression(pattern: findText, options: []) {
                let range = NSRange(file.name.startIndex..., in: file.name)
                return regex.stringByReplacingMatches(
                    in: file.name,
                    options: [],
                    range: range,
                    withTemplate: processedReplace
                )
            }
            return file.name
        } else {
            return file.name.replacingOccurrences(of: findText, with: processedReplace)
        }
    }
}

// MARK: - 自定义按钮样式

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.accent)
            .cornerRadius(6)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Theme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.backgroundElevated)
            .cornerRadius(6)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SmallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.backgroundTertiary)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.borderLight, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: 12))
                .foregroundColor(configuration.isOn ? Theme.accent : Theme.textTertiary)
            
            configuration.label
                .foregroundColor(Theme.textSecondary)
        }
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        
        BatchRenameView(
            isPresented: .constant(true),
            findText: .constant("IMG_"),
            replaceText: .constant("Photo_{n}"),
            useRegex: .constant(false),
            selectedFiles: [
                FileItem(id: "1", name: "IMG_001.jpg", path: URL(fileURLWithPath: "/test"), type: .file, size: 1024, modifiedDate: Date(), createdDate: Date(), isHidden: false, permissions: "644", fileExtension: "jpg"),
                FileItem(id: "2", name: "IMG_002.jpg", path: URL(fileURLWithPath: "/test"), type: .file, size: 1024, modifiedDate: Date(), createdDate: Date(), isHidden: false, permissions: "644", fileExtension: "jpg")
            ],
            onApply: { }
        )
    }
}
