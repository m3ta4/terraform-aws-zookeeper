#!/bin/bash
set -e

# Create Exhibitor Properties
mkdir -p /etc/exhibitor
cat << EOF > /etc/exhibitor/exhibitor.properties
zookeeper-install-directory=/usr/local/zookeeper
zookeeper-data-directory=/var/lib/zookeeper
auto-manage-instances=1
auto-manage-instances-apply-all-at-once=0
zoo-cfg-extra=syncLimit\=2&tickTime\=2000&initLimit\=5&autopurge.snapRetainCount\=3&autopurge.purgeInterval\=1
EOF

# Update the Exhibitor Systemd Unit
cat << EOF > /etc/systemd/system/exhibitor.service
# exhibitor service for systemd (CentOS 7.0+)
[Unit]
Description=Exhibitor Zookeeper Supervisor
After=network.target

[Service]
ExecStart=/usr/bin/java -jar /opt/exhibitor/exhibitor-1.6.0.jar -c s3 --s3config ${bucket}:${key} --defaultconfig /etc/exhibitor/exhibitor.properties
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

systemctl daemon-reload
systemctl restart exhibitor.service
