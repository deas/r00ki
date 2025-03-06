<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->

<a id="readme-top"></a>

<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
<!--
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
-->
<!--
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
-->

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <!--a href="https://github.com/deas/r00ki">
    <img src="images/logo.png" alt="Logo" width="80" height="80">
  </a-->

<h3 align="center">R00ki : Taking Rook Ceph from localhost to Production 🧪</h3>

  <p align="center">
    <!--project_description
    <br /-->
    <!--a href="https://github.com/deas/r00ki"><strong>Explore the docs »</strong></a>
    <br /-->
    <br />
    <!-- a href="https://github.com/deas/r00ki">View Demo</a>
    ·
    -->
    <a href="https://github.com/deas/r00ki/issues/new?labels=bug&template=bug-report---.md">Report Bug</a>
    ·
    <a href="https://github.com/deas/r00ki/issues/new?labels=enhancement&template=feature-request---.md">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <!--ul>
        <li><a href="#built-with">Built With</a></li>
      </ul-->
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#usage">Usage</a></li>
      </ul>
    </li>
    <li><a href="#todo">TODO</a></li>
    <li><a href="#known-issues">Known Issues</a></li>
    <li><a href="#references">References</a></li>
    <li><a href="#license">License</a></li>
    <!--
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
    -->
  </ol>
</details>

<!-- ABOUT THE PROJECT -->

## About The Project

