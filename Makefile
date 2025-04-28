PV_SIZE=12Gi
TOOLS_DIR=./tools
# ENV=${ENV:=""}
OPERATOR_NS=rook-ceph
ROOK_CLUSTER_NS=rook-ceph
PROMETHEUS_NS=openshift-user-workload-monitoring
REPO_ROOK=https://charts.rook.io/release
STORAGE_CLASSES=ceph-rbd cephfs
PROFILE_PREFIX=r00ki
ENV_SERVICE=service
ENV_CONSUMER=consumer
ENV_AIO=aio
AMTOOL_OUTPUT=simple
PART_SIZES=
PART_LABELS=
#PART_SIZES=1G
#PART_LABELS=metrics r00ki_bluestore
MINIKUBE_COMMON_START_ARGS=--container-runtime=containerd --cpus=2 --driver=kvm2 --network=default
# --wait=all -cni=cilium
# OLM Addon unsuprisingly ... broken
# MINIKUBE_COMMON_ADDONS=metrics-server olm
# message: Back-off pulling image "quay.io/operatorhubio/catalog@sha256:e08a1cd21fe72dd1be92be738b4bf1515298206dac5479c17a4b3ed119e30bd4"
# reason: ImagePullBackOff
MINIKUBE_COMMON_ADDONS=metrics-server
# Any amount of disks works in general
MINIKUBE_SERVICE_START_ARGS=$(MINIKUBE_COMMON_START_ARGS) --disk-size=40g --extra-disks=3
# wave=2 : Ensures operator is not removed, so it can take down everything else only 
HELMFILE_DESTROY_EXTRA_ARGS=--selector wave=2
# TODO: MANIFEST_DYNAMIC duplicated in helmfile
MANIFEST_DYNAMIC_PATH=apps/rook-ceph-cluster-external/files
MANIFEST_DYNAMIC=$(MANIFEST_DYNAMIC_PATH)/manifest-dynamic.yaml
# TODO: Beware of the k8s contexts!
.DEFAULT_GOAL := help


.PHONY: help
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


.PHONY: apply-apps 
apply-apps: ## Apply Apps
	if [ "$(APPS_ENV)" = "mini-$(ENV_SERVICE)" ] ; then \
		$(TOOLS_DIR)/kvm-helm-hack-apply-crds.sh; \
	else \
		$(TOOLS_DIR)/kvm-helm-hack-apply-crds.sh velero; \
	fi
	helmfile sync --concurrency 0 --environment $(APPS_ENV)

.PHONY: destroy-apps
destroy-apps: ## Destroy Apps
	 helmfile destroy --concurrency 0 --environment $(APPS_ENV) $(HELMFILE_DESTROY_EXTRA_ARGS) # HELMFILE_DESTROY_EXTRA_ARGS

.PHONY: patch-registry-mirror
patch-registry-mirror: ## Patch containerd registry mirror
	scp -o "StrictHostKeyChecking=no" -i $$(minikube --profile $(PROFILE_PREFIX)-$(ENV) ssh-key) $(TOOLS_DIR)/patch-containerd.sh docker@$$(minikube --profile $(PROFILE_PREFIX)-$(ENV) ip):
	$(TOOLS_DIR)/docker-registry-proxies.sh ghcr-proxy ghcr.io quay-proxy quay.io docker-proxy docker.io k8s-proxy registry.k8s.io | \
		ssh -o "StrictHostKeyChecking=no" -i $$(minikube --profile $(PROFILE_PREFIX)-$(ENV) ssh-key) docker@$$(minikube --profile $(PROFILE_PREFIX)-$(ENV) ip) \
		'chmod 755 patch-containerd.sh && sudo $${HOME}/patch-containerd.sh && sudo systemctl restart containerd && while [ ! -e /run/containerd/containerd.sock ]; do sleep 1; done'

