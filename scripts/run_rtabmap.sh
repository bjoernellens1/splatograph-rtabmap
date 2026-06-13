#!/usr/bin/env bash
# Run ONE RTAB-Map RGB-D pass over an Orbbec bag and evaluate the odometry
# trajectory (/slam/odom) against the baked O3D /camera_pose reference.
#
# Inside ghcr.io/bjoernellens1/splatograph-rtabmap:jazzy. Mounts:
#   /scripts      -> this repo's scripts/ (decompress + eval)
#   /splatograph  -> splatograph repo (utils/trajectory_eval.py, PYTHONPATH)
#   <out>         -> writable dir
#
# Usage: run_rtabmap.sh BAG OUTDIR LABEL [RATE] [DURATION_S]
# Env: RTABMAP_ARGS / ODOM_ARGS = RTAB-Map "--Key/Param value ..." for the sweep.
set -eo pipefail
BAG="$1"; OUTDIR="$2"; LABEL="${3:-run}"; RATE="${4:-1.0}"; DURATION="${5:-0}"
PLAY_EXTRA=""; [ "$DURATION" != "0" ] && PLAY_EXTRA="--playback-duration $DURATION"

source /opt/ros/jazzy/setup.bash
export PYTHONPATH="/splatograph:${PYTHONPATH:-}"
POSE_BAG="${OUTDIR}/${LABEL}_poses"; mkdir -p "$OUTDIR"; rm -rf "$POSE_BAG"
now() { date +%s.%N; }
T0=$(now)
echo "[run] LABEL=$LABEL RATE=$RATE DOMAIN=$ROS_DOMAIN_ID RTABMAP_ARGS=${RTABMAP_ARGS:-} ODOM_ARGS=${ODOM_ARGS:-}"

# 1. decompress compressed colour/depth -> raw Image
python3 /scripts/decompress_rgbd_node.py --ros-args -p color_encoding:=bgr8 -p sync:=true \
  > "${OUTDIR}/${LABEL}.decomp.log" 2>&1 &
DPID=$!

# 2. RTAB-Map (rgbd_odometry + rtabmap). camera_info comes straight from the bag.
#    odom_args is only passed when non-empty (ros2 launch rejects an empty value).
ODOM_ARG_KV=()
[ -n "${ODOM_ARGS:-}" ] && ODOM_ARG_KV=(odom_args:="${ODOM_ARGS}")
ros2 launch rtabmap_launch rtabmap.launch.py \
  rtabmap_viz:=false rviz:=false localization:=false \
  use_sim_time:=true \
  approx_sync:=true queue_size:=30 \
  frame_id:=camera_color_optical_frame \
  rgb_topic:=/camera/color/image_raw \
  depth_topic:=/camera/depth/image_raw \
  camera_info_topic:=/camera/color/camera_info \
  odom_topic:=/slam/odom \
  rtabmap_args:="--delete_db_on_start ${RTABMAP_ARGS:-}" \
  "${ODOM_ARG_KV[@]}" \
  > "${OUTDIR}/${LABEL}.slam.log" 2>&1 &
SPID=$!
SLOG="${OUTDIR}/${LABEL}.slam.log"
for i in $(seq 1 120); do
  grep -qiE "odometry: |subscribed to|rgbd_odometry.*ready" "$SLOG" 2>/dev/null && break
  sleep 0.25
done
sleep 3
T_ready=$(now)

# 3. record estimate + reference
ros2 bag record -s mcap -o "$POSE_BAG" /slam/odom /camera_pose > "${OUTDIR}/${LABEL}.rec.log" 2>&1 &
RPID=$!
sleep 2

# 4. play (blocks until end)
T_play0=$(now)
ros2 bag play "$BAG" -r "$RATE" --clock $PLAY_EXTRA > "${OUTDIR}/${LABEL}.play.log" 2>&1
T_play1=$(now)
sleep 4

# 5. shutdown
kill -INT "$RPID" 2>/dev/null || true; sleep 3
kill -INT "$SPID" "$DPID" 2>/dev/null || true
pkill -INT -f rgbd_odometry 2>/dev/null || true; pkill -INT -f "rtabmap" 2>/dev/null || true; sleep 2
kill "$RPID" "$SPID" "$DPID" 2>/dev/null || true
pkill -f rgbd_odometry 2>/dev/null || true; pkill -f rtabmap 2>/dev/null || true
wait 2>/dev/null || true

# 6. evaluate (Odometry estimate vs PoseStamped reference)
python3 /scripts/eval_traj.py "$POSE_BAG" --est /slam/odom --ref /camera_pose \
  --label "$LABEL" --json "${OUTDIR}/${LABEL}.eval.json"

# 7. timing
N_EST=$(grep -aoE '"n_est": [0-9]+' "${OUTDIR}/${LABEL}.eval.json" 2>/dev/null | grep -oE "[0-9]+" | head -1)
awk -v a="$T0" -v b="$T_ready" -v c="$T_play0" -v d="$T_play1" -v n="${N_EST:-0}" -v l="$LABEL" 'BEGIN{
  play=d-c; fps=(play>0&&n>0)?n/play:0;
  printf "[timing] %s init=%.1fs play=%.1fs(%d poses, %.1f/s)\n", l, b-a, play, n, fps }'
DEC=$(grep -aoE "color=[0-9]+ depth=[0-9]+" "${OUTDIR}/${LABEL}.decomp.log" | tail -1)
[ -n "$DEC" ] && echo "[timing] $LABEL decompress: $DEC"
