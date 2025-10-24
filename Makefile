# Makefile for LinuxServer.io Universal Helm Chart

# Variables
CHART_NAME := linuxserver-universal
RELEASE_NAME := test-release
NAMESPACE := default

# Default target
.PHONY: help
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: setup
setup: ## Setup development environment
	@echo "Setting up development environment..."
	# helm repo add $(HELM_REPO) $(HELM_REPO_URL)
	# helm repo update
	pip install helm-unittest

.PHONY: lint
lint: ## Lint the Helm chart
	@echo "Linting Helm chart..."
	helm lint .

.PHONY: test
test: ## Run unit tests
	@echo "Running unit tests..."
	helm unittest tests/

.PHONY: template
template: ## Test template rendering
	@echo "Testing template rendering..."
	helm template $(RELEASE_NAME) . --debug

.PHONY: dry-run
dry-run: ## Dry run installation
	@echo "Dry run installation..."
	helm install --dry-run --debug $(RELEASE_NAME) .

.PHONY: install
install: ## Install the chart
	@echo "Installing chart..."
	helm install $(RELEASE_NAME) .

.PHONY: upgrade
upgrade: ## Upgrade the chart
	@echo "Upgrading chart..."
	helm upgrade $(RELEASE_NAME) .

.PHONY: uninstall
uninstall: ## Uninstall the chart
	@echo "Uninstalling chart..."
	helm uninstall $(RELEASE_NAME)

.PHONY: status
status: ## Show release status
	@echo "Release status:"
	helm status $(RELEASE_NAME)

.PHONY: test-examples
test-examples: ## Test with example values
	@echo "Testing with Plex example..."
	helm template $(RELEASE_NAME) . -f examples/plex.yaml --debug
	@echo "Testing with Radarr example..."
	helm template $(RELEASE_NAME) . -f examples/radarr.yaml --debug
	@echo "Testing with Sonarr example..."
	helm template $(RELEASE_NAME) . -f examples/sonarr.yaml --debug
	@echo "Testing with Tautulli example..."
	helm template $(RELEASE_NAME) . -f examples/tautulli.yaml --debug
	@echo "Testing with Deluge example..."
	helm template $(RELEASE_NAME) . -f examples/deluge.yaml --debug

.PHONY: ci
ci: lint test template ## Run CI pipeline locally
	@echo "CI pipeline completed successfully"

.PHONY: clean
clean: ## Clean up temporary files
	@echo "Cleaning up..."
	rm -rf charts/
	rm -f Chart.lock

.PHONY: package
package: ## Package the chart
	@echo "Packaging chart..."
	helm package .

.PHONY: all
all: setup lint test template ## Run all checks
	@echo "All checks completed successfully"
