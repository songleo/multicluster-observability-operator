#!/usr/bin/env bash

# Copyright (c) 2021 Red Hat, Inc.
# Copyright Contributors to the Open Cluster Management project

set -euxo pipefail

KEY="$SHARED_DIR/private.pem"
chmod 400 "$KEY"

IP="$(cat "$SHARED_DIR/public_ip")"
HOST="ec2-user@$IP"
OPT=(-q -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -i "$KEY")

ssh "${OPT[@]}" "$HOST" sudo yum install gcc git -y
scp "${OPT[@]}" -r ../multicluster-observability-operator "$HOST:/tmp/multicluster-observability-operator"
ssh "${OPT[@]}" "$HOST" "cd /tmp/multicluster-observability-operator/tests/run-in-kind && ./run-e2e-in-kind.sh" > >(tee "$ARTIFACT_DIR/run-e2e-in-kind.log") 2>&1
sleep 10000
