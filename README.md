# 小食仓 · Pantry Keeper

一个轻巧的食材与保质期管理应用，使用 Flutter 编写，可从同一套代码构建 Android 和 iOS。

## 功能

- 添加食材、分类、数量和保质期
- 按到期时间排序，并突出显示三天内到期和已过期食材
- 标记已吃完、恢复库存，或删除并撤销
- 本机保存库存数据，无需账号或网络连接

## 本地运行

需要安装 Flutter stable SDK。然后运行：

```sh
flutter pub get
flutter run
```

## 自动构建

GitHub Actions 在推送到 `main`、创建 Pull Request 或手动运行时执行检查和构建。Android 工作流会产出 `armeabi-v7a`、`arm64-v8a` 和 `x86_64` 三种 APK，以及 AAB；macOS 工作流会构建未签名的 iOS app。

在 Actions 的运行页面下载 `pantry-keeper-android` 或 `pantry-keeper-ios-unsigned` 构建产物。
