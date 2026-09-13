#!/bin/bash
# Certbot deploy hook: restart the JC Radio Rails server so Puma loads the renewed certificate.
# Installed on the Pi as /etc/letsencrypt/renewal-hooks/deploy/jcradio-restart-rails.sh
# (root:root, 0755). Certbot runs every deploy hook as root only after a successful
# renewal, with RENEWED_LINEAGE set to the renewed cert's live directory.
set -u

LOG=/var/log/jcradio-cert-deploy.log

case "${RENEWED_LINEAGE:-}" in
    */jcradio.ddns.net) ;;
    *) exit 0 ;;
esac

{
    echo "$(date -Is) renewed ${RENEWED_DOMAINS:-?}; restarting JC Radio Rails"
    # Login + interactive shell so pi's ~/.bashrc supplies RVM, SPOTIFY_* and jcradio-restart.
    /sbin/runuser -l pi -c 'bash -ic jcradio-restart' </dev/null 2>&1
    echo "$(date -Is) jcradio-restart exit $?"
} >>"$LOG" 2>&1
