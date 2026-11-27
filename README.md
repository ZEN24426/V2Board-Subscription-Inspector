# V2Board Subscription Inspector

**飞鸟云入口助手（FeiNiao Portable）** 是一个基于 Flutter OHOS 分支开发的订阅入口发现与订阅链接获取工具。

项目从用户提供的机场发布页或 README 中提取入口，探测可用站点，并在用户明确选择信任的入口后，尝试登录 V2Board 或 SSPanel 面板获取订阅链接。

> 当前仓库已配置 Android 与 HarmonyOS（OHOS）工程。Flutter 框架支持的其他平台不代表本项目已经完成适配。

## 功能

- 从 GitHub、Gitee、jsDelivr 或自定义 HTTPS 发布页读取入口列表
- 支持 GitHub README 的多个 CDN / Raw 镜像回退
- 提取发布页中的 HTTPS 站点入口，并进行可达性探测
- 支持 V2Board 与 SSPanel 登录并获取订阅链接
- 获取成功后可复制、通过系统浏览器打开，并保存最近 20 条订阅历史
- 账号密码和订阅链接通过平台安全存储保存（单条内容上限为 1024 个 UTF-8 字节，超出时会明确报错）
  - Android：Android Keystore + AES-GCM
  - HarmonyOS：系统 AssetStoreKit
- 登录前显示待访问域名，由用户选择明确授权的入口；不会仅凭 HTTPS 自动认定站点可信

## 平台与技术栈

| 项目 | 当前实现 |
|---|---|
| Android | Flutter Android 工程 + Kotlin 原生桥接 |
| HarmonyOS / OHOS | Flutter OHOS 工程 + ArkTS/ETS 原生桥接 |
| 共享业务与界面 | Dart / Flutter |
| 平台通信 | MethodChannel（`feiniao/portable`） |
| Flutter OHOS SDK | `3.7.12-ohos-1.0.4` |
| HarmonyOS SDK 配置 | `5.0.0(12)` |

目前只维护 Android 与 HarmonyOS 两个目标。OHOS 模块当前声明的设备类型为 phone；平板、折叠屏以及 iOS、Windows、macOS、Linux 和 Web 尚未在本仓库配置或验证。

## 项目结构

```text
lib/
  core/       网络请求、URL 解析、数据模型、仓储与订阅获取逻辑
  ui/         Flutter 页面与主题
  main.dart   应用入口
android/      Android 工程与 Kotlin 平台实现
ohos/         HarmonyOS 工程与 ETS 平台实现
test/         Dart / Flutter 自动化测试
```

## 构建环境

### Android

- Flutter SDK（请使用与项目依赖兼容的版本）
- Android SDK / Android Studio
- JDK 与 Android Gradle Plugin 版本以工程配置为准

构建：

```bash
flutter pub get
flutter test
flutter build apk --release
```

用于正式分发的 Release APK 必须使用你自己的签名密钥。请在 `android/key.properties` 配置 `keyAlias`、`keyPassword`、`storeFile` 和 `storePassword`，并将密钥库保存在仓库之外。该文件已被 Git 忽略。未配置正式签名时，构建不会退回使用公共调试证书，产物将保持未签名状态。

### HarmonyOS / OHOS

- Flutter OHOS 分支：`3.7.12-ohos-1.0.4`
- DevEco Studio
- HarmonyOS SDK：`5.0.0(12)`
- 本地 Flutter OHOS SDK 提供的引擎包

本仓库不分发体积较大的 Flutter OHOS 引擎依赖。首次构建前，请从对应版本的 Flutter OHOS SDK 获取 `flutter.har`，放置到：

```text
ohos/har/flutter.har
```

构建 HAP：

```bash
flutter pub get
flutter build hap --release
```

签名材料属于个人开发环境，不应提交到仓库。请在 DevEco Studio 中配置本机签名，或使用本地构建配置。

## 安全说明

本工具会将账号凭据发送到用户选择的面板入口，以执行登录并获取订阅信息。请认真核对登录确认窗口中的域名：

- 只选择你通过官方渠道确认属于服务提供方的入口。
- HTTPS 只能保护传输链路，不能证明站点运营者身份。
- 不要将账号密码、完整订阅链接、Token、Cookie 或真实日志提交到 Issue、Pull Request 或公开截图。
- 如果发布页内容被修改、入口域名发生变化，先通过服务提供方的官方渠道核实，再进行登录。
- 获取到的订阅链接通常包含可直接使用的凭据，应按密码级别保管。

本项目仅用于读取发布页、登录面板和获取订阅链接，不提供代理或 VPN 连接服务。请仅访问你拥有或获准访问的服务，并遵守相关服务条款及当地法律法规。

## 贡献

欢迎通过 GitHub Issues 反馈问题，或提交 Pull Request。提交前请：

1. 运行现有测试。
2. 不要包含真实账号、密码、订阅链接、Token、Cookie、签名文件或密钥。
3. 描述复现步骤、目标平台及 SDK 版本。
4. 涉及平台能力时，注明 Android 或 HarmonyOS 的具体实现与验证情况。

## License

本项目采用 **GNU General Public License v3.0 only（GPL-3.0-only）**，详见 [LICENSE](LICENSE)。
