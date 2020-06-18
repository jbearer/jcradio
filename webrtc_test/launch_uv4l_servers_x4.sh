#!/bin/bash

/usr/bin/uv4l -f -k --sched-fifo --mem-lock --config-file=/etc/uv4l/uv4l-jcradio.conf --driver raspidisp --driver-config-file=/etc/uv4l/uv4l-jcradio.conf --server-option=--editable-config-file=/etc/uv4l/uv4l-jcradio.conf --server-option=--port=3011 --server-option=--www-port=3001 --server-option=--webrtc-recdevice-index=14 &
sleep 1
/usr/bin/uv4l -f -k --sched-fifo --mem-lock --config-file=/etc/uv4l/uv4l-jcradio.conf --driver raspidisp --driver-config-file=/etc/uv4l/uv4l-jcradio.conf --server-option=--editable-config-file=/etc/uv4l/uv4l-jcradio.conf --server-option=--port=3022 --server-option=--www-port=3002 --server-option=--webrtc-recdevice-index=29 &
sleep 1
/usr/bin/uv4l -f -k --sched-fifo --mem-lock --config-file=/etc/uv4l/uv4l-jcradio.conf --driver raspidisp --driver-config-file=/etc/uv4l/uv4l-jcradio.conf --server-option=--editable-config-file=/etc/uv4l/uv4l-jcradio.conf --server-option=--port=3033 --server-option=--www-port=3003 --server-option=--webrtc-recdevice-index=44 &
sleep 1
/usr/bin/uv4l -f -k --sched-fifo --mem-lock --config-file=/etc/uv4l/uv4l-jcradio.conf --driver raspidisp --driver-config-file=/etc/uv4l/uv4l-jcradio.conf --server-option=--editable-config-file=/etc/uv4l/uv4l-jcradio.conf --server-option=--port=3044 --server-option=--www-port=3004 --server-option=--webrtc-recdevice-index=59 &