.PHONY: apply-r00ki-aio
apply-r00ki-aio: ## Apply Ceph Service Cluster
	minikube $(MINIKUBE_SERVICE_START_ARGS) --profile $(PROFILE_PREFIX)-$(ENV_AIO) start
	if [ -n "$${PATCH_REGISTRY_MIRROR}" ] ; then make ENV=$(ENV_AIO) patch-registry-mirror ; fi
	[ -z "$(PART_LABELS)" ] || cat $(TOOLS_DIR)/prepare-disks.sh \
		| sed -e s,^PART_LABELS=.*,PART_LABELS="\"$(PART_LABELS)\"",g \
		| sed -e s,^PART_SIZES=.*,PART_SIZES="\"$(PART_SIZES)\"",g \
		| ssh -o "StrictHostKeyChecking=no" -i $$(minikube --profile $(PROFILE_PREFIX)-$(ENV_AIO) ssh-key) docker@$$(minikube --profile $(PROFILE_PREFIX)-$(ENV_AIO) ip) sudo bash
	for addon in $(MINIKUBE_COMMON_ADDONS) ; do minikube --profile $(PROFILE_PREFIX)-$(ENV_AIO) addons enable $${addon} ; done
	minikube --profile $(PROFILE_PREFIX)-$(ENV_AIO) addons enable volumesnapshots
	# kubectl api-versions # Wipe discovery cache / helm CRD workaround
	make APPS_ENV=mini-$(ENV_AIO) apply-apps

.PHONY: apply-r00ki-service
apply-r00ki-service: ## Apply Ceph Service Cluster
	minikube $(MINIKUBE_SERVICE_START_ARGS) --profile $(PROFILE_PREFIX)-$(ENV_SERVICE) start
	if [ -n "$${PATCH_REGISTRY_MIRROR}" ] ; then make ENV=$(ENV_SERVICE) patch-registry-mirror ; fi
	for addon in $(MINIKUBE_COMMON_ADDONS) ; do minikube --profile $(PROFILE_PREFIX)-$(ENV_SERVICE) addons enable $${addon} ; done
	make APPS_ENV=mini-$(ENV_SERVICE) apply-apps

.PHONY: apply-r00ki-consumer
apply-r00ki-consumer: ## Apply Ceph Consumer Cluster
	minikube $(MINIKUBE_COMMON_START_ARGS) --profile $(PROFILE_PREFIX)-$(ENV_CONSUMER) start
	if [ -n "$${PATCH_REGISTRY_MIRROR}" ] ; then make ENV=$(ENV_CONSUMER) patch-registry-mirror ; fi
	for addon in $(MINIKUBE_COMMON_ADDONS) ; do minikube --profile $(PROFILE_PREFIX)-$(ENV_CONSUMER) addons enable $${addon} ; done
	minikube --profile $(PROFILE_PREFIX)-$(ENV_CONSUMER) addons enable volumesnapshots
	make APPS_ENV=mini-$(ENV_CONSUMER) apply-apps

# TODO: Cluster(s) lifecycle should use CLUSTERS variable and we should dedupe
.PHONY: destroy-r00ki-aio
destroy-r00ki-aio: ## Destroy Ceph AIO Cluster
	minikube --profile $(PROFILE_PREFIX)-$(ENV_AIO) delete

.PHONY: destroy-r00ki-service
destroy-r00ki-service: ## Destroy Ceph Service Cluster
	minikube --profile $(PROFILE_PREFIX)-$(ENV_SERVICE) delete

.PHONY: destroy-r00ki-consumer
destroy-r00ki-consumer: ## Destroy Ceph Consumer Cluster
	minikube --profile $(PROFILE_PREFIX)-$(ENV_CONSUMER) delete

.PHONY: show-rook-resource-requests
show-rook-resource-requests: ## Show Rook Resource Requests
	kubectl get pods -n $(ROOK_CLUSTER_NS) -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,MEMORY_REQUEST:.spec.containers[*].resources.requests.memory,CPU_REQUEST:.spec.containers[*].resources.requests.cpu"

