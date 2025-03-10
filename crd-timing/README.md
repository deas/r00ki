There is a problem in this code.

The following `helm` command fails:

```
helm upgrade -i olm oci://ghcr.io/cloudtooling/helm-charts/olm --debug --version 0.30.0
```

It is part of a bigger command sequence which gets executed calling

```
make apply-demo
```

It fails because CRDs are not available at resource creation time, even though
the actual CRD creation succeeds.

There are observations hinting at needs to wait for certain conditions:

1. Adding a `sleep 60` after minikube cluster creation when using the `kvm2` driver.
2. Using an alternative minikube driver, such as `docker`

Attached, you'll find the `Makefile` and the output of the following command:

```
make apply-demo ; make destroy-demo ; make MINIKUBE_START_ARGS=--driver=docker apply-demo ; make destroy-demo
```

Identify the issues and rewrite the code with fixes. Explain what was wrong
and how your changes address the problems.

Feel free to ask for further diagnostic commands.
