## Infrastructure setup

### VPC

export AWS_PROFILE=community  
export AWS_DEFAULT_REGION=ap-southeast-1  
export ENVIRONMENT_NAME=chengdu

运行
```
./infrastructure/vpc/vpc.sh
```

### AppMesh
export MESH_NAME=color

运行
```
./infrastructure/appmesh/appmesh-mesh.sh
```  

### ECS Cluster

运行
```
./infrastructure/ecs/ecs-cluter.sh
``` 

### Namespace

export SERVICES_DOMAIN=rong.local

运行
```
./infrastructure/namespace/namespace.sh
```

## Service setup

### Service mesh

运行
```
./service/servicemesh/appmesh-colorapp.sh
```


### ECR Image
#### build and push gateway image

#### build and push color teller image


### ECS Service
export ENVOY_IMAGE=111345817488.dkr.ecr.us-west-2.amazonaws.com/aws-appmesh-envoy:v1.9.0.0-prod
export COLOR_GATEWAY_IMAGE=$(aws ecr describe-repositories --repository-names=gateway --query 'repositories[0].repositoryUri' --output text)
export COLOR_TELLER_IMAGE=$(aws ecr describe-repositories --repository-names=colorteller --query 'repositories[0].repositoryUri' --output text)

./service/ecs/fargate-colorapp.sh 

