NAMESPACE = mineshark
K8S_DIR = k8s

setup: secrets up

secrets:
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic rcon-secret --namespace=$(NAMESPACE) --from-literal=rcon-password="$(RCON_PASSWORD)" --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic curseforge-api-key --namespace=$(NAMESPACE) --from-literal=api-key="$(CF_API_KEY)" --dry-run=client -o yaml | kubectl apply -f -
	@test -f data/velocity/forwarding.secret || (mkdir -p data/velocity && openssl rand -hex 16 > data/velocity/forwarding.secret)
	@kubectl create secret generic velocity-forwarding-secret --namespace=$(NAMESPACE) --from-literal=forwarding-secret="$$(cat data/velocity/forwarding.secret)" --dry-run=client -o yaml | kubectl apply -f -

up:
	@kubectl apply -f $(K8S_DIR)/base/
	@kubectl apply -f $(K8S_DIR)/velocity/
	@kubectl apply -f $(K8S_DIR)/main/
	@kubectl apply -f $(K8S_DIR)/mod/

down:
	@kubectl -n $(NAMESPACE) delete deployment --all
	@kubectl -n $(NAMESPACE) delete svc --all

clean: down

fclean: clean
	@kubectl -n $(NAMESPACE) delete configmap --all
	@kubectl -n $(NAMESPACE) delete secret --all

re: fclean setup

status:
	@kubectl -n $(NAMESPACE) get pods,svc,pvc

logs-proxy:
	kubectl -n $(NAMESPACE) logs -f deployment/velocity -c velocity

logs-main:
	kubectl -n $(NAMESPACE) logs -f deployment/mc-main -c minecraft

logs-mod:
	kubectl -n $(NAMESPACE) logs -f deployment/mc-mod -c minecraft

mod-on:
	@kubectl -n $(NAMESPACE) scale deployment mc-mod --replicas=1

mod-off:
	@kubectl -n $(NAMESPACE) scale deployment mc-mod --replicas=0

.PHONY: setup secrets up down clean fclean re status logs-proxy logs-main logs-mod mod-on mod-off