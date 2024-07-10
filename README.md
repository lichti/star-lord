# AWS VPC Security Group Temporary Access Management

This project provides a solution for managing temporary access to AWS VPC Security Groups. It leverages AWS Lambda, API Gateway, and AWS Cognito to securely allow and revoke IP addresses for a specified duration.

## How it work

User -> API Gateway (/allow_access) -> AWS Cognito (JWT) -> Lambda (allow_access)
   |                                                                |
   |                                                                V
   +------------------------------------------------------> AWS EC2 Security Group
                                                              |
   +------------------------------------------------------> AWS CloudWatch (logs)
                                                              |
   +------------------------------------------------------> AWS EventBridge (schedule IP removal)


## TODOs

- [] Validate JWT
- [] Support for external identity providers (Cognito configuration)
- [] Improve Cognito configuration
- [] Configure env var for protocol
- [] Add support for IPV6
- [] Add user in the Description field
- [] Improve IAM functions

## Key Features

- **Temporary IP Access**: Automatically adds and removes IP addresses from Security Groups based on a predefined timeout.
- **User Authentication**: Utilizes AWS Cognito for secure user authentication.
- **Event-Driven Automation**: Uses AWS EventBridge to schedule the removal of IP addresses.
- **Logging**: Logs all access and revocation events to AWS CloudWatch for monitoring and auditing purposes.
- **Infrastructure as Code**: Deploys all resources using Terraform for consistent and repeatable infrastructure management.

## Components

- `allow_access.py`: Lambda function to grant temporary access.
- `revoke_access.py`: Lambda function to revoke access after the specified duration.
- `main.tf`: Terraform script to set up all required AWS resources.
- `variables.tf`: Defines input variables for the Terraform script.
- `terraform.tfvars`: Specifies values for the input variables.
- `Makefile`: Automates packaging and deployment processes.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html)
- [AWS CLI](https://aws.amazon.com/cli/)
- Python 3.x and `pip`

## Setup

### 1. Configure AWS CLI

Make sure your AWS CLI is configured with the necessary permissions to create resources:

```sh
aws configure
```

### 2. Prepare Environment

Install required Terraform modules:

```sh
terraform init
```

### 3. Create Zip Files and Prepare to Deploy

Use the `Makefile` to package the Lambda functions and prepare the deploy the infrastructure:

```sh
make
```

### 4. Deploy

To separately plan and apply the Terraform configuration:

```sh
make deploy
```

### 5. Destroy Infrastructure

To destroy all Terraform-managed infrastructure:

```sh
make destroy
```

## Directory Structure

```
/path/to/project
├── allow_access.py
├── revoke_access.py
├── Makefile
├── main.tf
├── variables.tf
├── terraform.tfvars
└── .gitignore
```

## Notes

- Ensure you update `terraform.tfvars` with the appropriate values for your environment.
- This project uses `pip` to install dependencies directly into the deployment package directories. Modify the `Makefile` if additional dependencies are needed.
- The `.gitignore` file is set to ignore the generated zip files and deployment directories.

## License

This project is licensed under the MIT License.
```

This `README.md` provides an overview of the project, key features, setup instructions, and usage commands to help users understand and work with the project effectively.