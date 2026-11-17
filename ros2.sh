#!/bin/bash
# 启动 turtlesim 的图形窗口（虚拟 X 桌面 + TigerVNC，macOS 屏幕共享可直接连）
# 用法：~/ros2_ws/turtle.sh
set -u

if [ -f /.dockerenv ] || [ -d /run/.containerenv ]; then
  cat >&2 <<'EOF'
✗ 这个脚本要在 Mac 的「终端」里运行，不能在容器里运行。

  它需要用 docker 命令操作容器、用 open 命令打开查看器，容器里两样都没有。
  请新开一个 Mac「终端」窗口再执行：~/ros2_ws/turtle.sh
EOF
  exit 1
fi

CONTAINER="ros2_jazzy"
PORT_FILE="$HOME/ros2_ws/.vnc_port"
VNC_MAC_PASS="turtle"

die() { echo "✗ $*" >&2; exit 1; }

docker inspect "$CONTAINER" >/dev/null 2>&1 || die "容器不存在，请先运行 ~/ros2_ws/ros2.sh"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  docker start "$CONTAINER" >/dev/null 2>&1 || die "容器启动失败，请运行 ~/ros2_ws/ros2.sh"
  sleep 2
fi

# 宿主端口
PORT=$(tr -d '[:space:]' < "$PORT_FILE" 2>/dev/null)
[ -z "${PORT:-}" ] && PORT=$(docker port "$CONTAINER" 5900 2>/dev/null | head -1 | sed 's/.*://')
[ -z "${PORT:-}" ] && PORT=59123

# 1) 虚拟 X 桌面（:1，RFB 5900，密码认证）
if ! docker exec "$CONTAINER" pgrep -x Xvnc >/dev/null 2>&1; then
  echo "→ 启动虚拟桌面 Xvnc :1 ..."
  docker exec -d "$CONTAINER" bash -c \
    'nohup Xvnc :1 -geometry 900x760 -depth 24 -rfbport 5900 -SecurityTypes VncAuth -rfbauth /root/.vnc/passwd -AlwaysShared -desktop ROS2 > /tmp/xvnc.log 2>&1 &'
  for _ in $(seq 1 20); do
    sleep 0.5
    docker exec "$CONTAINER" bash -c 'DISPLAY=:1 xdpyinfo >/dev/null 2>&1' && break
  done
fi

# 2) 窗口管理器（让窗口有标题栏、可拖动）
if ! docker exec "$CONTAINER" pgrep -x openbox >/dev/null 2>&1; then
  docker exec -d "$CONTAINER" bash -c 'DISPLAY=:1 nohup openbox > /tmp/openbox.log 2>&1 &'
  sleep 1
fi

# 3) turtlesim
if docker exec "$CONTAINER" pgrep -x turtlesim_node >/dev/null 2>&1; then
  echo "→ 小海龟已在运行"
else
  echo "→ 启动 turtlesim ..."
  docker exec -d "$CONTAINER" bash -c \
    'source /opt/ros/jazzy/setup.bash; export DISPLAY=:1; exec ros2 run turtlesim turtlesim_node > /tmp/turtle.log 2>&1'
  for _ in $(seq 1 20); do
    sleep 0.5
    docker exec "$CONTAINER" pgrep -x turtlesim_node >/dev/null 2>&1 && break
  done
fi

docker exec "$CONTAINER" pgrep -x turtlesim_node >/dev/null 2>&1 \
  || die "turtlesim 启动失败，查看日志：docker exec $CONTAINER cat /tmp/turtle.log"

# 4) 打开窗口
for _ in $(seq 1 20); do
  nc -z 127.0.0.1 "$PORT" >/dev/null 2>&1 && break
  sleep 0.5
done
echo "→ 打开窗口 vnc://127.0.0.1:$PORT"
open "vnc://127.0.0.1:$PORT"

cat <<EOF

────────────────────────────────────────
  VNC 密码：$VNC_MAC_PASS
  （首次输入后可勾选「记住密码」）
────────────────────────────────────────

驱动海龟：另开一个终端

  ~/ros2_ws/ros2.sh
  ros2 run turtlesim turtle_teleop_key

方向键按在那个终端里，窗口中的海龟就会动。
EOF
