# Kubernetes Deployment

This directory packages the filer application to run on Kubernetes.

This depends heavily on the [Carvel](https://carvel.dev) tool set.  You will need `kapp`, `ytt`, and `kbld`, plus your cluster needs `secretgen-controller` and an ingress controller running.

```sh
brew tap carvel-dev/carvel
brew install kapp ytt kbld

kapp deploy -a sg -f https://github.com/carvel-dev/secretgen-controller/releases/latest/download/release.yml
```

On Minikube, you can deploy this as:

```sh
minikube addons install nginx
ytt -v ingress.hostName=$(minikube ip) -v ingress.className=nginx -f config \
  | kbld -f kbld.yml -f - \
  | kapp deploy -a filer -y -f -
```

Other possible configuration options are listed in `config/**/schema.yml`, and `ytt` supports a `--data-values-file=name.yml` option to provide these in a file.

When you run the scanner, you will target the external ingress host name and port.

## Implementation Notes

### ytt setup

There seem to be two fundamental ways to drive ytt: write a series of template functions that generate large parts of the logic (just like in Helm), or generate a skeleton YAML manifest and use overlays to inject the content.

I've gone with the latter model.  I have no idea if it's idiomatic.  Things that need database details, for example, configure in their Deployment or StatefulSet YAML

```yaml
env:
  - name: POSTGRES_HOST
  - name: POSTGRES_DB
  - name: POSTGRES_USER
  - name: POSTGRES_PASSWORD
```

and then a ytt overlay fills in all of these details.

### Erlang clustering

[libcluster](https://hexdocs.pm/libcluster) seems to be the standard way to set this up, if you want or need to dynamically discover cluster members.  Roger Lipscombe's [libcluster and Kubernetes](https://blog.differentpla.net/blog/2022/01/08/libcluster-kubernetes/) is also a helpful overview.  The two tricks here are that (1) when one node (the "initiator") attempts to connect to the other (the "acceptor") then the two nodes must agree on the acceptor's node name; and (2) what names exactly are available depends on whether the destination is a StatefulSet or not.

For consistency and simplicity, we configure this using [libcluster's Kubernetes DNS lookup scheme](https://hexdocs.pm/libcluster/Cluster.Strategy.Kubernetes.DNS.html); with a separate active libcluster topology per component; consistently using IP-based node names everywhere.  So you'll see a node name like `filer-store@10.20.30.40`.  This works consistently with our mix of Deployment- and StatefulSet-based components, and doesn't require a ServiceAccount.
