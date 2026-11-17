#!/bin/bash
# 启动 turtlesim 的网页实时画面（不依赖 macOS 屏幕共享）
set -u

WS="$HOME/ros2_ws"
PORT_FILE="$WS/.vnc_port"
LIVE_DIR="/tmp/turtle_live"
WEB_PORT=8765
CONTAINER=ros2_jazzy

mkdir -p "$LIVE_DIR"

# 1) 确保容器在跑
if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "容器未运行，正在启动..."
  docker start "$CONTAINER" >/dev/null 2>&1 || { echo "无法启动容器，请先运行 $WS/ros2.sh"; exit 1; }
  sleep 2
fi

VNC_PORT=$(tr -d '[:space:]' < "$PORT_FILE" 2>/dev/null)
VNC_PORT=${VNC_PORT:-59123}

# 2) 确保 turtlesim 在跑
if ! docker exec "$CONTAINER" bash -c 'pgrep -x turtlesim_node >/dev/null' 2>/dev/null; then
  echo "启动 turtlesim..."
  docker exec -d "$CONTAINER" bash -c \
    'source /opt/ros/jazzy/setup.bash; export QT_QPA_PLATFORM=vnc; export QT_VNC_PORT=5900; exec ros2 run turtlesim turtlesim_node > /tmp/turtle.log 2>&1'
  for i in $(seq 1 15); do
    sleep 1
    docker exec "$CONTAINER" bash -c 'grep -q "QVncServer created" /tmp/turtle.log 2>/dev/null' && break
  done
fi

# 3) 清理旧进程
pkill -f "vnc_live.py --port $VNC_PORT" 2>/dev/null
lsof -nP -iTCP:$WEB_PORT -sTCP:LISTEN -t 2>/dev/null | xargs -r kill 2>/dev/null
sleep 1

# 4) 起抓帧
python3 "$WS/vnc_live.py" --port "$VNC_PORT" --out "$LIVE_DIR" --fps 4 \
  > "$LIVE_DIR/capture.log" 2>&1 &

# 5) 等首帧
for i in $(seq 1 20); do
  [ -f "$LIVE_DIR/turtle.png" ] && break
  sleep 0.5
done

# 6) 起网页服务
cd "$LIVE_DIR" && python3 -m http.server "$WEB_PORT" --bind 127.0.0.1 \
  > "$LIVE_DIR/http.log" 2>&1 &

sleep 1
[ -f "$LIVE_DIR/turtle.png" ] && echo "✔ 画面已就绪" || echo "✗ 未抓到画面，见 $LIVE_DIR/capture.log"
echo "→ http://127.0.0.1:$WEB_PORT/index.html"
