#!/bin/bash

# unset GNOME Shell app switching
gsettings set org.gnome.desktop.wm.keybindings switch-applications '[]'
gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward '[]'
# change GNOME Shell window switching to alt+tab
gsettings set org.gnome.desktop.wm.keybindings switch-windows '["<Alt>Tab"]'
# change GNOME Shell window switching to alt+shift+tab
gsettings set org.gnome.desktop.wm.keybindings switch-windows-backward '["<Alt><Shift>Tab"]'
# enable GNOME Fractional Scaling
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
