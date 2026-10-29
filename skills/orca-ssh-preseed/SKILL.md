---
name: orca-ssh-preseed
description: 给 Orca 新增 SSH 主机前，在服务器上预装 Orca 的 node 运行时和 orcad，避免慢线路上传卡在“正在连接”。Use when 用户要在 Orca 里添加/连接新服务器、SSH 主机一直“正在连接…”、或 Orca 升级后远程主机连不上。
---

# Orca SSH 主机预装

> 全程用中文回复。

## 背景

Orca 首次连接 SSH 主机时，会从本机通过 SFTP 上传约 30MB 的 node 运行时和约 30MB 的 orcad 服务端。线路慢时（跨境、15～30KB/s）会卡住，界面一直显示“正在连接…”。
本 skill 让**服务器自己下载**这些文件：node 从镜像下载，orcad 从 GitHub 上同版本 Orca 的 `.deb` 包中提取，然后按本机缓存的清单逐个校验哈希后放到 Orca 期望的位置。Orca 连接时发现已经装好，就会直接启动。

Orca 的判定规则（逆向自 1.4.244，Orca 升级后若失效需要重新核对）：
- node：`~/.orca-remote/runtimes/node-<可执行文件sha256>/bin/node`，加上 `.verified` 标记文件。
- orcad：`~/.orca-remote/orcad-<版本>/`，必需文件全部存在，并有 `.install-complete` 标记文件；不能残留 `.install-lock` 目录。
- 本机缓存位置：`%APPDATA%\orca\orcad-artifacts\<target>\<版本>\`。缓存目录名就是 orcad 版本，里面是完整文件集。

## 流程

1. **SSH 免密**：在 Windows 的 `C:\Users\<user>\.ssh\config` 里添加主机（别名用英文）。该文件只能 `<机器名>\<user>` 有权限，否则 OpenSSH 会拒绝读取，用 `icacls ... /inheritance:r /grant:r <机器名>\<user>:F` 修正。公钥需要用户自己在 PowerShell 里上传（要输一次密码）：
   ```powershell
   type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh <别名> "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
   ```
2. **预装**（在 WSL 中运行）：
   ```bash
   bash ~/.agents/skills/orca-ssh-preseed/scripts/preseed.sh <别名>
   ```
   - 退出码 2：本机还没有该平台的 orcad 缓存。让用户在 Orca 里点一次连接，等约 30 秒后完全退出 Orca，再加 `--force` 重跑。
   - 退出码 3：服务器上有 `.install-lock`，说明 Orca 正在上传。让用户完全退出 Orca（包括系统托盘），再加 `--force` 重跑。
   - 服务器访问 GitHub 慢时，可以用 `ORCA_DEB_URL=<镜像地址>` 覆盖下载地址（这个变量要在服务器端生效，必要时手动传入）。
3. **连接**：让用户在 Orca「SSH 主机」页面点“同步 ~/.ssh/config”，然后连接。用 `orca-ide host list --json` 确认 `connected: true`，并且出现同名的 `--environment`。

## 排查

- 连接后依然转圈：查看服务器上 `~/.orca-remote/` 有哪些文件在更新，以及 `orcad-*/orcad.log`。
- 日志里的 `agent-state-rules download failed: HTTP 404` 不影响使用。
- `ORCA_REMOTE_ROOT=/tmp/xxx` 可以把安装目录指向临时位置做演练，不影响正式安装。
