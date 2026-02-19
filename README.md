# MoePeek

macOS 菜单栏翻译工具，选中文字即可翻译。

## 安装

从 [Releases](https://github.com/aspect-build/MoePeek/releases) 下载最新的 `.dmg` 或 `.zip`，将 `MoePeek.app` 拖入 `/Applications`。

### macOS 提示"已损坏，无法打开"

由于应用未经 Apple 签名，macOS Gatekeeper 可能会拦截并提示：

> "MoePeek.app" 已损坏，无法打开。您应该将它移到废纸篓。

这并非文件损坏，而是系统的安全隔离机制。解决方法：

1. 打开 **终端**（Terminal）
2. 输入以下命令后回车，按提示输入密码：

```bash
sudo xattr -r -d com.apple.quarantine /Applications/MoePeek.app
```

之后即可正常打开应用。

## 许可证

[AGPL-3.0](LICENSE)
