# CodeDeploy Troubleshooting Environments
***


**Hello! This repository contains a terraform template which generates AWS CodeDeploy environments from scratch, as well as on the branches, some misconfigured scenarios so you can hands-on troubleshoot them in your own pace.**

***

## Requirements
  - AWS Account
  - Terraform Installed
  - EC2 Key Pair (eu-west-2 for now)
  - AWS CLI

  ***


  ## Steps

  - Creating the First working scenario:
    - Clone the repository
    - `terraform init`
    - `terraform apply`


  - Switching between troubleshooting scenarios:
    - `git checkout <branchname>`
    - `terraform apply`

   ***
