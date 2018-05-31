VERSION ?= $(VERSION)
GCP_PROJECT_ID ?=$(GCP_PROJECT_ID)

IMAGE ?= shippy-prod/kube-airflow
TAG ?= $(VERSION)
ALIAS ?= gcr.io/$(GCP_PROJECT_ID)/$(IMAGE)
REMOTE_IMAGE_PATH=${ALIAS}:${VERSION}
NAMESPACE ?= shippy-prod

build:
	protoc --proto_path=. --go_out=. --micro_out=. \
		proto/auth/auth.proto
	@echo "INOF: buiding image: $(IMAGE):$(TAG) ALIAS: $(ALIAS):$(TAG)"
	docker build -t $(IMAGE):$(TAG) . && docker tag $(IMAGE):$(TAG) $(ALIAS):$(TAG)

publish: build
	@echo "INFO: to publish $(ALIAS):$(TAG)"
	gcloud docker -- push $(ALIAS):$(TAG)
	gcloud container images list-tags $(ALIAS)

run:
	docker run --net="host" \
		-p 50051 \
		-e DB_HOST=localhost \
		-e DB_PASS=password \
		-e DB_USER=postgres \
		-e MICRO_SERVER_ADDRESS=:50051 \
		-e MICRO_REGISTRY=mdns \
		shippy-user-service

create: publish
	if ! kubectl get namespace $(NAMESPACE) >/dev/null 2>&1; then \
	  kubectl create namespace $(NAMESPACE); \
	fi
	cat ./deployments/deployment.tmpl | sed -e 's|%%REMOTE_IMAGE_PATH%%|$(REMOTE_IMAGE_PATH)|g' | kubectl create --record --save-config --namespace $(NAMESPACE) -f -

apply: publish
	cat ./deployments/deployment.tmpl | sed -e 's|%%REMOTE_IMAGE_PATH%%|$(REMOTE_IMAGE_PATH)|g' | kubectl --namespace $(NAMESPACE) apply --record -f -

# edit or replace
# flower should be updated when the version of airflow is changed
rolling-update:
	kubectl --namespace $(NAMESPACE) set image deployment/user user=$(REMOTE_IMAGE_PATH) --record

#--to-revision=<revision>
rollback:
	kubectl --namespace $(NAMESPACE) rollout undo deployment user

deploy:
	cat ./deployments/deployment.tmpl | sed -e 's|%%REMOTE_IMAGE_PATH%%|$(REMOTE_IMAGE_PATH)|g' | kubectl --namespace $(NAMESPACE) apply --record -f -

#delete:
#	kubectl delete -f airflow.all.yaml --namespace $(NAMESPACE)

list-pods:
	kubectl get po -a --namespace $(NAMESPACE)

list-services:
	kubectl get svc -a --namespace $(NAMESPACE)

# pod_name=web-2874099158-lxgm2 make login-pod
login-pod:
	kubectl --namespace $(NAMESPACE) exec -it $(pod_name) -- /bin/bash

# pod_name=web-2874099158-lxgm2 make describe-pod
describe-pod:
	kubectl describe pod/$(pod_name) --namespace $(NAMESPACE)

deploy: publish
	sed "s/{{ UPDATED_AT }}/$(shell date)/g" ./deployments/deployment.tmpl > ./deployments/deployment.yml
	kubectl replace -f ./deployments/deployment.yml
