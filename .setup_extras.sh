#!/bin/bash
# 容器内一次性环境增强：换国内源(USTC) + 补齐教学/开发用的包
set -e

echo "=== 1/4 切换 apt 源 ==="
sed -i 's|https://mirrors.tuna.tsinghua.edu.cn/ubuntu/|https://mirrors.ustc.edu.cn/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources
sed -i 's|https://mirrors.tuna.tsinghua.edu.cn/ros2|https://mirrors.ustc.edu.cn/ros2|g' /etc/apt/sources.list.d/ros2.sources
grep -h "URIs" /etc/apt/sources.list.d/*.sources | grep -v '^##'

echo "=== 2/4 更新索引 ==="
apt-get update -qq

echo "=== 3/4 安装教学与开发包 ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  ros-jazzy-demo-nodes-cpp \
  ros-jazzy-demo-nodes-py \
  ros-jazzy-turtlesim \
  ros-jazzy-rqt \
  ros-jazzy-tf2-tools \
  ros-dev-tools \
  python3-pip \
  git vim curl less nano

echo "=== 4/4 清理 ==="
apt-get clean
rm -rf /var/lib/apt/lists/*
echo "OK 环境增强完成"
