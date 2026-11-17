"""一条命令启动 turtlesim + 自动绘图节点。

用法:
    ros2 launch my_first_pkg turtle_demo.launch.py                 # 默认画正方形
    ros2 launch my_first_pkg turtle_demo.launch.py shape:=star     # 画五角星
    ros2 launch my_first_pkg turtle_demo.launch.py shape:=spiral
    ros2 launch my_first_pkg turtle_demo.launch.py auto_draw:=false # 只开窗口不画

这个文件替代了原来两步手工操作:
    ros2 run turtlesim turtlesim_node
    ros2 run my_first_pkg turtle_shape square
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, LogInfo, SetEnvironmentVariable, TimerAction
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    shape = LaunchConfiguration('shape')
    auto_draw = LaunchConfiguration('auto_draw')

    return LaunchDescription([
        # ---- 图形显示 ----
        # ROS 装在容器里，图形要画到容器内的虚拟桌面 :1 上，
        # 再由 VNC 送到 macOS 的屏幕共享窗口。
        # 不显式设置的话，从 VS Code 任务或非交互终端启动会报
        # "qt.qpa.xcb: could not connect to display"。
        SetEnvironmentVariable('DISPLAY', ':1'),
        SetEnvironmentVariable('QT_QPA_PLATFORM', 'xcb'),

        # ---- 可调参数 ----
        DeclareLaunchArgument(
            'shape',
            default_value='square',
            choices=['square', 'star', 'circle', 'spiral'],
            description='要画的图形',
        ),
        DeclareLaunchArgument(
            'auto_draw',
            default_value='true',
            description='true=启动就画；false=只开窗口，留给你手动遥控',
        ),

        LogInfo(msg=['[turtle_demo] 启动 turtlesim，待绘制图形: ', shape]),

        # ---- 节点 1：仿真窗口 ----
        Node(
            package='turtlesim',
            executable='turtlesim_node',
            name='turtlesim',
            output='screen',
        ),

        # ---- 节点 2：绘图控制 ----
        # 延后 2 秒启动，等 turtlesim 把 /turtle1/pose 先发出来，
        # 否则绘图节点会因为收不到位姿而超时退出。
        TimerAction(
            period=2.0,
            actions=[
                Node(
                    package='my_first_pkg',
                    executable='turtle_shape',
                    name='turtle_shape',
                    arguments=[shape],
                    output='screen',
                    condition=IfCondition(auto_draw),
                ),
            ],
        ),
    ])
