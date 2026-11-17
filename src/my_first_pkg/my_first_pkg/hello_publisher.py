import rclpy
from rclpy.node import Node
from std_msgs.msg import String


class HelloPublisher(Node):
    def __init__(self):
        super().__init__('hello_publisher')
        self.publisher_ = self.create_publisher(String, 'hello_topic', 10)
        self.count = 0
        self.timer = self.create_timer(1.0, self.tick)
        self.get_logger().info('hello_publisher 已启动，每秒发布一条消息')

    def tick(self):
        msg = String()
        msg.data = f'你好，ROS 2！这是第 {self.count} 条消息'
        self.publisher_.publish(msg)
        self.get_logger().info(f'发布: {msg.data}')
        self.count += 1


def main(args=None):
    rclpy.init(args=args)
    node = HelloPublisher()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
