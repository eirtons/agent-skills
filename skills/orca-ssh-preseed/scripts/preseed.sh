#!/usr/bin/env bash
# 在 WSL 中运行：读取本机 Orca 的版本/缓存，把 node 运行时和 orcad 预装到远程服务器。
# 用法：preseed.sh <Windows ~/.ssh/config 里的主机别名> [--force]
set -euo pipefail

HOST=${1:?用法：preseed.sh <主机别名> [--force]}
FORCE=0; [ "${2:-}" = --force ] && FORCE=1
HERE=$(cd "$(dirname "$0")" && pwd)

WIN_USER=$(cd /mnt/c && cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')
RES=/mnt/c/Users/$WIN_USER/AppData/Local/Programs/orca/resources
ART=/mnt/c/Users/$WIN_USER/AppData/Roaming/orca/orcad-artifacts
ssh_() { (cd /mnt/c && ssh.exe -o BatchMode=yes -o ConnectTimeout=15 "$HOST" "$@"); }
ssh_n() { (cd /mnt/c && ssh.exe -n -o BatchMode=yes -o ConnectTimeout=15 "$HOST" "$@"); }

echo "== 检查免密登录"
ssh_n true || { echo "无法免密登录 $HOST，请先配置 ~/.ssh/config 和公钥"; exit 1; }

echo "== 识别服务器平台"
read -r ARCH LIBC GLIBC < <(ssh_n 'a=$(uname -m); o=$(LC_ALL=C ldd --version 2>&1 || true)
  if echo "$o" | grep -qi musl; then l=musl; v=0; else l=glibc; v=$(echo "$o" | head -1 | grep -oE "[0-9]+\.[0-9]+$"); fi
  echo $a $l $v' | tr -d '\r')
case $ARCH in x86_64) A=x64; DEB_ARCH=amd64;; aarch64|arm64) A=arm64; DEB_ARCH=arm64;; *) echo "不支持的架构 $ARCH"; exit 1;; esac
TARGET=linux-$A-$LIBC
if [ "$LIBC" = glibc ] && [ "$(printf '%s\n2.28\n' "$GLIBC" | sort -V | head -1)" != 2.28 ]; then
  [ "$A" = x64 ] || { echo "arm64 + glibc $GLIBC 低于 2.28，Orca 不支持"; exit 1; }
  TARGET=linux-x64-glibc217
fi
echo "   $ARCH / $LIBC $GLIBC -> $TARGET"

ORCA_VER=$(orca-ide --version 2>/dev/null | tr -d '\r' | head -1)
CACHE=$(ls -dt "$ART/$TARGET"/*/ 2>/dev/null | head -1 || true)
if [ -z "$CACHE" ] || [ ! -f "$CACHE/.version" ]; then
  echo "本机还没有 $TARGET 的 orcad 缓存。请在 Orca 里对 $HOST 点一次“连接”，"
  echo "等约 30 秒（本机会先生成缓存），然后完全退出 Orca，再重跑本脚本加 --force。"
  exit 2
fi
ORCAD_VER=$(basename "$CACHE")
EXE_SHA=$(tr -d '\r\n' < "$CACHE/.runtime-node")
read -r NODE_VER NODE_ARCHIVE NODE_SOURCE < <(python3 - "$RES/orcad-template/orcad.js" "$TARGET" <<'EOF'
import re,sys
s=open(sys.argv[1],encoding='utf-8').read()
ver=re.search(r'\{version:"([0-9.]+)",electron:',s).group(1)
m=re.search(r'"%s":\{source:"(\w+)",archive:"([^"]+)"'%re.escape(sys.argv[2]),s)
print(ver,m.group(2),m.group(1))
EOF
)
echo "   Orca $ORCA_VER / orcad $ORCAD_VER / node $NODE_VER ($NODE_SOURCE)"

echo "== 生成文件清单"
PKG=$(mktemp -d)
trap 'rm -rf "$PKG"' EXIT
cp "$HERE/remote.sh" "$PKG/"
(cd "$CACHE" && find . -type f -printf '%P\n' | sort | xargs -d '\n' sha256sum) > "$PKG/manifest.sha256"
awk '{print $1, $2}' "$PKG/manifest.sha256" > "$PKG/manifest.txt"
mkdir -p "$PKG/extra" && (cd "$CACHE" && cp --parents .version .server-target .runtime-node "$PKG/extra/")
echo "   $(wc -l < "$PKG/manifest.txt") 个文件"

echo "== 在服务器上下载、组装、校验"
REMOTE_W=/tmp/orca-preseed-$$
tar -czf - -C "$PKG" . | ssh_ "mkdir -p $REMOTE_W && tar -xzf - -C $REMOTE_W"
set +e
ssh_n "${ORCA_REMOTE_ROOT:+ORCA_REMOTE_ROOT=$ORCA_REMOTE_ROOT }bash $REMOTE_W/remote.sh '$TARGET' '$NODE_VER' '$NODE_ARCHIVE' '$NODE_SOURCE' '$EXE_SHA' '$ORCAD_VER' '$ORCA_VER' '$DEB_ARCH' '$FORCE'; rc=\$?; rm -rf $REMOTE_W; exit \$rc"
rc=$?
set -e
[ $rc = 0 ] && echo "== 完成。现在在 Orca 里同步 ~/.ssh/config 并连接 $HOST 即可。"
exit $rc
