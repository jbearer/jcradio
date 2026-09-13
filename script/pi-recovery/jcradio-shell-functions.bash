
# Stop the JC Radio Rails server started by jcradio-start (Puma, daemonized).
# Waits for in-flight requests; SSE streams can hold Puma open, so fall back to SIGKILL.
jcradio-stop() {
    local pidfile=/home/pi/jcradio/tmp/pids/server.pid
    local pid i
    if [ ! -f "$pidfile" ]; then
        echo "JC Radio server is not running (no $pidfile)."
        return 0
    fi
    pid=$(cat "$pidfile")
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "Removing stale pid file (pid $pid is not running)."
        rm -f "$pidfile"
        return 0
    fi
    echo "Stopping JC Radio server (pid $pid)..."
    kill -TERM "$pid"
    for i in $(seq 1 15); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
    done
    if kill -0 "$pid" 2>/dev/null; then
        echo "Still running after 15s (open SSE streams?); sending SIGKILL."
        kill -KILL "$pid"
        sleep 1
    fi
    rm -f "$pidfile"
    echo "JC Radio server stopped."
}

jcradio-restart() {
    jcradio-stop && jcradio-start
}

# Spotify player is the jcradio-player systemd unit (private librespot 0.8.0).
jcradio-player-restart() {
    sudo systemctl restart jcradio-player && systemctl status jcradio-player --no-pager -n 5
}
