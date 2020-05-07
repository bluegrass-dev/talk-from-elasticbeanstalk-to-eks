include aws.env
include account.env

.PHONY: setup build deploy clean build-app-beanstalk deploy-infra-beanstalk clean-infra-beanstalk build-app-ecs deploy-infra-ecs clean-infra-ecs build-app-eks deploy-infra-eks clean-infra-eks build-infra-eks-extra deploy-infra-eks-extra bootstrap-secrets

preflight: preflight-check-aws preflight-check-secrets preflight-check-cdk preflight-check-cdk8s preflight-check-kubectl

bootstrap: bootstrap-secrets bootstrap-infra-ecs bootstrap-infra-eks bootstrap-infra-eks-extra

setup:
	git clone --single-branch --branch master https://github.com/bluegrass-dev/eb-java-scorekeep.git beanstalk/app \
	&& git clone --single-branch --branch ecs https://github.com/bluegrass-dev/eb-java-scorekeep.git ecs/app \
	&& git clone --single-branch --branch ecs https://github.com/bluegrass-dev/eb-java-scorekeep.git eks/app \

build: build-app-beanstalk build-app-ecs build-app-eks build-infra-eks-extra
deploy: deploy-infra-beanstalk deploy-infra-ecs deploy-infra-eks
clean: clean-infra-beanstalk clean-infra-ecs clean-infra-eks

preflight-check-aws:
	which aws &>/dev/null && echo "aws in path" || echo "aws NOT FOUND in path. Install following: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html"

preflight-check-secrets:
	./scripts/test-secrets.sh

preflight-check-cdk:
	test cdk &>/dev/null && echo "cdk in path" || echo "cdk NOT FOUND in path. Install via 'npm install -g aws-cdk'"

preflight-check-cdk8s:
	test cdk8s &>/dev/null && echo "cdk8s in path" || echo "cdk8s NOT FOUND in path. Install via 'npm install -g cdk8s-cli'"

preflight-check-kubectl:
	test kubectl &>/dev/null && echo "kubectl in path" || echo "kubectl NOT FOUND in path. Install via 'brew install kubectl'"

bootstrap-secrets: preflight-check-secrets
	export AWS_REGION="$(AWS_REGION)" && ./scripts/set-secrets.sh || true

build-app-beanstalk:
	cd beanstalk/app && \
	./gradlew build

local-app-beanstalk:
	cd beanstalk/app && \
	export NOTIFICATION_TOPIC=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id notificationTopic --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export GAME_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id gameTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export MOVE_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id moveTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export SESSION_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id sessionTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export STATE_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id stateTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export USER_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id userTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	./gradlew bootrun

deploy-infra-beanstalk:
	aws cloudformation create-stack \
    --stack-name beanstalk-stacks-"$(STACK_SERIAL)" \
    --template-body file://./beanstalk/cloudformation.yaml \
    --region "$(AWS_REGION)" --disable-rollback --capabilities="CAPABILITY_IAM" \
    --parameters ParameterKey=ApplicationName,ParameterValue=scorekeep ParameterKey=StackSerial,ParameterValue="$(STACK_SERIAL)" ParameterKey=EmailAddress,ParameterValue="$(EMAIL_ADDRESS)" 

update-infra-beanstalk:
	aws cloudformation update-stack \
    --stack-name beanstalk-stacks-"$(STACK_SERIAL)" \
    --template-body file://./beanstalk/cloudformation.yaml \
    --region "$(AWS_REGION)" --capabilities="CAPABILITY_IAM" \
    --parameters ParameterKey=ApplicationName,ParameterValue=scorekeep ParameterKey=StackSerial,ParameterValue="$(STACK_SERIAL)" ParameterKey=EmailAddress,ParameterValue="$(EMAIL_ADDRESS)"

clean-infra-beanstalk:
	export ECR_REPO=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id ECRRepo --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export ARTIFACTS_BUCKET=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id CodePipelineArtifactStore --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	aws ecr delete-repository --repository-name "$$ECR_REPO" --force || true && \
	aws s3api delete-objects \
    --bucket "$$ARTIFACTS_BUCKET" \
    --delete "$$(aws s3api list-object-versions --bucket "$$ARTIFACTS_BUCKET" --output=json --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" || true && \
	aws s3 rb s3://"$$ARTIFACTS_BUCKET" --force || true && \
	aws cloudformation delete-stack \
    --stack-name beanstalk-stacks-"$(STACK_SERIAL)" 

build-app-ecs:
	cd ecs/app && \
	make build && \
	make package

bootstrap-infra-ecs:
	cd ecs/infra-cdk && \
	npm i && \
	cdk bootstrap

deploy-infra-ecs: build-app-ecs
	export NOTIFICATION_TOPIC=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id notificationTopic --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export GAME_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id gameTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export MOVE_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id moveTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export SESSION_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id sessionTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export STATE_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id stateTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export USER_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id userTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	cd ecs/infra-cdk && \
	cdk deploy

clean-infra-ecs:
	cd ecs/infra-cdk && \
	cdk destroy

build-app-eks:
	cd eks/app && \
	make build && \
	make package

bootstrap-infra-eks:
	cd eks/infra-cdk && \
	npm i && \
	cdk bootstrap 

deploy-infra-eks:
	export AWS_ACCOUNT_ID="$(AWS_ACCOUNT_ID)" && \
	export AWS_REGION="$(AWS_REGION)" && \
	export NOTIFICATION_EMAIL="$(EMAIL_ADDRESS)" && \
	export NOTIFICATION_TOPIC=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id notificationTopic --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export GAME_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id gameTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export MOVE_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id moveTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export SESSION_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id sessionTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export STATE_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id stateTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	export USER_TABLE=$$(aws cloudformation describe-stack-resource --stack-name beanstalk-stacks-"$(STACK_SERIAL)" --logical-resource-id userTable --query 'StackResourceDetail.PhysicalResourceId' --output text) && \
	cd eks/infra-cdk && \
	cdk deploy

clean-infra-eks:
	cd eks/infra-cdk && \
	cdk destroy

bootstrap-infra-eks-extra:
	cd eks/infra-cdk8s && \
	npm i 

build-infra-eks-extra:
	cd eks/infra-cdk8s && \
	npm run compile && cdk8s synth

deploy-infra-eks-extra: build-infra-eks-extra
	kubectl apply -f eks/infra-cdk8s/dist/infracdk8s.k8s.yaml