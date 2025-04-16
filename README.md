# opensearch-sudachi

## Creating a Sudachi User Dictionary

- https://github.com/WorksApplications/Sudachi/blob/develop/docs/user_dict.md

```sh
cd sudachi
make
```

## local

```sh
cd sudachi
docker build -t opensearch-sudachi:2.17.1 .
```

```sh
docker compose up -d
```

## aws

```sh
cd terraform
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```
