#!/bin/bash
if [[ $UID != 0 ]]; then
  echo "Please run this script with sudo."
  exit 1
fi

function displayHelp() {
  echo "Usage:"
  echo "    autoupdate-zoom.sh -h          Display this help message."
  echo "    autoupdate-zoom.sh install     Install autoupdate service."
  echo "    autoupdate-zoom.sh uninstall   Uninstall autoupdate service."
  exit 0
}

# Parse options
while getopts ":h" opt; do
  case ${opt} in
  h)
    displayHelp
    ;;
  \?)
    echo "Invalid Option: -$OPTARG" 1>&2
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

subcommand=$1
case "$subcommand" in
install)
  mkdir /opt/zoom-updater
  if command -v apt-cache &>/dev/null; then
    cat <<'EOF' >/opt/zoom-updater/zoom-update.sh
#!/bin/bash
export LANG=en
ZOOM_VERSION_AVAILABLE=$(curl -s 'https://zoom.us/support/download' --header 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.75 Safari/537.36' | grep "class=\"linux-ver-text\"" | sed -e 's/.*Version \(.*\)<.*/\1/')
echo zoom version available for download: $ZOOM_VERSION_AVAILABLE
ZOOM_VERSION_AVAILABLE_MAJOR=$(echo $ZOOM_VERSION_AVAILABLE | sed -e 's/\([^\.]\+\.[^\.]\+\).*/\1/')
echo "major" zoom version available for download: $ZOOM_VERSION_AVAILABLE_MAJOR
ZOOM_VERSION_AVAILABLE_MINOR=$(echo $ZOOM_VERSION_AVAILABLE | sed -e 's/[^\(]\+(\(.*\)).*/\1/')
echo "minor" zoom version available for download: $ZOOM_VERSION_AVAILABLE_MINOR
ZOOM_VERSION_INSTALLED=$(apt-cache policy zoom | grep "Installed:" | sed -e 's/.*Installed: \(.*\)/\1/')
echo zoom version installed: $ZOOM_VERSION_INSTALLED
if [[ "$ZOOM_VERSION_INSTALLED" != *"$ZOOM_VERSION_AVAILABLE_MINOR"* ]] || [[ "$ZOOM_VERSION_INSTALLED" != *"$ZOOM_VERSION_AVAILABLE_MAJOR"* ]]; then
   echo downloading new version...
   wget --quiet https://zoom.us/client/latest/zoom_amd64.deb -P /tmp
   export DEBIAN_FRONTEND=noninteractive
   apt-get install -y /tmp/zoom_amd64.deb
   rm /tmp/zoom_amd64.deb
else
   echo already at latest version
fi
EOF
  fi
  if command -v dnf &>/dev/null; then
    cat <<'EOF' >/opt/zoom-updater/zoom-update.sh
#!/bin/bash
export LANG=en_US
ZOOM_VERSION_AVAILABLE=$(curl -s 'https://zoom.us/support/download' --header 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.75 Safari/537.36' | grep "class=\"linux-ver-text\"" | sed -e 's/.*Version \(.*\)<.*/\1/')
echo zoom version available for download: $ZOOM_VERSION_AVAILABLE
ZOOM_VERSION_AVAILABLE_MAJOR=$(echo $ZOOM_VERSION_AVAILABLE | sed -e 's/\([^\.]\+\.[^\.]\+\).*/\1/')
echo "major" zoom version available for download: $ZOOM_VERSION_AVAILABLE_MAJOR
ZOOM_VERSION_AVAILABLE_MINOR=$(echo $ZOOM_VERSION_AVAILABLE | sed -e 's/[^\(]\+(\(.*\)).*/\1/')
echo "minor" zoom version available for download: $ZOOM_VERSION_AVAILABLE_MINOR
ZOOM_VERSION_INSTALLED=$(dnf list installed zoom.x86_64 | grep "zoom.x86_64" | sed -e 's/.*zoom.x86_64\s*\(.*\)\s.*$/\1/')
echo zoom version installed: $ZOOM_VERSION_INSTALLED
if [[ "$ZOOM_VERSION_INSTALLED" != *"$ZOOM_VERSION_AVAILABLE_MINOR"* ]] || [[ "$ZOOM_VERSION_INSTALLED" != *"$ZOOM_VERSION_AVAILABLE_MAJOR"* ]]; then
   echo downloading new version...
   wget --quiet https://zoom.us/client/latest/zoom_x86_64.rpm -P /tmp
   dnf install -y /tmp/zoom_x86_64.rpm
   rm /tmp/zoom_x86_64.rpm
else
   echo already at latest version
fi
EOF
  fi
  chmod +x /opt/zoom-updater/zoom-update.sh

  cat <<'EOF' >/etc/systemd/system/zoom-update.timer
[Unit]
Description=Update zoom daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

  cat <<'EOF' >/etc/systemd/system/zoom-update.service
[Unit]
Description=zoom update service
After=network.target
After=network-online.target
[Service]
User=root
ExecStart=/opt/zoom-updater/zoom-update.sh

[Install]
WantedBy=multi-user.target
EOF
  systemctl enable --now zoom-update.timer
  # execute zoom update immediately
  systemctl start zoom-update.service
  # output systemd status/logs
  systemctl --no-pager status zoom-update.timer
  systemctl --no-pager status zoom-update.service
  ;;

uninstall)
  systemctl stop zoom-update.timer
  systemctl disable zoom-update.timer
  rm /etc/systemd/system/zoom-update.timer
  rm /etc/systemd/system/zoom-update.service
  rm -r /opt/zoom-updater
  echo "uninstalled zoom auto update service"
  ;;

*)
  # no or unknown subcommand entered
  displayHelp
  ;;
esac
