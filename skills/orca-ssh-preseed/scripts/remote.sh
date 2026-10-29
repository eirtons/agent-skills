#!/usr/bin/env bash
# 在目标服务器上执行：预装 Orca 的 node 运行时和 orcad，让 Orca 连接时跳过慢速上传。
# 由 preseed.sh 打包下发，不要单独调用。
set -euo pipefail

TARGET=$1 NODE_VER=$2 NODE_ARCHIVE=$3 NODE_SOURCE=$4 EXE_SHA=$5 ORCAD_VER=$6 ORCA_VER=$7 DEB_ARCH=$8 FORCE=${9:-0}
W=$(cd "$(dirname "$0")" && pwd)
ROOT=${ORCA_REMOTE_ROOT:-$HOME/.orca-remote}

fetch() { # fetch <out> <url>...
  local out=$1; shift
  for u in "$@"; do
    echo "  下载 $u"
    if command -v curl >/dev/null; then curl -fsSL --connect-timeout 15 --max-time 900 -o "$out" "$u" && return 0
    else wget -q -T 15 -O "$out" "$u" && return 0; fi
  done
  return 1
}
sha() { sha256sum "$1" | cut -d' ' -f1; }

# ---------- 1. node 运行时 ----------
RT=$ROOT/runtimes/node-$EXE_SHA
if [ -f "$RT/.verified" ] && [ -x "$RT/bin/node" ] && [ "$(sha "$RT/bin/node")" = "$EXE_SHA" ]; then
  echo "[node] 已存在，跳过"
else
  echo "[node] 安装 $NODE_ARCHIVE"
  if [ "$NODE_SOURCE" = official ]; then
    urls=("https://mirrors.tencent.com/nodejs-release/v$NODE_VER/$NODE_ARCHIVE"
          "https://registry.npmmirror.com/-/binary/node/v$NODE_VER/$NODE_ARCHIVE"
          "https://nodejs.org/dist/v$NODE_VER/$NODE_ARCHIVE")
  else
    urls=("https://unofficial-builds.nodejs.org/download/release/v$NODE_VER/$NODE_ARCHIVE")
  fi
  fetch "$W/node.tgz" "${urls[@]}" || { echo "[node] 所有下载源都失败"; exit 1; }
  mkdir -p "$W/node" && tar -xzf "$W/node.tgz" -C "$W/node" --wildcards '*/bin/node'
  bin=$(find "$W/node" -path '*/bin/node' -type f | head -1)
  [ "$(sha "$bin")" = "$EXE_SHA" ] || { echo "[node] 可执行文件哈希不符，中止"; exit 1; }
  mkdir -p "$RT/bin" && mv -f "$bin" "$RT/bin/node" && chmod 755 "$RT/bin/node" && : > "$RT/.verified"
  echo "[node] 完成：$("$RT/bin/node" --version)"
fi

# ---------- 2. orcad ----------
D=$ROOT/orcad-$ORCAD_VER
if [ -f "$D/.install-complete" ]; then
  echo "[orcad] $ORCAD_VER 已安装，跳过"
  exit 0
fi
if [ -d "$D/.install-lock" ] && [ "$FORCE" != 1 ]; then
  echo "[orcad] 发现 $D/.install-lock：Orca 可能正在上传。请先完全退出 Orca，再加 --force 重跑"
  exit 3
fi

echo "[orcad] 从 GitHub 下载 Orca $ORCA_VER ($DEB_ARCH)"
fetch "$W/orca.deb" "${ORCA_DEB_URL:-https://github.com/stablyai/orca/releases/download/v$ORCA_VER/orca-ide_${ORCA_VER}_${DEB_ARCH}.deb}" \
  || { echo "[orcad] 下载失败，可设置 ORCA_DEB_URL 指向镜像后重试"; exit 1; }
cd "$W"
if command -v ar >/dev/null; then ar x orca.deb
elif command -v python3 >/dev/null; then
  python3 -c '
import sys
d=open("orca.deb","rb").read();i=8
while i<len(d):
    n=d[i:i+16].decode().strip().rstrip("/");s=int(d[i+48:i+58]);i+=60
    open(n,"wb").write(d[i:i+s]);i+=s+(s&1)'
else echo "[orcad] 服务器缺少 ar 和 python3，无法解包 deb"; exit 1; fi
data=$(ls data.tar.* | head -1)
case $data in *.xz) z=-J;; *.gz) z=-z;; *.zst) z=--zstd;; *) z=;; esac
tar $z -xf "$data" ./opt/Orca/resources/orcad-template ./opt/Orca/resources/ripgrep
find opt -type f -exec sha256sum {} + > index.txt

# 按本机清单（哈希 路径）从安装包里取文件，找不到的用本机随包带来的 extra/
S=$W/stage; missing=0
while read -r h p; do
  src=$(awk -v h="$h" '$1==h{print $2; exit}' index.txt)
  [ -z "$src" ] && [ -f "extra/$p" ] && src="extra/$p"
  if [ -z "$src" ]; then echo "  缺失：$p"; missing=$((missing+1)); continue; fi
  mkdir -p "$S/$(dirname "$p")" && cp -p "$src" "$S/$p"
done < manifest.txt
[ "$missing" = 0 ] || { echo "[orcad] $missing 个文件在安装包里找不到，中止"; exit 1; }
(cd "$S" && sha256sum -c --quiet "$W/manifest.sha256") || { echo "[orcad] 校验失败，中止"; exit 1; }

mkdir -p "$D" && cp -a "$S/." "$D/" && touch "$D/.install-complete" && rm -rf "$D/.install-lock"
echo "[orcad] 完成：$(wc -l < manifest.txt) 个文件已安装到 $D"
