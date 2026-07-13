# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

R00ki deploys Rook Ceph storage (RBD, CephFS, S3/RGW, snapshots, Velero backup) plus observability to Kubernetes — from local minikube to production OpenShift. It is helmfile-driven (a deliberate decision over ArgoCD), with Make targets for cluster lifecycle and imperative glue in `tools/`.

## Commands

`make` (no args) prints help for all targets. Common flows:

```sh
# Cluster lifecycle (minikube, kvm2 driver, profiles r00ki-{aio,service,consumer})
make apply-r00ki-aio          # all-in-one cluster: Ceph service + external-cluster consumer bits
make apply-r00ki-service      # Ceph-serving cluster (extra disks attached)
make apply-r00ki-consumer     # consumer cluster attaching to the service cluster
make destroy-r00ki-aio        # minikube delete (same for -service / -consumer)

# Deploy/undeploy apps onto an existing cluster
make APPS_ENV=mini-aio apply-apps      # helmfile sync --environment <APPS_ENV>
make APPS_ENV=mini-aio destroy-apps    # destroys only wave=2 releases (see below)

# Tests (run against a live cluster; need kubestr)
make test-csi-io              # kubestr fio on ceph-rbd + cephfs storage classes
make test-csi-snapshot        # kubestr csicheck per storage class
make test-s3-io               # applies manifests/job-ob.yaml (ObjectBucketClaim IO)
make test-velero              # end-to-end backup of an nginx RBD PVC

# Debugging / inspection
make show-ceph-status         # kubectl rook-ceph ceph status (needs rook-ceph krew plugin)
make show-alerts              # firing Alertmanager alerts via amtool
make show-ceph-dashboard-password
make port-forward-grafana     # localhost:3000
make port-forward-dashboard   # Ceph dashboard, localhost:7000
make debug-operator           # patch operator deployment to --log-level DEBUG
```

Prerequisites: `make`, `minikube`, `kubectl`, `helmfile`; tests additionally use `kubestr`, `yq`, and the `kubectl rook-ceph` plugin. `.envrc` loads `.env` via direnv.

## Architecture

### helmfile.yaml is the orchestrator

Six environments = {mini, openshift} × {aio, service, consumer}. Environment values are feature toggles (`velero.enabled`, `rook-ceph-cluster-external.enabled`, `rook-ceph-service.enabled`, `openshift`) that conditionally include releases and pick value files:

- **aio**: one cluster runs the Ceph service *and* consumes it via the external-cluster path (exercises the full trust handoff locally).
- **service**: serves Ceph only. **consumer**: attaches to a service cluster's Ceph via `rook-ceph-cluster-external`.
- **openshift envs**: skip OLM install (operators come via OLM `Subscription`s in `apps/operators`) and skip kube-prometheus-stack (native user-workload monitoring is used instead).

Release ordering is via `needs:` plus a `wave: 2` label: `destroy-apps` only destroys `--selector wave=2` releases so the Rook operator survives to tear down the CephCluster cleanly.

### Ceph-CSI is a separate release (Rook >= 1.20)

Rook no longer deploys the CSI drivers. The `rook-ceph` chart bundles the **ceph-csi-operator** as a subchart (`csi.installCsiOperator`), but the `Driver` CRs it reconciles come from a *third* chart, `ceph-csi-drivers` (repo `https://ceph.github.io/ceph-csi-operator`). Without that release no volume ever mounts. It is gated on `rook-ceph-cluster-external.enabled` — exactly the clusters that consume Ceph via CSI — and labelled `wave: 2` so the Driver CRs are torn down while the csi-operator is still alive. Service clusters set `csi.installCsiOperator: false` instead; that is the replacement for the old `csi.enable{Rbd,Cephfs}Driver: false`.

Two traps here, both silent:

- The old `csi.*` tuning keys (`enableLiveness`, `enableGrpcMetrics`, `csi*Resource`, `cephFSKernelMountOptions`, …) no longer exist, and neither Rook chart ships a `values.schema.json` — leftovers are **ignored, not rejected**. Per-driver settings now live in the ceph-csi-operator `OperatorConfig`/`Driver` CRs.
- The `ceph-csi-drivers` chart defaults `drivers.rbd.snapshotPolicy` to `none` (only cephfs/nfs default to `volumeSnapshot`), and Rook's own "values for Rook" file does not override it. The RBD controller plugin then comes up **without a `csi-snapshotter` sidecar** and every RBD snapshot fails — which breaks `test-csi-snapshot` and Velero's snapshot data movement. `apps/ceph-csi-drivers/values.yaml` sets it to `volumeSnapshot` explicitly.

The Ceph image also moved: the cluster chart renders `cephClusterSpec.cephVersion` from the **top-level `cephImage`** block, so `cephVersion` must not also appear in `cephClusterSpec` or both render.

### apps/ layout convention

