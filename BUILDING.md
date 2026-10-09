# Building DayTrace

**Languages / 语言：** [English](#building-daytrace) · [简体中文](#简体中文)

## Requirements

- A Mac with a complete, current Xcode installation and macOS SDK.
- Xcode command-line tools (`xcodebuild`, `codesign`, and `plutil`).
- Python 3 for Native Messaging manifest helper scripts.
- Google Chrome only if you are developing or manually validating website attribution.

The app project supports macOS 13 and later. No third-party Swift package manager dependencies are declared in the Xcode project. The app uses Apple platform frameworks; the extension uses Chrome's built-in extension APIs.

## Build and automated tests

From the repository root:

```sh
xcodebuild -list -project app/DayTraceSpike/DayTrace.xcodeproj
xcodebuild -project app/DayTraceSpike/DayTrace.xcodeproj \
  -scheme DayTrace -configuration Debug \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
xcodebuild -project app/DayTraceSpike/DayTrace.xcodeproj \
  -scheme DayTrace -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -parallel-testing-enabled NO test
xcodebuild -project app/DayTraceSpike/DayTrace.xcodeproj \
  -scheme DayTraceNativeHost -configuration Debug \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Use a temporary DerivedData directory if you want to keep generated files outside the checkout, for example by adding `-derivedDataPath /tmp/DayTrace-DerivedData`. Do not commit DerivedData, `.xcresult`, build products, or local Xcode user data.

The XCTest target loads the DayTrace app executable as its test host. Quit any installed DayTrace instance before running tests: its single-instance guard and startup migration make concurrent test-host execution unsafe. Do not run the suite against a personal production store.

## Signing and permission-dependent behavior

An unsigned build can verify compilation and deterministic tests, but it is not evidence that Input Monitoring or TCC identity works. To manually test keyboard counting, use your own stable Apple Development identity, then grant Input Monitoring in macOS System Settings. The checked-in defaults preserve the existing production Bundle ID, Team, and Chrome extension ID; override them per build without source edits:

```sh
xcodebuild -project app/DayTraceSpike/DayTrace.xcodeproj \
  -scheme DayTrace -configuration Debug \
  DAYTRACE_APP_BUNDLE_ID=com.example.daytrace \
  DAYTRACE_DEVELOPMENT_TEAM=YOURTEAMID \
  DAYTRACE_CHROME_EXTENSION_ID=yourunpackedextensionid \
  build
```

Changing the Bundle ID creates a separate macOS/TCC identity. Existing production installs continue to use `com.wudonggua.daytrace` unless explicitly overridden.

Do not request Accessibility, Full Disk Access, Screen Recording, or other permissions as a workaround. The keyboard listener is listen-only.

## Chrome extension and Native Messaging

Load `extension/chrome/` as an unpacked extension from `chrome://extensions`. Set `DAYTRACE_CHROME_EXTENSION_ID` to its ID before running the development installer. The Native Messaging host name remains `com.daytrace.spike`, independent of both the extension ID and app Bundle ID. Do not add broad host permissions or change the local Unix socket architecture.

Never install the native host system-wide. The supported development flow is user-level and must use an absolute executable path in the generated manifest.

## Local data and test safety

The app writes its database and backups under the current user's Application Support directory. Do not point tests at personal production data. Automated tests should use isolated temporary or in-memory stores. Back up user data before manual restore or deletion tests. No build or test step should require copying a real database into the repository.

## 简体中文

### 环境要求

- 完整安装 Xcode 和 macOS SDK 的 Mac。
- Xcode 命令行工具：`xcodebuild`、`codesign`、`plutil`。
- Native Messaging manifest 辅助脚本需要 Python 3。
- 只有开发或人工验证网站归属时才需要 Google Chrome。

App 工程支持 macOS 13 及以上版本。Xcode 工程未声明第三方 Swift Package 依赖；App 使用 Apple 平台框架，扩展使用 Chrome 内置扩展 API。

### 构建和自动化测试

在仓库根目录运行 English 部分中的 `xcodebuild` 命令即可。也可通过 `-derivedDataPath /tmp/DayTrace-DerivedData` 将生成文件放在仓库外。不要提交 DerivedData、`.xcresult`、构建产物或本地 Xcode 用户状态。

Native Host 使用独立的 `DayTraceNativeHost` scheme 构建。Chrome 扩展是静态 Manifest V3 文件，无需编译；可用 `python3 -m json.tool extension/chrome/manifest.json` 检查 JSON。

XCTest target 会加载 DayTrace App 可执行文件作为测试宿主。运行测试前请退出已安装的 DayTrace：单实例保护和启动迁移使并行启动测试宿主不安全。不要让测试指向个人生产数据库。

### 签名和权限相关行为

未签名构建可用于编译和确定性测试，但不能证明 Input Monitoring 或 TCC 身份正常。人工测试键盘计数时，应使用开发者自己的稳定 Apple Development 签名，并在 macOS“系统设置”中授予 Input Monitoring。工程默认保留现有正式 Bundle ID、Team 和 Chrome 扩展 ID；可使用 `DAYTRACE_APP_BUNDLE_ID`、`DAYTRACE_DEVELOPMENT_TEAM`、`DAYTRACE_CHROME_EXTENSION_ID` 按构建覆盖。改变 Bundle ID 会创建新的 macOS/TCC 身份；未覆盖时正式安装身份仍为 `com.wudonggua.daytrace`。

不要以 Accessibility、Full Disk Access、Screen Recording 或其他权限作为绕过方案；键盘监听必须保持 listen-only。

### Chrome 扩展与 Native Messaging

在 `chrome://extensions` 打开开发者模式并加载 `extension/chrome/`。运行开发安装脚本前，将 `DAYTRACE_CHROME_EXTENSION_ID` 设为当前扩展 ID；用户级 Native Messaging manifest 会使用该值。Host 名称仍固定为 `com.daytrace.spike`，与 App Bundle ID 和 Extension ID 相互独立。不要增加宽泛 host permissions，也不要改变本地 Unix socket 架构。

Native Host 只能按用户级方式安装，生成的 manifest 必须使用可执行文件的绝对路径；禁止 system-wide 安装。

### 本地数据与测试安全

应用将数据库和备份写入当前用户的 Application Support 目录。不要让测试指向个人生产数据；自动化测试应使用临时或内存存储。人工测试恢复或删除前先备份。构建和测试不应要求把真实数据库复制进仓库。
