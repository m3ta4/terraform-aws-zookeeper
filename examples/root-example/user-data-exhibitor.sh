#!/bin/bash
set -e

# Update the Exhibitor Systemd Unit
cat << EOF > /etc/systemd/system/exhibitor.service
# exhibitor service for systemd (CentOS 7.0+)
[Unit]
Description=Exhibitor Zookeeper Supervisor
After=network.target

[Service]
ExecStart=/usr/bin/java -jar /opt/exhibitor/exhibitor-1.6.0.jar -c s3 --s3config "${bucket}":"${key}"
LimitNOFILE=8192
MountFlags=private
RestartSec=5s
Restart=on-failure
SyslogIdentifier=exhibitor
Type=simple

[Install]
WantedBy=multi-user.target
EOF

chmod 664 /etc/systemd/system/exhibitor.service

systemctl start exhibitor.service