`apps/<release>/envs/<environment>/values.yaml` — helmfile resolves value files by release name + environment name. Upstream charts (rook-ceph, rook-ceph-cluster, kube-prometheus-stack, velero) get values-only directories; local charts have `Chart.yaml` + `templates/`:

- `apps/operators` — OLM Subscriptions (grafana-operator, etc.)
- `apps/openshift-user-workload-monitoring` — Grafana instance, Ceph dashboards, datasources, monitoring configmaps; same chart serves minikube (against kube-prometheus-stack) and OpenShift (against UWM), both in the `openshift-user-workload-monitoring` namespace
- `apps/ceph-csi-drivers` — values-only; the ceph-csi-operator `Driver` CRs (see above). Driver names encode the operator namespace and must match the provisioners Rook writes into StorageClasses.
- `apps/rook-ceph-cluster-external` — consumer side: imports the exported service-cluster manifests, StorageClasses, ObjectBucketClaim, snapshot classes
- `apps/rook-ceph-export` — configmap wrapping Rook's upstream `create-external-cluster-resources.py`

`**/values-chart.yaml` files are gitignored reference copies of upstream chart defaults.

### Service → consumer trust handoff

The core non-obvious flow, mostly under `tools/`:

1. After `rook-ceph-cluster` syncs on a service/aio cluster, a helmfile `postsync` hook runs `tools/prepare-consumer.sh`: waits for the CephBlockPool/CephObjectStore to be Ready, then generates `config.ini` (external-cluster credentials, format like `config-sample.ini`).
2. `tools/gen-external-cluster-config-manifests.sh` sources `config.ini` and emits `apps/rook-ceph-cluster-external/files/manifest-dynamic.yaml` (secrets, mon endpoints, configmaps for the consumer).
3. `make split-external-manifest` splits that into `manifest-misc.yaml` / `manifest-secrets.yaml` (so secrets can be sealed separately; see `tools/secrets-to-sealedsecrets.sh`).

Both halves are **version-locked to Rook and must be re-vendored on every Rook bump**, and neither fails loudly if you forget:

- `tools/create-external-cluster-resources.py` (and its copy in `apps/rook-ceph-export/assets/`) is a verbatim vendored copy of `deploy/examples/create-external-cluster-resources.py` from the pinned Rook tag. Diff it against upstream after bumping.
- `tools/gen-external-cluster-config-manifests.sh` is a fork of Rook's `deploy/examples/import-external-cluster.sh` that emits YAML instead of applying it. Re-diff it against upstream on every bump. Rook 1.20 renamed the CephFS CSI secret keys `adminID`/`adminKey` → `userID`/`userKey`, added `controller-publish-secret-*` to the StorageClasses, and added cephx key-generation suffixes (`CEPHX_KEY_GENERATION`, `<user>.<gen>`) — all three are carried in the fork.

Note the aio env short-circuits this: `prepare-consumer.sh` only runs the exporter for `service`, and only generates the manifest when not `aio`. So aio exercises the Rook-created in-cluster secrets, *not* the fork — the fork is only exercised by the service → consumer flow.

`config.ini*` and `manifest-dynamic.yaml` are gitignored — they contain live credentials. Never commit them or their contents.

### Toolchain: helm 4 + helmfile 1 (pinned)

`.mise.toml` pins helm and helmfile together, and they must move together. helmfile 0.x probes `helm version --client`, a flag helm 4 removed, so an unpinned helm rolling to 4.x makes helmfile 0.x panic before deploying anything. helmfile >= 1.0 also requires the state file to be named `helmfile.yaml.gotmpl` to be Go-templated, with `environments` and `releases` in separate YAML parts (`---`).

Because helm 4 applies server-side, `helmDefaults.syncArgs: --force-conflicts` is set: OLM writes into the packageserver CSV's `.spec.install.spec.deployments`, so it co-owns fields the olm chart also sets and a re-sync would fail on a field-manager conflict. Helm 3's client-side apply overwrote those silently.

### Historical: the helm/CRD timing race on kvm2 minikube

`apply-apps` used to pre-apply OLM/prometheus/grafana/velero CRDs plus `sleep 60`. The underlying race was real under helm 3: charts that ship CRDs in `crds/` *and* consume them in `templates/` (olm, kube-prometheus-stack, velero) could fail with "ensure CRDs are installed first", because helm's readiness check has no `CustomResourceDefinition` case — it confirmed the CRDs existed but not that they were `Established` and published in API discovery, and a cold 2-CPU kvm2 apiserver lost that race. Under helm 4 this no longer reproduces on a cold cluster, so the pre-apply and the sleep are gone and `apply-apps` is a single `helmfile sync`. If it ever resurfaces, gate the affected release with a `presync` hook running `kubectl wait --for=condition=Established crd/<name>` — don't reintroduce a blind sleep.
