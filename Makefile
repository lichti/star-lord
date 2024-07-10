# Define variables
ALLOW_ACCESS_DIR = allow_access
REVOKE_ACCESS_DIR = revoke_access
ALLOW_ACCESS_ZIP = allow_access.zip
REVOKE_ACCESS_ZIP = revoke_access.zip
TERRAFORM = terraform
TFPLAN = tfplan
PIP = pip3.9

# Default target
all: clean package prepare

# Clean up previous zip files and directories
clean:
	rm -f $(ALLOW_ACCESS_ZIP) $(REVOKE_ACCESS_ZIP) $(OAUTH_CALLBACK_ZIP)
	rm -rf $(ALLOW_ACCESS_DIR) $(REVOKE_ACCESS_DIR) $(OAUTH_CALLBACK_DIR)

# Create directories and install dependencies
prepare_dirs:
	mkdir -p $(ALLOW_ACCESS_DIR) $(REVOKE_ACCESS_DIR)
	$(PIP) install --platform manylinux2014_x86_64 --implementation cp --only-binary=:all: --upgrade --target=build/package -r requirements.txt -t $(ALLOW_ACCESS_DIR)
	$(PIP) install --platform manylinux2014_x86_64 --implementation cp --only-binary=:all: --upgrade --target=build/package -r requirements.txt -t $(REVOKE_ACCESS_DIR)

# Package Lambda functions into zip files
package: prepare_dirs $(ALLOW_ACCESS_ZIP) $(REVOKE_ACCESS_ZIP)

$(ALLOW_ACCESS_ZIP):
	cp allow_access.py $(ALLOW_ACCESS_DIR)
	cd $(ALLOW_ACCESS_DIR) && zip -r ../$(ALLOW_ACCESS_ZIP) .

$(REVOKE_ACCESS_ZIP):
	cp revoke_access.py $(REVOKE_ACCESS_DIR)
	cd $(REVOKE_ACCESS_DIR) && zip -r ../$(REVOKE_ACCESS_ZIP) .

# Init Terraform
init: 
	$(TERRAFORM) init

# Prepare Terraform plan
prepare: init package
	$(TERRAFORM) plan -out=$(TFPLAN)

# Deploy the plan
deploy:
	@if [ -f $(TFPLAN) ]; then \
		$(TERRAFORM) apply $(TFPLAN); \
	else \
		echo "Error: tfplan file does not exist. Run 'make prepare' first."; \
		exit 1; \
	fi

# Destroy Terraform-managed infrastructure and clean up directories
destroy:
	$(TERRAFORM) destroy -auto-approve
	rm -rf $(ALLOW_ACCESS_DIR) $(REVOKE_ACCESS_DIR) $(OAUTH_CALLBACK_DIR)

