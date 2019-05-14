# Zookeeper AWS Module

This repo contains a module for deploying an Exhibitor managed Zookeeper Ensemble on AWS using Terraform.

### How to use this Module

Each Module has the following folder structure:

* root: This folder shows an example of Terraform code that uses the zookeeper-ensemble module to deploy a Zookeeper Ensemble in AWS.
* modules: This folder contains the reusable code for this Module, broken down into one or more modules.
* examples: This folder contains examples of how to use the modules.
* test: Automated tests for the modules and examples.

To deploy a Zookeeper Ensemble using this Module:

1. Create a Zookeeper AMI using a Packer template that installs zookeeper and exhibitor.
2. Deploy the AMI across an Auto Scaling Group using the Terraform zookeeper-ensemble module and execute the user-data-exhibitor script during boot on each Instance in the Auto Scaling Group to form the Zookeeper Ensemble.

