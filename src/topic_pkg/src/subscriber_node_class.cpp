#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"

class MySubscriber : public rclcpp::Node
{
public:
    MySubscriber() : Node("subscriber_node_class")
    {
        subscription_ = this->create_subscription<std_msgs::msg::String>(
            "/my_topic", 10, std::bind(&MySubscriber::callback, this, std::placeholders::_1));

        RCLCPP_INFO(this->get_logger(), "类封装的订阅者已启动！");
    }

private:
    void callback(const std_msgs::msg::String::SharedPtr msg)
    {
        RCLCPP_INFO(this->get_logger(), "Receive: '%s'", msg->data.c_str());
    }
    rclcpp::Subscription<std_msgs::msg::String>::SharedPtr subscription_;
};

int main(int argc, char * argv[])
{
    rclcpp::init(argc, argv);
    auto node = std::make_shared<MySubscriber>();
    rclcpp::spin(node);
    rclcpp::shutdown();
    return 0;
}