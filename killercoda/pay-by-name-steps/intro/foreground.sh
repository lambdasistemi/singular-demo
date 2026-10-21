echo "Downloading and checking the demo kit, and installing tmux and node..."
while [ ! -f /tmp/finished ]; do sleep 1; done
bash /root/play/windows.sh /root/singular-demo-run
echo "Ready."
