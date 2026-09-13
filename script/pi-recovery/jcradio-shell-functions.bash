
# Website is the jcradio-web systemd unit (Puma, HTTPS :3000); see jcradio-web.service.
# It autostarts at boot. These replace the old daemonized `rails server -d` function.
jcradio-start() {
    sudo systemctl start jcradio-web && systemctl status jcradio-web --no-pager -n 5
}

jcradio-stop() {
    sudo systemctl stop jcradio-web && echo "JC Radio website stopped."
}

jcradio-restart() {
    sudo systemctl restart jcradio-web && systemctl status jcradio-web --no-pager -n 5
}

# Spotify player is the jcradio-player systemd unit (private librespot 0.8.0).
jcradio-player-restart() {
    sudo systemctl restart jcradio-player && systemctl status jcradio-player --no-pager -n 5
}

# One-screen health check: website, player, encoder, stream, certificate.
jcradio-status() {
    local playerlog=/home/pi/.local/state/jcradio-player/player.log
    local marker
    echo "== Website (jcradio-web.service, Rails on https://0.0.0.0:3000)"
    if [ "$(systemctl is-active jcradio-web)" = active ]; then
        echo "   active since $(systemctl show jcradio-web -p ExecMainStartTimestamp --value), home page HTTP $(curl -sk -m 5 -o /dev/null -w '%{http_code}' https://127.0.0.1:3000/)"
    else
        echo "   $(systemctl is-active jcradio-web) -> jcradio-start   (journalctl -u jcradio-web -n 30)"
    fi
    echo "== Player (jcradio-player.service, librespot)"
    marker=$(grep -oE 'Authenticated as|Authentication failed|Connection to server closed|ERROR' "$playerlog" 2>/dev/null | tail -n 1)
    echo "   $(systemctl is-active jcradio-player) since $(systemctl show jcradio-player -p ExecMainStartTimestamp --value), last log marker: ${marker:-none}"
    echo "== Encoder (DarkIce -> Icecast)"
    if pgrep -x darkice >/dev/null; then
        echo "   darkice running; loopback capture: $(head -1 /proc/asound/Loopback/pcm0c/sub0/status 2>/dev/null)"
    else
        echo "   darkice NOT running (started by /etc/rc.local via /home/pi/darkice.sh)"
    fi
    echo "   playback side: $(head -1 /proc/asound/Loopback/pcm1p/sub0/status 2>/dev/null)  (RUNNING = a track is playing, closed = idle/silence)"
    echo "== Stream (Icecast :8000/rapi.mp3)"
    curl -s -m 5 http://127.0.0.1:8000/status-json.xsl | python3 -B -c '
import sys, json
d = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))["icestats"]
s = d.get("source")
if s is None:
    print("   NO SOURCE connected")
else:
    s = s if isinstance(s, dict) else s[0]
    print("   %s kbps, listeners now %s, peak %s" % (s.get("bitrate"), s.get("listeners"), s.get("listener_peak")))
' 2>/dev/null || echo "   icecast not answering"
    echo "== Certificate"
    echo "   $(echo | openssl s_client -connect 127.0.0.1:3000 -servername jcradio.ddns.net 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null || echo 'not served (website down)')"
}

# Usage: jcradio-logs [rails|web|player|icecast] [lines] [-f]   (web = systemd journal for Puma)
jcradio-logs() {
    local which=rails lines=50 follow="" arg file
    for arg in "$@"; do
        case "$arg" in
            rails|web|player|icecast) which=$arg ;;
            -f) follow=-f ;;
            ''|*[!0-9]*) echo "usage: jcradio-logs [rails|web|player|icecast] [lines] [-f]"; return 2 ;;
            *) lines=$arg ;;
        esac
    done
    if [ "$which" = web ]; then
        journalctl -u jcradio-web -n "$lines" --no-pager $follow
        return
    fi
    case "$which" in
        rails)   file=/home/pi/jcradio/log/development.log ;;
        player)  file=/home/pi/.local/state/jcradio-player/player.log ;;
        icecast) file=/var/log/icecast2/error.log ;;
    esac
    echo "== $file"
    tail -n "$lines" $follow "$file"
}
