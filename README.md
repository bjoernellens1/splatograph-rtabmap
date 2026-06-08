# Splatograph RTAB-Map ROS2 Jazzy Container

CPU/AMD-compatible ROS2 Jazzy RTAB-Map image for feeding live SLAM poses into Splatograph.

## Image

```bash
docker pull ghcr.io/bjoernellens1/splatograph-rtabmap:jazzy
```

## Run

```bash
docker compose up slam
```

For bag replay from `./bags`:

```bash
BAG_PATH=/bags/input docker compose --profile bag up bag slam
```

For Splatograph integration:

```bash
docker compose -f compose.splatograph.yml up
```

## ROS Contract

Default input/output topics are documented in `config/default.yaml`. Provider output is normalized for Splatograph around `/slam/pose`, `/slam/odom`, `/slam/path`, and `/tf` where the upstream method publishes those streams.

## Upstream

- Upstream: https://github.com/introlab/rtabmap_ros
- Pinned reference for initial implementation: `ros2@aec4f91f6150e82572bae1a5378fd9e5be924ca0`
- ROS distro: Jazzy
- Platform: `linux/amd64`
- Runtime policy: CPU/AMD-compatible, no NVIDIA runtime dependency

## Smoke Test

```bash
docker build -t ghcr.io/bjoernellens1/splatograph-rtabmap:jazzy .
docker run --rm ghcr.io/bjoernellens1/splatograph-rtabmap:jazzy splatograph-smoke
docker compose config
```
