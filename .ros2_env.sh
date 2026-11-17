# 容器内终端启动时自动执行（由 ros2.sh 的 --rcfile 指定）
# 目标：无论容器/挂载处于什么状态，都保证 ros2 命令可用

# 1) 加载 ROS 2 底层环境
if [ -f /opt/ros/jazzy/setup.bash ]; then
  source /opt/ros/jazzy/setup.bash
else
  echo "✗ 找不到 /opt/ros/jazzy/setup.bash，镜像可能有问题" >&2
fi

# 2) 加载你的工作区（编译过才有）
if [ -f /root/ros2_ws/install/setup.bash ]; then
  source /root/ros2_ws/install/setup.bash 2>/dev/null || true
fi

# 3) 兜底：万一 setup.bash 没把 bin 目录塞进 PATH，这里强制补上
case ":$PATH:" in
  *":/opt/ros/jazzy/bin:"*) ;;
  *) export PATH="/opt/ros/jazzy/bin:$PATH" ;;
esac

# 4) 让 ROS 2 走本机回环，多个终端之间立刻能发现对方
export ROS_DOMAIN_ID=42
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

# 5) 图形界面显示到虚拟桌面（turtlesim / rqt / rviz 都能开窗）
#    前提：Xvnc :1 在跑，'~/ros2_ws/turtle.sh' 会把它拉起来
if [ -S /tmp/.X11-unix/X1 ]; then
  export DISPLAY=:1
fi

# 5) 自检：真的能用才放行，不能用就直说
if ! command -v ros2 >/dev/null 2>&1; then
  echo "✗ ros2 未能加载。可能容器是旧的，请退出后在 Mac 终端执行："
  echo "  docker rm -f ros2_jazzy && ~/ros2_ws/ros2.sh"
fi

cd /root/ros2_ws 2>/dev/null || true

PS1='\[\e[36m\][ROS2 jazzy]\[\e[0m\] \w $ '