<!--
[![Product Name Screen Shot][product-screenshot]](https://example.com)
-->
<!--
Here's a blank template to get started: To avoid retyping too much info. Do a search and replace with your text editor for the following: `github_username`, `repo_name`, `twitter_handle`, `linkedin_username`, `email_client`, `email`, `project_title`, `project_description`

-->

Kubernetes Storage. Rook. The Boss Fight. Still a bit messy. But it works. Most of the time.

There must be a reason [Red Hat OpenShift Data Foundation](https://docs.redhat.com/en/documentation/red_hat_openshift_data_foundation) is expensive ...

Now seriously: Storage is one of the most critical bits in general. Many workloads are stateful, and not every Kubernetes infrastructure solves the problem nicely. That was where I found myself a few times in the past. We we given virtual machines with basic disks attached - VMware VMDKs in my case. Customers were in demand of ... you name it - everything: RWX-/RWO Volumes, S3, Snapshots, Backup/Recovery - superfast and always available. The code reflects these roots.

Disclaimer: We started by borrowing proven things from the Rook project - adapted them as we went along.

<!-- https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/organizing-information-with-collapsed-sections -->
<details>
<summary>Demo creating a Minikube cluster and running a few tests 🪄🎩🐰</summary>

```sh
 make apply-r00ki-aio test-csi-io test-csi-snapshot test-velero
```

![Demo](./assets/demo.gif)

</details>

### Goals

- Awesome local first Rook Ceph Dev Experience
- First Class Observability
- Fail early and loud (Notifications)
- Simplicity (yes, really)
- Composability
- Target `minikube`, vanilla Kubernetes and Openshift.
- Add the Rook Ops bits not covered by the Operator
- Declarative trumps Imperative

### Non Goals

### Decisions

- ArgoCD is great, but `helmfile` appears even better for our use case
- We aim for first class citizens. For Rook, it's the helm charts, for some operators, its OLM Subscriptions.

### Features

We cover:

- Single (All in Once Cluster) Deployments targetting `minikube` and Production Kubernetes (including Openshift)
- Two Cluster Deployments (Service and Consumer) targetting `minikube` and Production Kubernetes (including Openshift)
- Kube-Prometheus bits all wired up - including alerts
- Shiny Dashboards (including Grafana)
- Seamless integration with ArgoCD, specifically [`deas/argcocd-conductor`](https://github.com/deas/argcocd-conductor)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!--
### Built With

* [![Docker][Docker]][Docker-url]
* [![Terraform][Terraform]][Terraform-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>

-->

<!-- GETTING STARTED -->

## Getting Started

Some opinions first:

- Ceph is complex
- Automating Trust Relationships is hard

### Prerequisites

- `make`
- `minikube`
- `kubectl`
- `helmfile`

### Usage

Run

```sh
make
```

shows help for basic tasks and give you an idea where to start.

We want lifecycle of things (Create/Destroy) to be as fast as possible. We ship support to levarage registry mirrors using pull through.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- TODO -->

## TODO

<!--
- [ ] Feature 1
- [ ] Feature 3
    - [ ] Nested Feature
-->

- Use `dyff` to separate out value files?
- Separate out Observability, add Logging and Alerting
- Support for Mon v2
- Support for TLS/encryption
- Replace imperative bits by declarative ones
- Introduce Pentesting - maybe even Chaos Scenarios
- Improve Observability / Include Alerts
- Smoketests in CI
- Cleanup bits aroud `TODO` tags sprinkled across the code
- Use LVM instead of raw disks/partitions?
- Performance: How/When do multiple disks per node make sense?
- Exercise Upgrade/Recreate and Desaster Recovery + build tests
- Introduce unhappy path tests -likely leveraging Litmus
- Proper cascaded removal of `CephCluster`?
- Finding-/cleaning up orphans (volumes or buckets)
- Go deeper with `nix`/`devenv` - maybe even replace `mise`

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Known Issues

- With kvm + minikube, there appears to be a timing issue with helm when used via helmfile. `helm upgrade` sometimes fails due to CRDs unavailable - s. [fix: clear the discovery cache after CRDs are installed](https://github.com/helm/helm/pull/6332)
- ["To sum up: the Docker daemon does not currently support multiple registry mirrors ..."](https://blog.alexellis.io/how-to-configure-multiple-docker-registry-mirrors/) -> `minikube start --registry-mirror="http://yourmirror"`
- kvm network dns(masq) slow from minikube kubernetes. Times out for s3.
  Patching coredns gets around the issue.
- mons on port 3300 (workaround: use port 6789 / `ROOK_EXTERNAL_CEPH_MON_DATA`): `2024-12-16T16:56:02.784+0000 7fd593d1c000 -1 failed for service _ceph-mon._tcp
mount error: no mds (Metadata Server) is up. The cluster might be laggy, or you may not be authorized
  Warning  FailedMount  2m25s  kubelet  (combined from similar events): MountVolume.MountDevice failed for volume "pvc-026c86e8-9ee4-4261-a7e4-083011b80494" : rpc error: code = Internal desc = an error (exit status 32) occurred while running mount args: [-t ceph 192.168.122.231:3300:/volumes/csi/csi-vol-7072e90c-5d6b-477b-bbab-655b76d0425f/e8d828a3-a1ad-4a22-9b36-7d5bc9fe9026 /var/lib/kubelet/plugins/kubernetes.io/csi/rook-ceph.cephfs.csi.ceph.com/f172f41f387d01c38f46e71a4097304d70c35494e81e1c8a070549de56234790/globalmount -o name=csi-cephfs-node,secretfile=/tmp/csi/keys/keyfile-2436134297,mds_namespace=myfs,_netdev] stderr: unable to get monitor info from DNS SRV with service name: ceph-mon`
- [Looking up Monitors through DNS](https://docs.ceph.com/en/latest/rados/configuration/mon-lookup-dns/)
- [OperatorHub Sub Outdated - at 1.1.1](https://operatorhub.io/operator/rook-ceph)

## References

- [Monitor OpenShift Virtualization using user-defined projects and Grafana](https://developers.redhat.com/articles/2024/08/19/monitor-openshift-virtualization-using-user-defined-projects-and-grafana)
- [How to create a long lived service account token in RHOCP4](https://access.redhat.com/solutions/7025261)
<!-- CONTRIBUTING -->

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>
<!--
### Top contributors:

<a href="https://github.com/deas/r00ki/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=deas/r00ki" alt="contrib.rocks image" />
</a>
-->

<!-- LICENSE -->

## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACT -->
<!--
## Contact

Your Name - [@twitter_handle](https://twitter.com/twitter_handle) - email@email_client.com

Project Link: [https://github.com/deas/r00ki](https://github.com/deas/r00ki)

<p align="right">(<a href="#readme-top">back to top</a>)</p>
-->

<!-- ACKNOWLEDGMENTS -->
<!--
## Acknowledgments

* []()
-->

<!-- p align="right">(<a href="#readme-top">back to top</a>)</p-->

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
