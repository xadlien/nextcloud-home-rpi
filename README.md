# nextcloud-home

## Description
Repository to manage my home nextcloud setup.

## Usage
To bring this environment up you will need to first create the docker volumes. Then the main terraform will bring everything else online with ssl encryption.
```bash
cd volumes
terraform init
terraform apply
cd ..
terraform init
terraform apply
```  
I split the volumes from the rest of the terraform so that they won't be destroyed.

## SSL
The terraform will create self-signed certs for your application. 