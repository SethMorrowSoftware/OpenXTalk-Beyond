#!/bin/bash
# Diagnostic: starts a headless Mutter (GNOME's compositor) as a Wayland
# session with Xwayland and runs "$@" in it. Run under dbus-run-session.
export XDG_RUNTIME_DIR=$(mktemp -d /tmp/oxt-mutter-XXXXXX)
chmod 700 "$XDG_RUNTIME_DIR"
before=$(ls /tmp/.X11-unix 2>/dev/null | tr '\n' ' ')
env -u DISPLAY -u WAYLAND_DISPLAY mutter --headless --wayland --wayland-display wayland-oxt-mutter \
  --virtual-monitor 1280x1024 > "$XDG_RUNTIME_DIR/mutter.log" 2>&1 &
mutter=$!
display=
for i in $(seq 1 100); do
  for s in $(ls /tmp/.X11-unix 2>/dev/null); do
    case " $before " in *" $s "*) ;; *) display=":${s#X}" ;; esac
  done
  [ -n "$display" ] && [ -e "$XDG_RUNTIME_DIR/wayland-oxt-mutter" ] && break
  kill -0 "$mutter" 2>/dev/null || break
  sleep 0.2
done
mutter --version
echo "Mutter: pid $mutter, Wayland socket $(ls "$XDG_RUNTIME_DIR" | tr '\n' ' '), X sockets before: $before, now: $(ls /tmp/.X11-unix | tr '\n' ' '), display: $display"
if [ -z "$display" ]; then
  echo "RESULT mutter: no session"; tail -20 "$XDG_RUNTIME_DIR/mutter.log" | cut -c1-200
  kill "$mutter" 2>/dev/null; exit 0
fi
# Mutter's Xwayland takes clients only with its own authority file, which a
# GNOME session hands to its programs in XAUTHORITY
auth=$(ls -a "$XDG_RUNTIME_DIR" | grep '^\.mutter-Xwaylandauth' | head -1)
if [ -n "$auth" ]; then export XAUTHORITY="$XDG_RUNTIME_DIR/$auth"; fi
export DISPLAY=$display WAYLAND_DISPLAY=wayland-oxt-mutter XDG_SESSION_TYPE=${OXT_SESSION_TYPE:-wayland}
echo "XAUTHORITY=${XAUTHORITY-} XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
timeout 30 xwininfo -root > /dev/null 2>&1; echo "Mutter's X server answers xwininfo: exit status $?"
"$@"
echo "Mutter's log, last lines:"; grep -v "Could not resolve keysym\|^> \|^Errors from xkbcomp" "$XDG_RUNTIME_DIR/mutter.log" | tail -25 | cut -c1-220
kill "$mutter" 2>/dev/null; wait "$mutter" 2>/dev/null
exit 0