.PHONY: test-csi-io
test-csi-io: ## Run CSI IO Test
	for sc in $(STORAGE_CLASSES); do kubestr fio -s $${sc} -z $(PV_SIZE); done

.PHONY: test-csi-snapshot
test-csi-snapshot: ## Test CSI Snapshot
	for sc in $(STORAGE_CLASSES); do kubestr csicheck -s $${sc} -v $${sc}; done

.PHONY: test-s3-io
test-s3-io: ## Run S3 IO Test
	kubectl delete -f manifests/job-ob.yaml || true
	kubectl apply -f manifests/job-ob.yaml

.PHONY: test-velero
test-velero: ## Test Velero Backup
	kubectl delete -f manifests/nginx.yaml -f manifests/backup-rbd-pvc.yaml 2>/dev/null || true 
	. $(TOOLS_DIR)/s3-bucket-env.sh && kubectl run --rm -i aws-cli --image=amazon/aws-cli --env="AWS_ENDPOINT_URL=$${AWS_ENDPOINT_URL}" --env="AWS_HOST=$${AWS_HOST}" --env="AWS_ACCESS_KEY_ID=$${AWS_ACCESS_KEY_ID}" --env="AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY}" -- s3 rm --recursive s3://$${BUCKET_NAME}/backups || true 
	kubectl apply -f manifests/nginx.yaml 
	kubectl wait --timeout=180s --for=jsonpath='{.status.availableReplicas}'=1 deployment/nginx
	kubectl apply -f manifests/backup-rbd-pvc.yaml
	kubectl -n velero wait --timeout=180s --for=jsonpath='{.status.phase}'=Completed backup/rbd-pvc

.PHONY: debug-operator
patch-wipe: ## Patch the CephCluster to wipe host data/volumes 
	kubectl -n $(OPERATOR_NS) patch cephcluster rook-ceph --type merge \
		-p '{"spec":{"cleanupPolicy":{"confirmation":"yes-really-destroy-data"}}}'

# TODO: Ugly, but appears current helm chart does not support custom command line args - not even via environment? There is a Level in cm rook-ceph-operator-config?
.PHONY: debug-operator
debug-operator: ## Debug Operator
	kubectl -n $(OPERATOR_NS) patch deployment rook-ceph-operator --type='json' \
		-p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["ceph", "operator", "--log-level", "DEBUG"]}]'

.PHONY: show-ceph-dashboard-password
show-ceph-dashboard-password: ## Show Ceph Dashboard password
	kubectl -n $(ROOK_CLUSTER_NS) get secret rook-ceph-dashboard-password -o jsonpath="{.data.password}" | base64 -d

.PHONY: show-alerts
show-alerts: ## Show firing alerts
	@kubectl -n $(PROMETHEUS_NS) exec -it alertmanager-kube-prometheus-stack-alertmanager-0 -- amtool alert -o $(AMTOOL_OUTPUT) --alertmanager.url=http://alertmanager-operated:9093

# TODO: Try kubefwd to port forward multiple services at once
.PHONY: port-forward-grafana
port-forward-grafana: ## Port forward Grafana
	kubectl -n $(PROMETHEUS_NS) port-forward svc/kube-prometheus-stack-grafana 3000:80

.PHONY: port-forward-dashboard
port-forward-dashboard: ## Port forward Ceph Dashboard
	kubectl -n $(ROOK_CLUSTER_NS) port-forward svc/rook-ceph-mgr-dashboard 7000:7000 

.PHONY: show-ceph-status
show-ceph-status: ## Show Ceph Status
	kubectl rook-ceph ceph status

.PHONY: split-external-manifest
split-external-manifest: ## Split external manifest
	yq 'select(.kind != "Secret")' < $(MANIFEST_DYNAMIC) > $(MANIFEST_DYNAMIC_PATH)/manifest-misc.yaml
	yq 'select(.kind == "Secret")' < $(MANIFEST_DYNAMIC) > $(MANIFEST_DYNAMIC_PATH)/manifest-secrets.yaml
