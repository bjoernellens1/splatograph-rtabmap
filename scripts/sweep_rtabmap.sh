#!/usr/bin/env bash
# RTAB-Map odometry stabilization sweep on a bag, tabulating the objective tuple
# (ATE-vs-O3D, coverage %, track-loss gaps). Coverage/continuity first, ATE second.
#
# RTAB-Map odometry per-frame ~50ms (keeps up at 15fps), so instability is
# genuine registration failure + motion-model over-extrapolation, not drops.
# Axes: Odom/Strategy (1=Frame-to-Frame is usually more robust handheld than
# 0=Frame-to-Map), Vis/MaxFeatures, Vis/MinInliers, Odom/ResetCountdown.
#
# Usage: sweep_rtabmap.sh BAG OUTDIR [DURATION_S] [RATE]
set -eo pipefail
BAG="$1"; OUTDIR="$2"; DUR="${3:-60}"; RATE="${4:-0.5}"
mkdir -p "$OUTDIR"

# label : ODOM_ARGS
declare -a GRID=(
  "baseline|"
  "f2f|--Odom/Strategy 1"
  "f2f_feat2k|--Odom/Strategy 1 --Vis/MaxFeatures 2000"
  "f2f_inl12|--Odom/Strategy 1 --Vis/MinInliers 12"
  "f2f_feat2k_inl12_reset|--Odom/Strategy 1 --Vis/MaxFeatures 2000 --Vis/MinInliers 12 --Odom/ResetCountdown 1"
  "f2m_feat2k|--Odom/Strategy 0 --Vis/MaxFeatures 2000"
)

for spec in "${GRID[@]}"; do
  LBL="${spec%%|*}"; ARGS="${spec#*|}"
  echo "=== $LBL : [$ARGS] ==="
  ODOM_ARGS="$ARGS" bash /scripts/run_rtabmap.sh "$BAG" "$OUTDIR" "$LBL" "$RATE" "$DUR" || echo "[sweep] FAILED $LBL"
done

echo "=== RTABMAP SWEEP SUMMARY (${BAG##*/}) ==="
python3 - "$OUTDIR" <<'PY'
import json, glob, os, sys
rows=[]
for f in sorted(glob.glob(os.path.join(sys.argv[1], "*.eval.json"))):
    d=json.load(open(f))
    rows.append((d["label"], d.get("ate_rmse_vs_o3d"), d.get("coverage",0), d.get("track_loss_gaps",0), d.get("n_est",0)))
rows.sort(key=lambda r:(-(r[2] or 0), r[1] if r[1] is not None else 9e9))
print(f"{'config':<26} {'ATE(mm)':>8} {'cov%':>6} {'losses':>7} {'n_est':>6}")
for lbl,ate,cov,los,n in rows:
    am=f"{ate*1000:.0f}" if ate is not None else "n/a"
    print(f"{lbl:<26} {am:>8} {(cov or 0)*100:>5.1f} {los:>7} {n:>6}")
PY
