#!/bin/bash
# 打开一个已经在 ROS 2 环境里的容器终端（供 VS Code 终端配置调用）
CONTAINER="ros2_jazzy"

if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "容器不存在，请先运行 ~/ros2_ws/ros2.sh 初始化"
  exec bash
fi

if ! docker start "$CONTAINER" >/dev/null 2>&1; then
  echo "容器启动失败，请检查 ~/ros2_ws/ros2.sh"
  exec bash
fi

exec docker exec -it "$CONTAINER" bash --rcfile /root/ros2_ws/.ros2_env.sh
