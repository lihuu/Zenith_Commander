//
//  SingleFileRenameView.swift
//  Zenith Commander
//
//  单个文件重命名模态窗口
//

import SwiftUI

struct SingleFileRenameView: View {
    @Binding var isPresented: Bool
    @Binding var fileName: String
    
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "pencil.line")
                    .foregroundColor(Theme.accent)
                Text("Rename File")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Button(action: onCancel) {
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
                // 文件名输入框
                VStack(alignment: .leading, spacing: 6) {
                    Text("New name")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                    
                    TextField("Enter new file name", text: $fileName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Theme.background)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.borderLight, lineWidth: 1)
                        )
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            onConfirm()
                        }
                }
                
                Spacer()
                    .frame(height: 4)
            }
            .padding(16)
            
            Divider()
                .background(Theme.border)
            
            // 按钮栏
            HStack(spacing: 12) {
                Spacer()
                
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 12))
                        .frame(minWidth: 80)
                }
                .keyboardShortcut(.cancelAction)
                
                Button(action: onConfirm) {
                    Text("Rename")
                        .font(.system(size: 12))
                        .frame(minWidth: 80)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
            .background(Theme.backgroundTertiary)
        }
        .frame(width: 400)
        .background(Theme.backgroundSecondary)
        .cornerRadius(8)
        .shadow(radius: 8)
        .onAppear {
            isTextFieldFocused = true
            // 选中文件名（不包括扩展名）
            selectFileNameWithoutExtension()
        }
    }
    
    private func selectFileNameWithoutExtension() {
        // 将光标聚焦到文本框，并选中文件名部分（不包括扩展名）
        let components = fileName.split(separator: ".", omittingEmptySubsequences: false)
        if components.count > 1 {
            // 有扩展名的文件
            let nameWithoutExt = components.dropLast().joined(separator: ".")
            // 虽然 TextField 不直接支持选中文本，但我们可以记住位置
            // 这里仅做了设置焦点，实际的文本选中在用户开始输入时会自动替换
        }
    }
}

#Preview {
    @Previewable @State var fileName = "document.txt"
    @Previewable @State var isPresented = true
    
    return ZStack {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
        
        SingleFileRenameView(
            isPresented: $isPresented,
            fileName: $fileName,
            onConfirm: {
                print("Renamed to: \(fileName)")
                isPresented = false
            },
            onCancel: {
                print("Cancelled")
                isPresented = false
            }
        )
    }
}
