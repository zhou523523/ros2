#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"
#include <chrono> // 用于时间库

// 1. 定义一个类，继承自 rclcpp::Node
class MyPublisher : public rclcpp::Node
{
public:
    // 2. 构造函数
    MyPublisher() : Node("publisher_node_class")
    {
        // 创建发布者
        publisher_ = this->create_publisher<std_msgs::msg::String>("/my_topic", 10);

        // 创建一个定时器（替代之前的 while 循环），每隔 1000ms (1秒) 执行一次 timer_callback
        timer_ = this->create_wall_timer(
            std::chrono::milliseconds(1000),
            std::bind(&MyPublisher::timer_callback, this)
        );

        RCLCPP_INFO(this->get_logger(), "类封装的发布者已启动！");
    }

private:
    // 3. 定时器回调函数：每次触发时，执行发布逻辑
    void timer_callback()
    {
        auto message = std_msgs::msg::String();
        message.data = "Hello World (from class)!";

        // 发布消息
        publisher_->publish(message);
    }

    // 成员变量
    rclcpp::Publisher<std_msgs::msg::String>::SharedPtr publisher_;
    rclcpp::TimerBase::SharedPtr timer_;
};

// 4. main 函数变得极其干净
int main(int argc, char * argv[])
{
    rclcpp::init(argc, argv);

    // 实例化我们的类
    auto node = std::make_shared<MyPublisher>();

    // 交给 spin 去维持生命，等待定时器触发
    rclcpp::spin(node);

    rclcpp::shutdown();
    return 0;
}