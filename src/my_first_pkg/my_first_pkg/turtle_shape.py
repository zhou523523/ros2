"""小海龟自动绘图节点。

用法:
    ros2 run my_first_pkg turtle_shape square     # 画正方形
    ros2 run my_first_pkg turtle_shape circle     # 画圆
    ros2 run my_first_pkg turtle_shape spiral     # 画螺旋
    ros2 run my_first_pkg turtle_shape star       # 画五角星

原理:
    - 订阅 /turtle1/pose 拿到当前位置和朝向
    - 向 /turtle1/cmd_vel 发布线速度/角速度
    - 采用「奔向目标点」的闭环控制: 一边走一边修正朝向,
      所以不会像定时开环那样越画越歪
"""

import math
import sys

import rclpy
from geometry_msgs.msg import Twist
from rclpy.node import Node
from turtlesim.msg import Pose


def normalize(angle: float) -> float:
    """把角度归一化到 [-pi, pi]，处理 0/2pi 处的跳变。"""
    while angle > math.pi:
        angle -= 2.0 * math.pi
    while angle < -math.pi:
        angle += 2.0 * math.pi
    return angle


class TurtleShape(Node):
    def __init__(self):
        super().__init__('turtle_shape')
        self.publisher = self.create_publisher(Twist, '/turtle1/cmd_vel', 10)
        self.create_subscription(Pose, '/turtle1/pose', self.on_pose, 10)
        self.pose = None
        self.tick = 1.0 / 50.0

    def on_pose(self, msg: Pose) -> None:
        self.pose = msg

    # ---------- 基础动作 ----------

    def wait_for_pose(self, timeout: float = 5.0) -> None:
        start = self.get_clock().now()
        while self.pose is None:
            rclpy.spin_once(self, timeout_sec=0.1)
            elapsed = (self.get_clock().now() - start).nanoseconds / 1e9
            if elapsed > timeout:
                raise RuntimeError(
                    '收不到 /turtle1/pose —— 请先启动 turtlesim（~/ros2_ws/turtle.sh）'
                )

    def spin_once(self) -> None:
        self.publisher.publish(Twist())
        rclpy.spin_once(self, timeout_sec=self.tick)

    def go_to(self, target_x: float, target_y: float,
              tolerance: float = 0.04, max_speed: float = 1.6) -> None:
        """闭环奔向一个坐标点: 朝向偏差大就原地转，对准了就加速冲。"""
        for _ in range(3000):  # 安全上限，避免死循环
            dx = target_x - self.pose.x
            dy = target_y - self.pose.y
            distance = math.hypot(dx, dy)
            if distance < tolerance:
                break
            heading_error = normalize(math.atan2(dy, dx) - self.pose.theta)
            twist = Twist()
            # 朝向越正，前进越快；偏太多就几乎不前进，先转方向
            twist.linear.x = min(max_speed, 2.0 * distance) * max(0.0, math.cos(heading_error))
            twist.angular.z = 3.0 * heading_error
            self.publisher.publish(twist)
            rclpy.spin_once(self, timeout_sec=self.tick)
        self.stop()

    def publish_for(self, twist: Twist, seconds: float) -> None:
        steps = max(1, int(seconds / self.tick))
        for _ in range(steps):
            self.publisher.publish(twist)
            rclpy.spin_once(self, timeout_sec=self.tick)

    def stop(self) -> None:
        stop = Twist()
        for _ in range(8):
            self.publisher.publish(stop)
            rclpy.spin_once(self, timeout_sec=0.02)

    # ---------- 图形 ----------

    def draw_square(self, side: float = 2.4) -> None:
        x0, y0 = self.pose.x, self.pose.y
        corners = [(x0 + side, y0), (x0 + side, y0 + side),
                   (x0, y0 + side), (x0, y0)]
        self.get_logger().info(f'画正方形，边长 {side}')
        for i, (cx, cy) in enumerate(corners, 1):
            self.go_to(cx, cy)
            self.get_logger().info(f'  第 {i} 个角到达 ({cx:.2f}, {cy:.2f})')

    def draw_star(self, radius: float = 2.2) -> None:
        """五角星: 每隔 144° 取一个顶点，一笔画出来。"""
        cx, cy = self.pose.x, self.pose.y
        points = []
        for k in range(5):
            angle = math.pi / 2 + k * 4.0 * math.pi / 5.0
            points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
        self.get_logger().info('画五角星')
        for px, py in points:
            self.go_to(px, py)
        self.get_logger().info('  回到起点收笔')
        self.go_to(points[0][0], points[0][1])

    def draw_circle(self, radius: float = 1.6, laps: int = 1) -> None:
        speed = 1.5
        omega = speed / radius
        twist = Twist()
        twist.linear.x = speed
        twist.angular.z = omega
        duration = laps * 2.0 * math.pi / omega
        self.get_logger().info(f'画圆，半径 {radius}，{laps} 圈')
        self.publish_for(twist, duration)

    def draw_spiral(self, laps: int = 3, speed: float = 1.2) -> None:
        self.get_logger().info(f'画螺旋，{laps} 圈')
        omega = 1.8
        total = laps * 2.0 * math.pi / omega
        steps = int(total / self.tick)
        twist = Twist()
        for i in range(steps):
            twist.linear.x = speed * (0.2 + 0.8 * i / steps)
            twist.angular.z = omega
            self.publisher.publish(twist)
            rclpy.spin_once(self, timeout_sec=self.tick)


def main(args=None):
    argv = sys.argv[1:] if args is None else args
    shape = argv[0] if argv else 'square'

    rclpy.init()
    node = TurtleShape()
    try:
        node.wait_for_pose()
        node.get_logger().info(
            f'起点 x={node.pose.x:.2f} y={node.pose.y:.2f} theta={node.pose.theta:.2f}'
        )
        if shape == 'square':
            node.draw_square()
        elif shape == 'star':
            node.draw_star()
        elif shape == 'circle':
            node.draw_circle()
        elif shape == 'spiral':
            node.draw_spiral()
        else:
            node.get_logger().error(f'未知图形 "{shape}"，可选: square / star / circle / spiral')
            return
        node.stop()
        node.get_logger().info(
            f'画完了 ✔ 终点 x={node.pose.x:.2f} y={node.pose.y:.2f}'
        )
    except KeyboardInterrupt:
        node.stop()
    finally:
        node.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()
