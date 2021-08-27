#!/usr/bin/env bash

set -euxo pipefail

export IS_KIND_ENV=true

# git clone --depth 1 -b release-2.4 https://github.com/open-cluster-management/multicluster-observability-operator.git
# cd multicluster-observability-operator/tests/run-in-kind


setup_kubectl_command() {
    if ! command -v kubectl >/dev/null 2>&1; then 
        echo "This script will install kubectl (https://kubernetes.io/docs/tasks/tools/install-kubectl/) on your machine"
        if [[ "$(uname)" == "Linux" ]]; then
            curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubectl
        elif [[ "$(uname)" == "Darwin" ]]; then
            curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/darwin/amd64/kubectl
        fi
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
    fi
}

install_jq() {
    if ! command -v jq >/dev/null 2>&1; then 
        if [[ "$(uname)" == "Linux" ]]; then
            curl -o jq -LO https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
        elif [[ "$(uname)" == "Darwin" ]]; then
            curl -o jq -LO https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64
        fi
        chmod +x ./jq
        sudo mv ./jq /usr/local/bin/jq
    fi
}

create_kind_cluster() {
    if ! command -v kind >/dev/null 2>&1; then 
        echo "This script will install kind (https://kind.sigs.k8s.io/) on your machine."
        curl -Lo ./kind-amd64 "https://kind.sigs.k8s.io/dl/v0.10.0/kind-$(uname)-amd64"
        chmod +x ./kind-amd64
        sudo mv ./kind-amd64 /usr/local/bin/kind
    fi
    echo "Delete the KinD cluster if exists"
    kind delete cluster --name $1 || true

    echo "Start KinD cluster with the default cluster name - $1"
    rm -rf $HOME/.kube/kind-config-$1
    kind create cluster --kubeconfig $HOME/.kube/kind-config-$1 --name $1 --config ./kind/kind-$1.config.yaml
    export KUBECONFIG=$HOME/.kube/kind-config-$1
}

deploy_service_ca_operator() {
    kubectl create ns openshift-config-managed
    kubectl apply -f service-ca/00_roles.yaml
    kubectl apply -f service-ca/01_namespace.yaml
    kubectl apply -f service-ca/02_service.yaml
    kubectl apply -f service-ca/03_cm.yaml
    kubectl apply -f service-ca/03_operator.cr.yaml
    kubectl apply -f service-ca/04_sa.yaml
    kubectl apply -f service-ca/05_deploy.yaml
    kubectl apply -f service-ca/07_clusteroperator.yaml
}

deploy_crds() {
    kubectl apply -f req_crds/
}

deploy_templates() {
    kubectl apply -f templates/
}

deploy_openshift_router() {
    kubectl create ns openshift-ingress
    kubectl apply -f router/
}

setup_e2e_test() {
    ../../cicd-scripts/setup-e2e-tests.sh -a install
}

run_e2e_test() {
    ../../cicd-scripts/run-e2e-tests.sh
}

deploy() {
    setup_kubectl_command
    install_jq
    create_kind_cluster hub
    deploy_crds
    deploy_templates
    deploy_service_ca_operator
    deploy_openshift_router
    setup_e2e_test
    # just for testing
    kubectl set image -n open-cluster-management deployment/multicluster-observability-operator multicluster-observability-operator=quay.io/songleo/multicluster-observability-operator:ssli-debug
    sleep 20
    kubectl apply -k ../../examples/minio
    kubectl apply -f ../../examples/mco/e2e/v1beta2/observability.yaml
    sleep 10000
    # deploy grafana-test
    # run_e2e_test
    # label to managedcluster vendor == "GKE"
}

deploy
