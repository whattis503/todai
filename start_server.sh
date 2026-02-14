#!/bin/bash
cd /home/user/flutter_app/build/web
while true; do
    python3 -m http.server 5060 --bind 0.0.0.0
    sleep 2
done
