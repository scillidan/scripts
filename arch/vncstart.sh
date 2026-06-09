#!/bin/bash

vncserver -kill :1 >/dev/null 2>&1
rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1
vncserver :1