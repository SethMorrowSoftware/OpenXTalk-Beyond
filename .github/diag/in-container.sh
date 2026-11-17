#!/bin/bash
# Diagnostic: inside an Ubuntu container (the repository at /w, the package
# at /oxt, logs at /logs, core files at /cores): installs what the package
# needs and runs the browser check under Xvfb, in a Weston session and in a
# Mutter session.
export DEBIAN_FRONTEND=noninteractive
. /etc/os-release; echo "Container: $PRETTY_NAME"
apt-get -o Acquire::Retries=3 update -q > /dev/null
want=(python3 xz-utils xvfb xauth x11-utils weston xwayland mutter dbus dbus-x11 gdb)
while read -r soname use deb rpm rest; do
  case $soname in ''|'#'*) continue ;; esac
  if apt-cache show --no-all-versions "${deb}t64" > /dev/null 2>&1; then deb="${deb}t64"; fi
  case " ${want[*]} " in *" $deb "*) ;; *) want+=("$deb") ;; esac
done < /w/Installer/linux/libraries.txt
have=()
for p in "${want[@]}"; do
  if apt-cache show --no-all-versions "$p" > /dev/null 2>&1; then have+=("$p"); else echo "NOT IN THIS UBUNTU: $p"; fi
done
echo "Installing: ${have[*]}"
apt-get -o Acquire::Retries=3 install -y -q --no-install-recommends "${have[@]}" > /tmp/apt.log 2>&1 || { echo "apt-get install failed"; tail -20 /tmp/apt.log; }
ldd --version | sed -n 1p; weston --version 2>&1 | head -1; mutter --version 2>&1 | head -1
dpkg -l | grep -E "libgtk2|libgtk-3|mesa|libwayland-client" | awk '{print $2, $3}' | head -12

echo "===== c1: Xvfb"
Xvfb :77 -screen 0 1280x1024x24 > /dev/null 2>&1 & xvfb=$!
sleep 2
env -u WAYLAND_DISPLAY -u XDG_SESSION_TYPE DISPLAY=:77 bash /w/.github/diag/check-in-session.sh c1-xvfb /oxt /logs /cores
kill $xvfb

echo "===== c2: a Weston session"
env -u DISPLAY -u WAYLAND_DISPLAY bash /w/.github/diag/check-in-session.sh c2-weston /oxt /logs /cores --session wayland

echo "===== c3: a Mutter session"
env -u DISPLAY -u WAYLAND_DISPLAY dbus-run-session -- bash /w/.github/diag/mutter-session.sh \
  bash /w/.github/diag/check-in-session.sh c3-mutter /oxt /logs /cores
echo "===== container done"
