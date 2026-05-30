if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi

if [ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ] && [ ! -e /run/ai-setup-gui-closed ]; then
  touch /run/ai-setup-gui-closed
  exec xinit /usr/local/bin/ai-setup-session -- /usr/bin/X -nolisten tcp vt1
fi
