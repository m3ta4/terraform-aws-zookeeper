#!/bin/bash
set -e

# Configure Zookeeper
cat << EOF > /usr/local/zookeeper/conf/zoo.cfg
tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
EOF

# Start Zookeeper
/usr/local/zookeeper/bin/zkServer.sh start

