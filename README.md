# Alist-FN

将 [AList](https://github.com/AlistGo/alist) 官方 Linux 静态二进制封装为飞牛 fnOS 应用，并在上游发布稳定版后自动构建、发布 `.fpk` 安装包。

## 自动发布

GitHub Actions 每小时检查一次 AList 的最新稳定版。发现本仓库尚未发布的版本后，会：

1. 获取上游 Release 元数据；
2. 下载并校验 `linux-musl-amd64` 和 `linux-musl-arm64` 官方资产；
3. 分别构建 fnOS `x86` 与 `arm` 安装包；
4. 创建 `alist-vX.Y.Z` GitHub Release，附带两个 `.fpk` 和 `SHA256SUMS`。

也可以在 Actions 页手动运行 **Sync AList release**，指定 AList 版本并选择是否覆盖已有发布资产。

> GitHub Actions 不能直接订阅另一个仓库的 Release 事件，因此使用定时轮询；通常在上游发布后 1 小时内开始构建。

## 启用方法

1. 在 GitHub 新建一个空仓库，将本项目推送进去。
2. 打开仓库 **Settings → Actions → General**，确认 Workflow permissions 为 **Read and write permissions**。工作流也声明了 `contents: write`。
3. 在 **Actions** 页手动运行一次工作流，或等待定时任务。

不需要额外 Secret；发布使用仓库自动提供的 `GITHUB_TOKEN`。

## fnOS 应用行为

- 应用 ID：`AlistFN`
- Web 端口：`5244`
- 运行身份：fnOS 专用低权限包用户
- 持久数据：`TRIM_PKGVAR`（AList 的配置、SQLite 数据库、日志等）
- 用户文件：在 fnOS 应用设置中显式授权需要挂载到 AList 的目录
- 桌面入口：`http://<NAS>:5244/`

首次启动后，从 fnOS 桌面打开 AList。初始管理员密码请查看 AList 日志，或在终端执行 AList 官方的管理员密码重置命令。

## 本地构建

需要安装官方 [`fnpack`](https://developer.fnnas.com/docs/cli/fnpack/)：

```bash
./scripts/build-fpk.sh v3.60.0 x86 dist
./scripts/build-fpk.sh v3.60.0 arm dist
```

支持的架构参数：

- `x86`：使用 `alist-linux-musl-amd64.tar.gz`
- `arm`：使用 `alist-linux-musl-arm64.tar.gz`

如已下载上游压缩包，可避免重复下载：

```bash
ALIST_ARCHIVE=/path/to/alist-linux-musl-amd64.tar.gz \
ALIST_SHA256=<sha256> \
./scripts/build-fpk.sh v3.60.0 x86 dist
```

## 目录结构

```text
packaging/                 fnOS 应用包模板
scripts/build-fpk.sh       可复现的本地/CI 构建入口
.github/workflows/         上游版本检测、双架构构建与发布
```

## 安全与许可

构建流程校验 GitHub Release API 提供的上游 SHA-256 摘要；摘要缺失或不匹配时构建失败。`fnpack` 固定使用飞牛官方文档当前列出的 `1.2.3` 版本。

AList 使用 AGPL-3.0 许可证。本项目不修改 AList 二进制，安装包内附上游许可证与来源说明。本项目自己的打包脚本使用 MIT 许可证。

