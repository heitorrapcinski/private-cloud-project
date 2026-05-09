#!/bin/bash
# Swift Ring Builder Script
# Run from a controller node after Swift nodes are provisioned

set -euo pipefail

PART_POWER=14
REPLICAS=3
MIN_PART_HOURS=1
RING_DIR="/etc/swift"

cd "${RING_DIR}"

echo "=== Creating Swift Rings ==="

# Create builders
for ring in account container object; do
  swift-ring-builder ${ring}.builder create ${PART_POWER} ${REPLICAS} ${MIN_PART_HOURS}
done

echo "=== Adding AZ1 devices (Zone 1) ==="
for i in $(seq 1 6); do
  IP="10.0.20.$((100+i))"
  for disk in b c d e f g h i j k l m; do
    swift-ring-builder account.builder add --region 1 --zone 1 --ip ${IP} --port 6202 --device sd${disk} --weight 100
    swift-ring-builder container.builder add --region 1 --zone 1 --ip ${IP} --port 6201 --device sd${disk} --weight 100
    swift-ring-builder object.builder add --region 1 --zone 1 --ip ${IP} --port 6200 --device sd${disk} --weight 100
  done
done

echo "=== Adding AZ2 devices (Zone 2) ==="
for i in $(seq 1 6); do
  IP="10.0.21.$((100+i))"
  for disk in b c d e f g h i j k l m; do
    swift-ring-builder account.builder add --region 1 --zone 2 --ip ${IP} --port 6202 --device sd${disk} --weight 100
    swift-ring-builder container.builder add --region 1 --zone 2 --ip ${IP} --port 6201 --device sd${disk} --weight 100
    swift-ring-builder object.builder add --region 1 --zone 2 --ip ${IP} --port 6200 --device sd${disk} --weight 100
  done
done

echo "=== Adding AZ3 devices (Zone 3) ==="
for i in $(seq 1 6); do
  IP="10.0.22.$((100+i))"
  for disk in b c d e f g h i j k l m; do
    swift-ring-builder account.builder add --region 1 --zone 3 --ip ${IP} --port 6202 --device sd${disk} --weight 100
    swift-ring-builder container.builder add --region 1 --zone 3 --ip ${IP} --port 6201 --device sd${disk} --weight 100
    swift-ring-builder object.builder add --region 1 --zone 3 --ip ${IP} --port 6200 --device sd${disk} --weight 100
  done
done

echo "=== Rebalancing Rings ==="
swift-ring-builder account.builder rebalance
swift-ring-builder container.builder rebalance
swift-ring-builder object.builder rebalance

echo "=== Ring Statistics ==="
swift-ring-builder account.builder
swift-ring-builder container.builder
swift-ring-builder object.builder

echo "=== Done. Distribute .ring.gz files to all Swift nodes ==="
