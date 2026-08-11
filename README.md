# OpenClaw（小龙虾）一键安装包

在 **macOS** / **Windows** 上双击即可安装 [OpenClaw](https://docs.openclaw.ai/)。

本仓库为**非官方便利封装**：不重新打包 OpenClaw 二进制，而是下载并执行 openclaw.ai 官方安装脚本。

| 平台 | 官方脚本（默认） | 推荐入口 |
|------|------------------|----------|
| macOS | [`install-cli.sh`](https://openclaw.ai/install-cli.sh) → `~/.openclaw`（无需 sudo） | 双击 `OpenClaw Installer.app` |
| Windows | [`install.ps1`](https://openclaw.ai/install.ps1) | 双击 `一键安装-OpenClaw.bat` |

## 给最终用户

### macOS · 方式 A：双击 App（推荐）

1. 拿到 `OpenClaw Installer.app`（或 macOS 的 `.dmg` / `.zip`）
2. 双击 **OpenClaw Installer**
3. 点「开始安装」
4. 在打开的 Terminal 里按提示完成（准备好模型 API Key）

首次打开若被 Gatekeeper 拦截：右键 App → **打开** → **仍要打开**。

### macOS · 方式 B / C

- 双击 `一键安装-OpenClaw.command`
- 或：`./scripts/install-openclaw.sh`（`--skip-onboard` 仅装 CLI）

macOS 系统级安装（可选）：`./scripts/install-openclaw.sh --system`

详见 [使用说明.txt](./使用说明.txt)。

### Windows · 双击 bat（推荐）

1. 解压 `OpenClaw-Installer-Windows-*.zip`
2. 双击 **一键安装-OpenClaw.bat**
3. 若 SmartScreen 拦截：更多信息 → 仍要运行
4. 在黑窗里按提示完成（准备好模型 API Key）
5. **新开** PowerShell 再使用

命令行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-openclaw.ps1
# 仅装 CLI：
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-openclaw.ps1 -SkipOnboard
```

见 [使用说明-Windows.txt](./使用说明-Windows.txt)。ZIP 内另有英文文件名入口 `Install-OpenClaw.bat`（内容相同）。

### 安装成功后怎么用？

见扫盲手册：**[OpenClaw用户手册.txt](./OpenClaw用户手册.txt)**。

**macOS 最短路径：**

```bash
export PATH="$HOME/.openclaw/bin:$PATH"
openclaw gateway status
openclaw dashboard
```

**Windows 最短路径：**

```powershell
$env:Path = "$env:APPDATA\npm;$env:Path"
openclaw gateway status
openclaw dashboard
```

在浏览器控制面板里发一条消息即可。

### 接入飞书（macOS / Windows 均支持）

OpenClaw 通过官方 Feishu 频道与本机 Gateway 连接（默认 WebSocket，无需公网 IP）。**两端命令相同**，仅 PATH 准备方式不同。

完整扫盲步骤见 **[飞书接入说明.txt](./飞书接入说明.txt)**。摘要：

```bash
# macOS
export PATH="$HOME/.openclaw/bin:$PATH"

# Windows PowerShell
# $env:Path = "$env:APPDATA\npm;$env:Path"

openclaw gateway status
openclaw channels login --channel feishu   # 扫码或手动填写 App ID/Secret
openclaw gateway restart
# 若提示配对：
openclaw pairing list feishu
openclaw pairing approve feishu <CODE>
```

官方文档：[Feishu 频道](https://docs.openclaw.ai/channels/feishu)

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

工作流文件：`.github/workflows/build-macos-installer.yml`（macOS runner + Windows runner 并行打包）。

> 未做代码签名时，macOS 首次可能需「右键 → 打开」；Windows 可能需绕过 SmartScreen。

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

## 在 Windows 上本地打成 ZIP

```powershell
cd openclaw-macos-installer
powershell -NoProfile -ExecutionPolicy Bypass -File .\build-windows-zip.ps1
```

产物在 `dist/`：

| 文件 | 说明 |
|------|------|
| `OpenClaw-Installer-macOS-1.0.0.dmg` | macOS：双击挂载后运行 App |
| `OpenClaw-Installer-macOS-1.0.0.zip` | macOS：方便网盘传输 |
| `OpenClaw-Installer-Windows-1.0.0.zip` | Windows：解压后双击 bat |

## 目录结构

```
openclaw-macos-installer/
├── scripts/install-openclaw.sh   # macOS 核心安装逻辑
├── scripts/install-openclaw.ps1  # Windows 核心安装逻辑
├── OpenClaw Installer.app/       # macOS 双击 App
├── 一键安装-OpenClaw.command     # macOS 备用双击
├── 一键安装-OpenClaw.bat         # Windows 双击入口
├── prepare-on-mac.sh             # macOS：同步脚本 + 权限
├── build-dmg.sh                  # macOS 打 DMG/ZIP
├── build-windows-zip.ps1         # Windows 打 ZIP
├── 使用说明.txt                  # macOS 安装说明
├── 使用说明-Windows.txt          # Windows 安装说明
├── OpenClaw用户手册.txt          # 安装后扫盲（双平台）
├── 飞书接入说明.txt              # 飞书/Lark 接入（双平台）
└── README.md
```

修改 `scripts/install-openclaw.sh` 后，在 Mac 上运行 `bash prepare-on-mac.sh`（或 `./build-dmg.sh`）会同步到 App bundle。

## 安装后检查

```bash
openclaw --version
openclaw doctor
openclaw gateway status
openclaw dashboard
```

| 平台 | 日志目录 |
|------|----------|
| macOS | `~/Library/Logs/OpenClawInstaller/` |
| Windows | `%LOCALAPPDATA%\OpenClawInstaller\logs\` |

## 常见问题

### 找不到 `openclaw` / `command not found`

`export PATH=...` 只是把目录加入搜索路径。若该目录里没有 `openclaw` 可执行文件，仍会报找不到。多数情况不是 PATH 没生效，而是**没装上或装到了别处**。

**1. 先确认文件是否存在（macOS Terminal）：**

```bash
echo "$HOME"
ls -la "$HOME/.openclaw/bin"
ls -la "$HOME/.openclaw/bin/openclaw"
type -a openclaw 2>/dev/null
```

| 现象 | 含义 |
|------|------|
| `~/.openclaw` 都没有 | 安装没成功，或没跑完 |
| 有目录但没有 `bin/openclaw` | 安装半截/失败，PATH 再对也没用 |
| 文件存在但 permission denied | 无执行权限（少见） |
| 文件存在、`type` 仍没有 | PATH 或当前 shell 环境有问题 |

**2. 临时 PATH 后重试：**

```bash
export PATH="$HOME/.openclaw/bin:$PATH"
openclaw --version
# 然后新开一个 Terminal 窗口再试
```

**3. 用绝对路径区分问题：**

```bash
"$HOME/.openclaw/bin/openclaw" --version
```

- 绝对路径能跑、`openclaw` 不能 → PATH 未生效  
- 绝对路径也不行 → 安装不完整或包装脚本损坏  

**4. 根本没装成功（最常见）：**

查日志：

```bash
ls -lt ~/Library/Logs/OpenClawInstaller/
# 打开最新 install-*.log 看末尾 ERROR
```

或重装：

```bash
curl -fsSL https://openclaw.ai/install-cli.sh | bash -s -- --no-onboard
ls "$HOME/.openclaw/bin/openclaw"
```

**5. 装到了别的目录：**

系统安装 / Homebrew / 全局 npm 时，可能不在 `~/.openclaw/bin`：

```bash
find "$HOME" /opt/homebrew /usr/local -name openclaw 2>/dev/null | head
ls "$(npm prefix -g 2>/dev/null)/bin/openclaw" 2>/dev/null
export PATH="$(npm prefix -g)/bin:$PATH"   # 若在 npm 全局
```

**6. 环境不对：**

- 必须在 **macOS** Terminal（`uname -s` 应为 `Darwin`），不是 Windows  
- 确认 `whoami` / `$HOME` 与安装时为同一用户  
- 使用英文半角引号，勿用全角字符  

### Installing Homebrew failed / Need sudo

旧版一键包可能走系统安装并装 Homebrew。请用**新版**（默认 `~/.openclaw`，无需 sudo），或先用管理员装好 Homebrew 后再装。

### 当前用户不是 Administrator

默认用户目录安装即可，不必管理员。系统级安装请用 `./scripts/install-openclaw.sh --system`。

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

- 本仓库为**非官方便利封装**，会下载并执行 openclaw.ai 官方安装脚本。
- **macOS 默认**：[`install-cli.sh`](https://openclaw.ai/install-cli.sh)（`~/.openclaw`）；可选 `--system` → [`install.sh`](https://openclaw.ai/install.sh)。
- **Windows 默认**：[`install.ps1`](https://openclaw.ai/install.ps1)；封装层对进程使用 `ExecutionPolicy Bypass`，并以 `-NoOnboard` 安装后尽量执行 `openclaw onboard --install-daemon`。
