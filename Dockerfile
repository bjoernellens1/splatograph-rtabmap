FROM ros:jazzy-ros-base-noble

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
LABEL org.opencontainers.image.source="https://github.com/bjoernellens1/splatograph-rtabmap"       org.opencontainers.image.description="ROS2 Jazzy RTAB-Map container for Splatograph pose input"       org.opencontainers.image.licenses="Apache-2.0"

ENV ROS_DISTRO=jazzy     DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends       ros-jazzy-rtabmap-ros       ros-jazzy-rosbag2-storage-mcap       ros-jazzy-tf2-ros       ros-jazzy-image-transport       ros-jazzy-cv-bridge     && rm -rf /var/lib/apt/lists/*

COPY scripts/slam-launch /usr/local/bin/slam-launch
COPY scripts/smoke.sh /usr/local/bin/splatograph-smoke
RUN chmod +x /usr/local/bin/slam-launch /usr/local/bin/splatograph-smoke

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["slam-launch"]
