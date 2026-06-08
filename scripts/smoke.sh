#!/usr/bin/env bash
set -eo pipefail
source /opt/ros/${ROS_DISTRO:-jazzy}/setup.bash
ros2 pkg prefix rtabmap_slam >/dev/null
ros2 pkg prefix rtabmap_odom >/dev/null
ros2 pkg prefix rtabmap_launch >/dev/null
command -v slam-launch >/dev/null
