IMAGE_NAME ?= task-tracker-api
IMAGE_TAG  ?= latest
REGISTRY   ?= ghcr.io/$(shell git config user.name | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

.PHONY: dev down build push test lint fmt clean

## Start local dev environment (Flask + PostgreSQL + pgAdmin)
dev:
	docker-compose up --build

## Stop and remove local dev containers and volumes
down:
	docker compose down -v

## Build the production Docker image
build:
	docker build --target runtime -t $(IMAGE_NAME):$(IMAGE_TAG) .

## Push image to registry (set REGISTRY env var)
push: build
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	docker push $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

## Run tests (requires running db or uses sqlite in-memory via conftest)
test:
	cd app && python3 -m pytest tests/ -v

## Lint Python source
lint:
	cd app && python -m flake8 . --max-line-length=120 --exclude=__pycache__,.pytest_cache

## Format check (flake8 style only — no auto-formatter to keep deps minimal)
fmt: lint

## Remove generated artifacts
clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.pyc" -delete 2>/dev/null || true
