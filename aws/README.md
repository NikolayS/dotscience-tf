# dotscience-tf

## XXX This is a work in progress

## 1. deploy the stack

Make a copy of `input.tfvars.sample` and add in settings for the parameters below

```
admin_password   = "SECURE_PASSWORD"
hub_ingress_cidr = "0.0.0.0/0"
key_name         = "dotscience-hub-cf"
ssh_access_cidr  = "0.0.0.0/0"
stack_name       = "dotscience"
```   

Initialise Terraform:
```
terraform init
```

Deploy the stack:
```
terraform apply -var-file="testing.tfvars" -auto-approve
```

## 2. connect eks cluster as dotscience deployer

TODO: all of this should be automated... maybe by shelling out to `ds` command to add managed deployer.

Grab the login URL and open it in a browser:
```
terraform show |grep '"LoginURL" = "'
```

Log in (using `admin` and the password you set in step 1) and let's set up the EKS cluster.

Click "≡" and "Deployers".
Add new deployer, name it "EKS" or whatever.

Record the command in the deployer settings, which we'll call `<command>` below.

Identify the `kubeconfig` file terraform creates locally:

```
ls kubeconfig*
```

Prepare the following command:

```
KUBECONFIG=<kubeconfig> <command>
```

Before running it, make the following changes to `<command>`:
* add `&notls=true` at the end of the URL
* add quotes around the entire URL

The deployer should go green in the Dotscience web interface.

## tutorial

TODO: insert basic end-to-end data science tutorial here.

TODO: https://github.com/dotmesh-io/dotscience-aws/issues/55 and wire in grafana

TODO: Also set up routes to grafana
