#!/bin/bash
# 在 ROS 2 环境里执行一条命令，自动判断"我在宿主机还是容器里"
# 用法：~/ros2_ws/ros-cmd.sh "ros2 topic list"
# 宿主机 → docker exec 进容器执行；容器内 → 直接执行

CONTAINER="ros2_jazzy"
WS_CT="/root/ros2_ws"

# ---------- 已经在容器里：直接用 ----------
if [ -x /opt/ros/jazzy/bin/ros2 ]; then
  source /opt/ros/jazzy/setup.bash
  [ -f "$WS_CT/install/setup.bash" ] && source "$WS_CT/install/setup.bash"
  cd "$WS_CT" 2>/dev/null || true
  exec bash -c "$*"
fi

# ---------- 在宿主机：确保容器在跑，再进去执行 ----------
if ! docker info >/dev/null 2>&1; then
  echo "→ 正在启动 Docker ..." >&2
  open -a Docker
  for _ in $(seq 1 40); do
    docker info >/dev/null 2>&1 && break
    sleep 3
  done
  docker info >/dev/null 2>&1 || { echo "✗ Docker 启动失败" >&2; exit 1; }
fi

if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "✗ 容器 $CONTAINER 不存在，请先运行 ~/ros2_ws/ros2.sh 初始化" >&2
  exit 1
fi

docker start "$CONTAINER" >/dev/null 2>&1 || {
  echo "✗ 容器启动失败（可能是端口被占用），请先运行 ~/ros2_ws/ros2.sh" >&2
  exit 1
}

exec docker exec -w "$WS_CT" "$CONTAINER" bash -c "
  source /opt/ros/jazzy/setup.bash
  [ -f $WS_CT/install/setup.bash ] && source $WS_CT/install/setup.bash
  export ROS_DOMAIN_ID=42
  export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
  $*
"
