# OpenClaw（小龙虾）macOS 一键安装包

在 macOS 上双击即可安装 [OpenClaw](https://docs.openclaw.ai/)，内部调用官方安装脚本 `https://openclaw.ai/install.sh`（可自动安装 Node、安装 CLI，并引导 onboard）。

## 给最终用户

### 方式 A：双击 App（推荐）

1. 拿到 `OpenClaw Installer.app`（或 `.dmg` / `.zip`）
2. 双击 **OpenClaw Installer**
3. 点「开始安装」
4. 在打开的 Terminal 里按提示完成（准备好模型 API Key）

首次打开若被 Gatekeeper 拦截：

- 右键 App → **打开** → **仍要打开**

### 方式 B：双击 `.command`

双击 `一键安装-OpenClaw.command`，在 Terminal 中直接跑安装脚本。

### 方式 C：命令行

```bash
chmod +x scripts/install-openclaw.sh
./scripts/install-openclaw.sh
```

仅装 CLI、不做引导：

```bash
./scripts/install-openclaw.sh --skip-onboard
```

## 推荐：提交到 GitHub 用 Actions 构建

可以。把本目录单独建成一个 GitHub 仓库后，macOS runner 会自动打出 `.dmg` / `.zip`。

### 1. 创建仓库并推送

在本机（任意系统）进入本目录：

```bash
cd openclaw-macos-installer
git init
git add .
git commit -m "Add OpenClaw macOS one-click installer"
gh repo create openclaw-macos-installer --public --source=. --remote=origin --push
```

或先在 GitHub 网页新建空仓库，再：

```bash
git remote add origin https://github.com/<你的用户名>/openclaw-macos-installer.git
git branch -M main
git push -u origin main
```

### 2. 触发构建

| 触发方式 | 说明 |
|----------|------|
| push 到 `main`/`master` | 改安装相关文件后自动构建 |
| Actions → **Build macOS Installer** → Run workflow | 可手填版本号 |
| 发布 Release（打 tag） | 构建并把 DMG/ZIP 挂到 Release |

### 3. 下载产物

- **Actions**：打开对应 run → Artifacts → `OpenClaw-Installer-macOS-*`
- **Release**：在 Releases 页面直接下载 `.dmg` / `.zip`

工作流文件：`.github/workflows/build-macos-installer.yml`（`runs-on: macos-14`）。

> 未做 Apple 代码签名/公证时，用户首次仍可能需「右键 → 打开」。签名需自备 Developer ID 证书并写入 GitHub Secrets（可后续再加）。

## 从 Windows 拷到 Mac 后（本地打包，必做一次）

Windows 打的 zip **不会保留可执行权限**。在 Mac 上解压后先执行：

```bash
cd openclaw-macos-installer
bash prepare-on-mac.sh
```

然后即可双击 `OpenClaw Installer.app`，或继续打包 DMG。

## 在 Mac 上本地打成 DMG / ZIP

```bash
cd openclaw-macos-installer
bash prepare-on-mac.sh
./build-dmg.sh
```

产物在 `dist/`：

| 文件 | 说明 |
|------|------|
| `OpenClaw-Installer-macOS-1.0.0.dmg` | 双击挂载后拖出 / 运行 App |
| `OpenClaw-Installer-macOS-1.0.0.zip` | 方便微信 / 网盘传输 |

## 目录结构

```
openclaw-macos-installer/
├── OpenClaw Installer.app/     # 双击安装的 App
├── 一键安装-OpenClaw.command   # 备用双击脚本
├── scripts/install-openclaw.sh # 核心安装逻辑
├── build-dmg.sh                # 在 Mac 上打包 DMG
├── 使用说明.txt
└── README.md
```

## 安装后检查

```bash
openclaw --version
openclaw doctor
openclaw gateway status
openclaw dashboard
```

日志目录：`~/Library/Logs/OpenClawInstaller/`

## 系统要求

- macOS 12+
- 网络可访问 `openclaw.ai`
- 建议准备 Anthropic / OpenAI / Google 等模型 API Key（onboard 时填写）

## 代码签名（可选）

未签名时，用户首次需「右键 → 打开」。若有 Apple Developer ID：

```bash
codesign --deep --force --options runtime \
  --sign "Developer ID Application: YOUR NAME" \
  "OpenClaw Installer.app"
./build-dmg.sh
# 再用 notarytool 对 DMG 做公证
```

## 说明

- 本仓库为**官方安装流程的封装**，不重新打包 OpenClaw 二进制。
- 真正的安装仍由官方 `install.sh` 完成，保证与文档一致、便于升级。
