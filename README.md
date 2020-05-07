# talk-from-elasticbeanstalk-to-eks

Post: <https://www.bluegrass.dev/talks/from-aws-elastic-beanstalk-to-eks>

## Steps

### setup

First, putting in place some helpful information used in the various AWS CloudFormation Stacks / CLI calls made.

```bash
touch account.env
echo AWS_ACCOUNT_ID=YOUR_AWS_ACCOUNT_ID >> account.env
echo EMAIL_ADDRESS=YOUR_EMAIL_ADDRESS >> account.env
```

Then, to ensure we have all the system requirements and the project setup!

```bash
# checks to ensure you have everything required
make preflight
# Then, resolve any errors based on the outputs then re-run until no errors remain

# If no errors, proceed
make bootstrap
```

### beanstalk via cloudformation

```bash
make deploy-infra-beanstalk
```

### ecs via cdk

```bash
make deploy-infra-ecs
```

### eks via cdk

```bash
make deploy-infra-eks
```

### eks - with some cdk8s

```bash
make deploy-infra-eks-extra
```

## Cleanup

```bash
make cleanup
```

## Inspiration

- <https://github.com/aws-samples/eb-java-scorekeep>
  - A sample application to take throught this theorhetical exercise
- <https://github.com/TysonWorks/cdk-examples>
  - ECS Cluster example
  - EKS Cluster example
- <https://github.com/aws-samples/eks-workshop>

## Resources

- <https://docs.aws.amazon.com/cdk/latest/guide/home.html>
- <https://github.com/aws/aws-cdk>
- <https://github.com/awslabs/cdk8s>
