#!/bin/bash
# 빠른 샘플 캡처: 고도를 한 번만 띄워 주요 화면 9장을 찍는다. 사용: tools/samples.sh OUT_DIR [WxH]
OUT=${1:-/tmp/samples}; RES=${2:-2340x1080}; W=${RES%x*}; H=${RES#*x}
cd "$(dirname "$0")/../godot"
GD=${GODOT:-/tmp/claude-0/godot/Godot_v4.5.1-stable_linux.x86_64}
rm -rf "$OUT"; mkdir -p "$OUT"
timeout 170 xvfb-run -a -s "-screen 0 $((W+64))x$((H+64))x24" $GD --rendering-driver opengl3 --path . --resolution $RES -- --samples=$OUT --seed=7 2>&1 | grep -E "SCRIPT ERROR|Parse Error" -A3
ls $OUT
