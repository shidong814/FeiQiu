# 🦐 在 Mac 上编译运行飞秋

## 前置条件

- macOS 13.0 (Ventura) 或更高
- Xcode 14.0 或更高（从 App Store 安装）
- XcodeGen（用于生成 Xcode 项目）

## 第一步：安装 XcodeGen

打开终端执行：

```bash
brew install xcodegen
```

如果没有 Homebrew，先安装：
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## 第二步：获取代码

### 方式 A：从 GitHub Clone
```bash
cd ~/Desktop
git clone https://github.com/你的用户名/FeiQiu.git
cd FeiQiu
```

### 方式 B：拷贝项目文件夹
把 FeiQiu 整个文件夹拷贝到 Mac 上，比如放在桌面：
```bash
cd ~/Desktop/FeiQiu
```

## 第三步：生成 Xcode 项目

```bash
xcodegen generate
```

输出类似：
```
⚙️  Generating plists...
⚙️  Generating project...
⚙️  Writing project...
✅  Saved project to FeiQiu.xcodeproj
```

## 第四步：打开项目

```bash
open FeiQiu.xcodeproj
```

或者双击 `FeiQiu.xcodeproj` 文件。

## 第五步：编译运行

1. 在 Xcode 顶部选择 **FeiQiu** scheme 和 **My Mac**
2. 点击 ▶️ 运行按钮，或按 `⌘R`
3. 首次运行会弹出 **本地网络权限** 对话框，点"允许"

## 常见问题

### ❌ "No such module 'Network'"
确保 Deployment Target 设为 macOS 13.0+

### ❌ 编译报 NSItemProvider 错误
确保 Swift Language Version 设为 5.7+

### ❌ 端口 2425 被占用
检查是否有其他飞秋/飞鸽传书在运行：
```bash
lsof -i :2425
```

### ❌ 发现不了 Windows 飞秋用户
1. 确认 Mac 和 Windows 在同一网段
2. 检查 macOS 防火墙：系统设置 → 网络 → 防火墙 → 关闭或添加例外
3. 在飞秋里点"刷新"按钮重新广播

## 测试步骤

1. Mac 启动飞秋 App
2. Windows 启动飞秋
3. 确认两台设备同一 WiFi
4. Mac 侧边栏应显示 Windows 用户
5. Windows 飞秋应显示 Mac 用户
6. 互发消息测试
7. 互传文件测试

## 打包分发（DMG）

```bash
# Release 编译
xcodebuild -project FeiQiu.xcodeproj \
  -scheme FeiQiu \
  -configuration Release \
  -derivedDataPath build

# 找到编译产物
open build/Build/Products/Release/
```
