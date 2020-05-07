import * as cdk from "@aws-cdk/core";
import * as ec2 from "@aws-cdk/aws-ec2";
import * as ecs from "@aws-cdk/aws-ecs";
import * as ecs_patterns from "@aws-cdk/aws-ecs-patterns";
import * as iam from "@aws-cdk/aws-iam";
import { PolicyStatement } from "@aws-cdk/aws-iam";

class EcsJavaAppStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, "vpc", { maxAzs: 2 });

    const cluster = new ecs.Cluster(this, "Cluster", { vpc });

    const fargateService = new ecs_patterns.ApplicationLoadBalancedFargateService(
      this,
      "FargateService",
      {
        cluster,
        taskImageOptions: {
          image: ecs.ContainerImage.fromAsset(`${__dirname}/../app`),
          containerPort: 5000,
          environment: {
            DEPLOYED_DATE: Date.now().toLocaleString(),
            AWS_REGION: process.env.AWS_REGION || "",
            NOTIFICATION_TOPIC: process.env.NOTIFICATION_TOPIC || "",
            NOTIFICATION_EMAIL: process.env.NOTIFICATION_EMAIL || "",
            USER_TABLE: process.env.USER_TABLE || "",
            SESSION_TABLE: process.env.SESSION_TABLE || "",
            GAME_TABLE: process.env.GAME_TABLE || "",
            MOVE_TABLE: process.env.MOVE_TABLE || "",
            STATE_TABLE: process.env.STATE_TABLE || "",
          },
        },
        desiredCount: 2,
      }
    );

    fargateService.taskDefinition.addContainer("frontend", {
      image: ecs.ContainerImage.fromAsset(
        `${__dirname}/../app/scorekeep-frontend`
      ),
      cpu: 64,
      memoryReservationMiB: 512,
    });

    fargateService.taskDefinition.executionRole?.addManagedPolicy(
      iam.ManagedPolicy.fromManagedPolicyArn(
        this,
        "ECRAccess",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      )
    );
    fargateService.taskDefinition.executionRole?.addManagedPolicy(
      iam.ManagedPolicy.fromManagedPolicyArn(
        this,
        "LogAccess",
        "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
      )
    );

    fargateService.taskDefinition.taskRole?.addManagedPolicy(
      iam.ManagedPolicy.fromManagedPolicyArn(
        this,
        "DynamoAccess",
        "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
      )
    );

    fargateService.taskDefinition.taskRole?.addManagedPolicy(
      iam.ManagedPolicy.fromManagedPolicyArn(
        this,
        "SnsAccess",
        "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
      )
    );

    new cdk.CfnOutput(this, "LoadBalancerDNS", {
      value: fargateService.loadBalancer.loadBalancerDnsName,
    });
  }
}

const app = new cdk.App();
new EcsJavaAppStack(app, "EcsJavaApp", {
  env: {
    account: process.env.AWS_ACCOUNT_ID,
    region: process.env.AWS_REGION,
  },
});
