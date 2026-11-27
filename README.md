# 飞鸟云入口助手（FeiNiao Portable）

一个 Flutter 单代码库应用，同时构建 **安卓 APK** 与 **鸿蒙 HarmonyOS HAP**。

从机场发布页（GitHub / Gitee / jsdelivr 镜像）自动发现全部订阅入口，使用账号密码自动登录 V2Board / SSPanel 面板并获取订阅链接，支持复制、浏览器打开与历史保存。账号与订阅通过系统安全存储（Android Keystore / OpenHarmony Asset Store）加密保存。

## 功能

- 发布页链接自动读取（多镜像并发竞速，国内网络友好）
- 入口自动发现 + 并行可达性探测，按响应速度择优登录
- V2Board / SSPanel 自动登录，获取完整订阅链接
- 账号密码本地加密存储（Keystore AES-GCM / Asset Store）
- 订阅历史保存（最近 20 条）

## 构建前提

- Flutter OHOS 分支（本仓库基于 `3.7.12-ohos-1.0.4`）
- DevEco Studio + HarmonyOS SDK（`5.0.0(12)`）
- `ohos/har/flutter.har` 是鸿蒙引擎依赖包，由 Flutter OHOS SDK 提供，体积较大，不随仓库分发；
  首次构建前请从 SDK 复制到 `ohos/har/`。
- 鸿蒙签名不随仓库提供：在 DevEco Studio 的
  `File > Project Structure > Signing Configs` 中勾选 “Automatically generate signature”，
  由工具在本机生成签名配置。

## 构建

```bash
# 鸿蒙 HAP（需 DevEco Studio SDK + Flutter OHOS 分支）
flutter build hap --release

# 安卓 APK
flutter build apk --release
```

## 许可证

本项目基于 [GPL-3.0](LICENSE) 许可证开源。
