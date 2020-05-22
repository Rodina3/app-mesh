#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

if [ -z "${ENVOY_IMAGE}" ]; then
    echo "ENVOY_IMAGE environment is not defined"
    exit 1
fi

if [ -z "${COLOR_GATEWAY_IMAGE}" ]; then
    echo "COLOR_GATEWAY_IMAGE environment is not defined"
    exit 1
fi

if [ -z "${COLOR_TELLER_IMAGE}" ]; then
    echo "COLOR_TELLER_IMAGE environment is not defined"
    exit 1
fi

stack_output=$(aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    cloudformation describe-stacks --stack-name "${ENVIRONMENT_NAME}-ecs-cluster" \
    | jq '.Stacks[].Outputs[]')

task_role_arn=($(echo $stack_output \
    | jq -r 'select(.OutputKey == "TaskIamRoleArn") | .OutputValue'))

execution_role_arn=($(echo $stack_output \
    | jq -r 'select(.OutputKey == "TaskExecutionIamRoleArn") | .OutputValue'))

# functions
generate_sidecars() {
    app_name=$1
    generate_envoy_container_json ${app_name}
}

generate_envoy_container_json() {
    app_name=$1
    envoy_container_json=$(jq -n \
    --arg ENVOY_IMAGE $ENVOY_IMAGE \
    --arg VIRTUAL_NODE "mesh/$MESH_NAME/virtualNode/${app_name}-vn" \
    --arg APPMESH_XDS_ENDPOINT "${APPMESH_XDS_ENDPOINT}" \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    -f "${DIR}/envoy-container.json")
}

generate_color_teller_task_def() {
    color=$1
    task_def_json=$(jq -n \
    --arg NAME "$ENVIRONMENT_NAME-ColorTeller-${color}" \
    --arg STAGE "$APPMESH_STAGE" \
    --arg COLOR "${color}" \
    --arg APP_IMAGE $COLOR_TELLER_IMAGE \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg TASK_ROLE_ARN $task_role_arn \
    --arg EXECUTION_ROLE_ARN $execution_role_arn \
    --argjson ENVOY_CONTAINER_JSON "${envoy_container_json}" \
    -f "${DIR}/colorteller-task-definition.json")

    task_def=$(aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    ecs register-task-definition \
    --cli-input-json "$task_def_json")
}

# Color Gateway Task Definition
generate_sidecars "colorgateway"
task_def_json=$(jq -n \
    --arg NAME "$ENVIRONMENT_NAME-ColorGateway" \
    --arg STAGE "$APPMESH_STAGE" \
    --arg COLOR_TELLER_ENDPOINT "colorteller.$SERVICES_DOMAIN:9080" \
    --arg APP_IMAGE $COLOR_GATEWAY_IMAGE \
    --arg AWS_REGION $AWS_DEFAULT_REGION \
    --arg TASK_ROLE_ARN $task_role_arn \
    --arg EXECUTION_ROLE_ARN $execution_role_arn \
    --argjson ENVOY_CONTAINER_JSON "${envoy_container_json}" \
    -f "${DIR}/gateway-task-definition.json")

task_def=$(aws --profile "${AWS_PROFILE}" --region "${AWS_DEFAULT_REGION}" \
    ecs register-task-definition \
    --cli-input-json "$task_def_json")

colorgateway_task_def_arn=($(echo $task_def \
    | jq -r '.taskDefinition | .taskDefinitionArn'))


# Color Teller White Task Definition
generate_sidecars "colorteller-white"
generate_color_teller_task_def "white"
colorteller_white_task_def_arn=($(echo $task_def \
    | jq -r '.taskDefinition | .taskDefinitionArn'))

# Color Teller Blue Task Definition
generate_sidecars "colorteller-blue"
generate_color_teller_task_def "blue"
colorteller_blue_task_def_arn=($(echo $task_def \
    | jq -r '.taskDefinition | .taskDefinitionArn'))

