#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"

// 这里定义了一个全局变量 node，为了方便在回调函数里使用
std::shared_ptr<rclcpp::Node> node;

// 这是一个回调函数，每当收到消息时就会自动执行这里的代码
void Callback(const std_msgs::msg::String::SharedPtr msg)
{
    RCLCPP_INFO(node->get_logger(), "Receive: '%s'", msg->data.c_str());
}

int main(int argc, char * argv[])
{
    rclcpp::init(argc, argv);

    // 创建节点
    node = std::make_shared<rclcpp::Node>("subscriber_node");

    // 创建订阅者，订阅 "/my_topic" 话题，队列长度为 10，绑定回调函数 Callback
    auto subscriber = node->create_subscription<std_msgs::msg::String>("/my_topic", 10, &Callback);

    // 进入自旋，等待接收消息
    rclcpp::spin(node);
    rclcpp::shutdown();
    return 0;
}