SHELL := /bin/bash

.PHONY: kube-info kubeconfig-merge kind-create kind-destroy infra-up infra-down grafana verify-infra up down apps-up apps-down smoke \
	fastapi-up fastapi-build fastapi laravel-up laravel-build laravel symfony-up symfony-build symfony symfony-consumer-up

kube-info:
	./scripts/kube-info.sh

kubeconfig-merge:
	./scripts/kubeconfig-merge.sh

kind-create:
	./scripts/kind-create.sh

kind-destroy:
	./scripts/kind-destroy.sh

infra-up:
	./scripts/infra-up.sh

infra-down:
	./scripts/infra-down.sh

grafana:
	./scripts/grafana-portforward.sh

verify-infra:
	./scripts/verify-infra.sh

up:
	./scripts/up.sh

down:
	./scripts/down.sh

apps-up:
	./scripts/apps-up.sh

apps-down:
	./scripts/apps-down.sh

smoke:
	./scripts/smoke.sh

fastapi-build:
	./scripts/fastapi-build.sh

fastapi-up:
	./scripts/fastapi-up.sh

fastapi:
	./scripts/fastapi-portforward.sh

laravel-build:
	./scripts/laravel-build.sh

laravel-up:
	./scripts/laravel-up.sh

laravel:
	./scripts/laravel-portforward.sh

symfony-build:
	./scripts/symfony-build.sh

symfony-up:
	./scripts/symfony-up.sh

symfony:
	./scripts/symfony-portforward.sh

symfony-consumer-up:
	./scripts/symfony-consumer-up.sh
