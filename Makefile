vg-status:
	@echo "Listing the status of all Vagrant machines:"
	@vagrant global-status

vg-get-box:
	vagrant box add canonical/jammy64 https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-vagrant.box

# List the IP addresses of all Vagrant machines
vg-ip:
	@echo "Listing IP addresses of all Vagrant machines:"
	@for id in $$(vagrant global-status --machine-readable | awk -F, '/^machine/{print $$1}'); do \
		cd $$(dirname $$(vagrant global-status --machine-readable | grep $$id | cut -d',' -f2)); \
		echo "Machine: $$id"; \
		vagrant ssh-config | grep HostName; \
	done

# List the forwarded ports of all Vagrant machines
vg-ports:
	@echo "Listing forwarded ports of all Vagrant machines:"
	@for id in $$(vagrant global-status --machine-readable | awk -F, '/^machine/{print $$1}'); do \
		cd $$(dirname $$(vagrant global-status --machine-readable | grep $$id | cut -d',' -f2)); \
		echo "Machine: $$id"; \
		vagrant port; \
	done

vg-ssh-master:
	vagrant ssh k0s_master

vg-ssh-node1:
	vagrant ssh k0s_node1

vg-ssh-node2:
	vagrant ssh k0s_node2

update-certs:
	curl -sLo ./deployment/k0s/traefik/certs/fiksim_privkey.pem https://github.com/Voronenko/fiks.im/releases/download/$(shell curl -s https://api.github.com/repos/Voronenko/fiks.im/releases/latest | grep tag_name | cut -d '"' -f 4)/fiksim_privkey.pem
	curl -sLo ./deployment/k0s/traefik/certs/fiksim_cert.pem https://github.com/Voronenko/fiks.im/releases/download/$(shell curl -s https://api.github.com/repos/Voronenko/fiks.im/releases/latest | grep tag_name | cut -d '"' -f 4)/fiksim_cert.pem
	curl -sLo ./deployment/k0s/traefik/certs/fiksim_fullchain.pem https://github.com/Voronenko/fiks.im/releases/download/$(shell curl -s https://api.github.com/repos/Voronenko/fiks.im/releases/latest | grep tag_name | cut -d '"' -f 4)/fiksim_fullchain.pem
	kubectl delete secret fiksim-tls-secret --namespace=traefik --ignore-not-found
	kubectl create secret tls fiksim-tls-secret --cert=./deployment/k0s/traefik/certs/fiksim_fullchain.pem --key=./deployment/k0s/traefik/certs/fiksim_privkey.pem --namespace=traefik


install-k0s-ctl:
	curl -sLo ./k0sctl https://github.com/k0sproject/k0sctl/releases/download/$(shell curl -s https://api.github.com/repos/k0sproject/k0sctl/releases/latest | grep tag_name | cut -d '"' -f 4)/k0sctl-linux-amd64
	chmod +x ./k0sctl

k0s-version:
	kubectl version

k0s-init:
	k0sctl init > k0sctl.yaml

k0s-apply:
	k0sctl apply --debug --config k0sctl.yaml

k0s-longhorn-dashboard:
	kubectl apply -f deployment/k0s/longhorn/dashboard.yaml

k0s-troubleshoot-charts:
	kubectl -n kube-system get charts k0s-addon-chart-traefik k0s-addon-chart-metallb k0s-addon-chart-longhorn -o custom-columns=NAME:.metadata.name,ERROR:.status.error

k0s-print-lbs:
	@echo "NGINX ingress":
	@kubectl get services --namespace ingress-nginx ingress-nginx-controller --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
	@echo "\r\nTraefik ingress":
	@kubectl get services  --namespace traefik traefik --output jsonpath='{.status.loadBalancer.ingress[0].ip}'

helm-repos-add:
	helm repo add longhorn https://charts.longhorn.io
	helm repo add traefik https://traefik.github.io/charts
	helm repo add metallb https://metallb.github.io/metallb

helm-metallb-install:
	helm upgrade --install metallb metallb/metallb --create-namespace --namespace metallb-system --wait
	kubectl apply -f deployment/k0s/metallb/metallb-l2-pool.yaml

helm-traefik-install:
	helm upgrade --install --create-namespace --namespace=traefik --values deployment/k0s/traefik/values.yaml traefik traefik/traefik
	kubectl apply -f deployment/k0s/traefik/dashboard.yaml
	kubectl apply -f deployment/k0s/traefik/whoami.yaml
helm-nginx-ingress-install:
	helm upgrade --install ingress-nginx ingress-nginx \
		--repo https://kubernetes.github.io/ingress-nginx \
		--namespace ingress-nginx --create-namespace

clean-ssh-fingerprints:
	ssh-keygen -f "$(HOME)/.ssh/known_hosts" -R "node1.fiks.im"
	ssh-keygen -f "$(HOME)/.ssh/known_hosts" -R "node2.fiks.im"
	ssh-keygen -f "$(HOME)/.ssh/known_hosts" -R "master.fiks.im"
	ssh-keygen -f "$(HOME)/.ssh/known_hosts" -R "192.168.56.71"
	ssh-keygen -f "$(HOME)/.ssh/known_hosts" -R "192.168.56.72"
	ssh-keygen -f "$(HOME)/.ssh/known_hosts" -R "192.168.56.70"
	ssh-keyscan -H node1.fiks.im >> ~/.ssh/known_hosts
	ssh-keyscan -H node2.fiks.im >> ~/.ssh/known_hosts
	ssh-keyscan -H master.fiks.im >> ~/.ssh/known_hosts

build:
	vagrant up
	vagrant reload
	k0sctl apply --config k0sctl.yaml

get-kubeconfig:
	k0sctl kubeconfig > kubeconfig

fwd-ui-longhorn:
	echo "UI will be at port 8000"
	kubectl -n longhorn-system port-forward service/longhorn-frontend 8000:80
fwd-ui-traefik:
	echo "UI will be at port 8080"
	echo 'kubectl port-forward $(kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name) 8080:8080'
	kubectl port-forward $(shell kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name) 8080:8080
ui-longhorn:
	xdg-open https://vg-longhorn.fiks.im/
ui-traefik:
	xdg-open https://vg-traefik.fiks.im/

print-ingesses:
	kubectl get ingresses --all-namespaces -o custom-columns='NAMESPACE:.metadata.namespace, NAME:.metadata.name, HOSTS:.spec.rules[*].host'
