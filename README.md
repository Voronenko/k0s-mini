Based on 

https://github.com/rgl/k0s-vagrant/tree/main

## Extra config

Helm charts

https://docs.k0sproject.io/stable/helm-charts/


## Theory
###  What is k0s?
k0s is a lightweight Kubernetes distribution from the team behind Lens. The “zero” in k0s aptly represents the distro’s zero compromises, dependencies, or downtime issues.

k0s is easy to run anywhere – bare metal, on-prem, locally, and on any cloud provider. It doesn’t have any dependencies and is distributed in a single binary. With k0s, you don’t have to worry excessively about config (unlike many k8s options), and can get a cluster spun up within minutes — all important considerations for local dev or other lightweight use cases.

### What is k3s?
Rancher’s k3s is a lightweight yet highly configurable Kubernetes distribution. k3s’ name reflects its status as the smaller cousin of traditional k8s, and thus has half the characters represented (ten total letters versus five). However, unlike k8s, there is no “unabbreviated” word form of k3s.

k3s is also distributed as a dependency-free, single binary. It helps engineers achieve a close approximation of production infrastructure while only needing a fraction of the compute, config, and complexity, which all result in faster runtimes.

### K0s vs K3s
k0s and k3s are both CNCF-certified k8s distributions, and meet all the benchmarks/requirements for standard k8s clusters. They’re both good options for teams looking for lighter-weight and easy to configure cluster solutions.

Cluster architecture
k3s supports both single and multi-node clusters. Its control plane defaults to SQLite for its embedded datastore on all cluster types, and multi-node clusters can be configured to use MySQL, PostgreSQL, and etcd.

k0s also accommodates single and multi-node clusters. Its datastore defaults to SQLite for single-node clusters, and to etcd for multi-node clusters. The datastore can also be configured to use PostgreSQL and MySQL.

Like standard k8s, k0s has a distinct separation between worker and control planes, which can be distributed across multiple nodes.

Both distros use containerd for their container runtimes. k0s ships without a built-in ingress controller; stock k3s comes with Traefik.

### k0s.yaml

Allows auto-configuration of k0s cluster. Check for some hints and examples:

Working with helm charts:

https://docs.k0sproject.io/v1.32.1+k0s.0/helm-charts/

#### Nginx ingress controller:
https://docs.k0sproject.io/v1.32.1+k0s.0/examples/nginx-ingress/
https://blog.helmuth.at/2024/11/k0s-ingress-part2/


#### Metal load balancer

https://docs.k0sproject.io/v1.32.1+k0s.0/examples/metallb-loadbalancer/

For manual experimentation

```sh
helm-install-metallb:
        helm upgrade --install metallb metallb/metallb --create-namespace --namespace metallb-system --wait
        kubectl apply -f deployment/k0s/metallb/metallb-l2-pool.yaml
```

Some ideas for networks from your home router to associate
```
192.168.3.192/28	192.168.3.192 - 192.168.3.207	192.168.3.193 - 192.168.3.206	14				
192.168.3.208/28	192.168.3.208 - 192.168.3.223	192.168.3.209 - 192.168.3.222	14		
192.168.3.224/28	192.168.3.224 - 192.168.3.239	192.168.3.225 - 192.168.3.238	14		
192.168.3.240/28	192.168.3.240 - 192.168.3.255	192.168.3.241 - 192.168.3.254	14	
```

which you need additionally to route to any vagrant machine

`sudo ip route add 192.168.3.192/28 via 192.168.56.7`


#### Traefik load balancer

```sh

helm-install-traefik:
  helm install --namespace=traefik traefik traefik/traefik
```

After you installed both, metallb and traefik, you should be able to discover external IP for traefik:
Note EXTERNAL-IP is the IP of the same vagrant cluster machine where you installed traefik
On your machine it should be accessible.

```shell
kubectl get all
Alias tip: kga
NAME                           READY   STATUS    RESTARTS   AGE
pod/traefik-7bc5f58897-2hcm8   1/1     Running   0          31s

NAME              TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                      AGE
service/traefik   LoadBalancer   10.103.118.147   192.168.3.201   80:31449/TCP,443:30821/TCP   31s

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/traefik   1/1     1            1           31s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/traefik-7bc5f58897   1         1         1       31s
```


## After vagrant up, you have:

### nodes
```
 kubectl get nodes
Alias tip: kgno
NAME    STATUS   ROLES    AGE   VERSION
node1   Ready    <none>   30m   v1.31.5+k0s
node2   Ready    <none>   30m   v1.31.5+k0s
```

### Metalb load balancer should be available


In order to proceed further, you need to have a load balancer available for the Kubernetes cluster.
Should you have difficulties out of the box, you can use the following example.

To verify that it's available, deploy a simple load balancer service.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: example-load-balancer
spec:
  selector:
    app: web
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
```

`kubectl apply -f example-load-balancer.yaml`

Then run the following command to see your LoadBalancer with an external IP address.

`kubectl get service example-load-balancer`

If the LoadBalancer is not available, you won't get an IP address for EXTERNAL-IP. Instead, it's `<pending>`. In this case you should go back to the previous step and check your load balancer availability.

If you are successful, you'll see a real IP address and you can proceed further.

You can delete the example-load-balancer:

`kubectl delete -f example-load-balancer.yaml`


### longhorn storage class

defining storage classes based on longhorn you could potentially easier imitate storage classes used in 
prod environment, so that your experiment would have as less differences as possible

```shell
kubectl get storageclass
Alias tip: k get storageclass
NAME                 PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
longhorn (default)   driver.longhorn.io   Delete          Immediate           true                   24h
longhorn-static      driver.longhorn.io   Delete          Immediate           true                   24h
```

With UI on https://vg-longhorn.fiks.im/

```sh
kubectl get storageclasses
Alias tip: k get storageclasses
NAME                 PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
longhorn (default)   driver.longhorn.io   Delete          Immediate           true                   18m
longhorn-static      driver.longhorn.io   Delete          Immediate           true                   18m
```

### Traefik ingress controller

With UI on https://vg-traefik.fiks.im/dashboard/#/

By default, cluster is based on "fiks.im" local development environment, with few addresses overwritten
via /etc/hosts. You can always get up-to-date green seal certificates from https://github.com/Voronenko/fiks.im

Test deployment 


### Nginx ingress controller

Note, that applying after traefik ingress controller, it will use next public IP available to metallb cluster load
balancer, thus you should point nginx enabled services to that IP, don't be confused.

Should you test, deploy dummy-nginx-test app, which should be available on https://vg-dummy.fiks.im/

ideas for usage

```yaml
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: example
    namespace: foo
  spec:
    ingressClassName: nginx
    rules:
      - host: www.example.com
        http:
          paths:
            - pathType: Prefix
              backend:
                service:
                  name: exampleService
                  port:
                    number: 80
              path: /
    # This section is only required if TLS is to be enabled for the Ingress
    tls:
      - hosts:
        - www.example.com
        secretName: example-tls

If TLS is enabled for the Ingress, a Secret containing the certificate and key must also be provided:

  apiVersion: v1
  kind: Secret
  metadata:
    name: example-tls
    namespace: foo
  data:
    tls.crt: <base64 encoded cert>
    tls.key: <base64 encoded key>
  type: kubernetes.io/tls
```

## Tools and notes

Visual subnet calculator
https://www.davidc.net/sites/default/subnets/subnets.html


## Troubleshouting

### Optimize space

Change default replica count for volumes to 1 from kubernetes default 3

`kubectl edit cm longhorn-storageclass -n longhorn-system`
kubectl edit cm longhorn-storageclass -n longhorn-system
