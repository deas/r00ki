# virtualbox, kvm2, qemu2, qemu, vmware, none, docker, podman, ssh
DRIVER=kvm2
MINIKUBE_START_ARGS=--container-runtime=containerd --cpus=2 --driver=$(DRIVER) --network=default
# --kubernetes-version=v1.28.13
# --wait=all

.DEFAULT_GOAL := help

.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


.PHONY: apply-demo
apply-demo: ## Apply demo 
	minikube $(MINIKUBE_START_ARGS) --profile demo start --wait=all
	kubectl get pod -A
	minikube --profile demo ssh "ps -axww"
	# sleep 60
	helm upgrade -i olm oci://ghcr.io/cloudtooling/helm-charts/olm --debug --version 0.30.0

.PHONY: destroy-demo
destroy-demo: ## Destroy Demo
	minikube --profile demo delete
