#!/usr/bin/bash
set -euo pipefail

xbutil reset --force --device 0000:a1:00.1
xbutil reset --force --device 0000:81:00.1
xbutil reset --force --device 0000:01:00.1
