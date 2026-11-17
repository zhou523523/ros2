#!/bin/bash
# ROS 2 Jazzy 启动器（macOS + Docker）
# 用法：~/ros2_ws/ros2.sh            进入 ROS 环境
#       ~/ros2_ws/ros2.sh --recreate 显式重建容器（会换新的容器 ID）
#
# 重要原则：绝不自动删除容器。
# VS Code 的「附加到容器」是按容器 ID 绑定的，一旦重建旧的附加窗口就失效。

# ── 这个脚本只能在 Mac 上跑（它要用 docker 命令去开容器）─────────────
if [ -f /.dockerenv ] || [ -d /run/.containerenv ]; then
  cat >&2 <<'EOF'
✗ 这个脚本要在 Mac 的「终端」里运行，不能在容器里运行。

  你现在这个终端已经进到容器里面了（提示符前有 [ROS2 jazzy]），
  容器里没有 docker 命令，也没有 macOS 的 open 命令。

  想进容器：退出后双击桌面的 ROS2，或执行 ~/ros2_ws/ros2.sh
  想在容器里跑小乌龟：直接 ros2 run turtlesim turtlesim_node
EOF
  exit 1
fi

CONTAINER="ros2_jazzy"
IMAGE="ros:jazzy-full"
WS_HOST="$HOME/ros2_ws"
WS_CT="/root/ros2_ws"

# 固定端口：避开 macOS 自带「屏幕共享」占用的 5900，且只绑本机回环
VNC_PORT=59123
PORT_FILE="$WS_HOST/.vnc_port"

die() {
  echo
  echo "✗ $*" >&2
  echo
  read -r -p "按回车键关闭窗口 ..." _ 2>/dev/null || true
  exit 1
}

create_container() {
  echo "→ 创建容器 $CONTAINER（画布端口 127.0.0.1:$VNC_PORT）..."
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker run -dit \
    --name "$CONTAINER" \
    --hostname ros2 \
    -p "127.0.0.1:$VNC_PORT:5900" \
    -v "$WS_HOST":"$WS_CT" \
    -w "$WS_CT" \
    "$IMAGE" \
    bash >/dev/null || die "容器创建失败，请确认 Docker Desktop 正常运行"
  echo "$VNC_PORT" > "$PORT_FILE"
}

# 0) 显式重建（唯一会删除容器的入口）
if [ "$1" = "--recreate" ]; then
  echo "→ 按你的要求重建容器。重建后 VS Code 里的远程窗口需要重新附加。"
  create_container
  shift
fi

# 1) 确保 Docker 引擎在运行
if ! docker info >/dev/null 2>&1; then
  echo "→ Docker 未运行，正在启动 ..."
  open -a Docker
  for _ in $(seq 1 40); do
    docker info >/dev/null 2>&1 && break
    sleep 3
  done
  docker info >/dev/null 2>&1 || die "Docker 启动失败，请手动打开 Docker Desktop 后再试"
fi

# 2) 容器不存在才创建（存在就绝不动它）
if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  create_container
fi

# 3) 启动容器；失败只报错，不重建
if ! start_msg=$(docker start "$CONTAINER" 2>&1); then
  die "容器启动失败：
$start_msg

数据没丢，都在 ~/ros2_ws。
如果是端口 $VNC_PORT 被占用，先关掉占用它的程序；
确实需要彻底重建，请执行：~/ros2_ws/ros2.sh --recreate"
fi

# 4) 健康检查：只提示，不重建
if ! docker exec "$CONTAINER" test -x /opt/ros/jazzy/bin/ros2 >/dev/null 2>&1; then
  echo "⚠ 容器里找不到 ros2，镜像可能异常。" >&2
  echo "  需要重建请执行：~/ros2_ws/ros2.sh --recreate" >&2
fi

# 5) 记录画布端口，供 turtle.sh 使用
echo "$VNC_PORT" > "$PORT_FILE"

# 6) 进入 shell（自动加载 ROS 环境）
if [ -t 0 ]; then
  exec docker exec -it "$CONTAINER" bash --rcfile "$WS_CT/.ros2_env.sh"
else
  exec docker exec -i "$CONTAINER" bash -c '. "$1"; exec bash --norc' _ "$WS_CT/.ros2_env.sh"
fi
