import * as cdk from "@aws-cdk/core";
import * as eks from "@aws-cdk/aws-eks";
import * as ec2 from "@aws-cdk/aws-ec2";
import * as iam from "@aws-cdk/aws-iam";
import * as ecrAssets from "@aws-cdk/aws-ecr-assets";
import { getKubernetesTemplates } from "./templates";
import { PolicyStatement } from "@aws-cdk/aws-iam";

class EKSClusterStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, "vpc", {
      maxAzs: 3,
    });

    const mastersRole = new iam.Role(this, "master-role", {
      assumedBy: new iam.AccountRootPrincipal(),
    });

    const cluster = new eks.Cluster(this, "cluster", {
      kubectlEnabled: true,
      defaultCapacityInstance: new ec2.InstanceType("m5.large"),
      defaultCapacity: 2,
      clusterName: "ekscluster",
      vpc,
      mastersRole,
    });

    cluster.defaultNodegroup?.role.addToPolicy(
      new PolicyStatement({
        effect: iam.Effect.ALLOW,
        resources: [
          "arn:aws:dynamodb:*:*:table/scorekeep-*",
          "arn:aws:sns:*:*:scorekeep-*",
        ],
        actions: ["*"],
      })
    );

    const backendRepository = new ecrAssets.DockerImageAsset(
      this,
      "java-app-repo",
      {
        repositoryName: "api",
        directory: "../app",
      }
    );

    let backendTemplate = getKubernetesTemplates(
      backendRepository, //repo
      "api", //resource name
      80, // host port
      5000, //container port
      2, //replica number
      2, // min replicas for hpa
      4, // max replicas for hpa
      70, // hpa cpu util. target
      [
        {
          name: "AWS_ACCOUNT_ID",
          value: process.env.AWS_ACCOUNT_ID,
        },
        { name: "AWS_REGION", value: process.env.AWS_REGION },
        {
          name: "NOTIFICATION_TOPIC",
          value: process.env.NOTIFICATION_TOPIC,
        },
        {
          name: "NOTIFICATION_EMAIL",
          value: process.env.NOTIFICATION_EMAIL,
        },
        {
          name: "USER_TABLE",
          value: process.env.USER_TABLE,
        },
        {
          name: "SESSION_TABLE",
          value: process.env.SESSION_TABLE,
        },
        {
          name: "GAME_TABLE",
          value: process.env.GAME_TABLE,
        },
        {
          name: "MOVE_TABLE",
          value: process.env.MOVE_TABLE,
        },
        {
          name: "STATE_TABLE",
          value: process.env.STATE_TABLE,
        },
      ]
    );

    const backendResource = new eks.KubernetesResource(this, "api", {
      cluster,
      manifest: backendTemplate,
    });

    const frontendRepository = new ecrAssets.DockerImageAsset(
      this,
      "frontend-repo",
      {
        repositoryName: "frontend",
        directory: "../frontend",
      }
    );
    const frontedResource = new eks.KubernetesResource(
      this,
      "frontend-resource",
      {
        cluster,
        manifest: getKubernetesTemplates(
          frontendRepository, //repo
          "frontend", //resource name
          80, // host port
          80, //container port
          2, //replica number
          2, // min replicas for hpa
          4, // max replicas for hpa
          70, // hpa cpu util. target
          []
        ),
      }
    );
  }
}
const app = new cdk.App();
const clusterStack = new EKSClusterStack(app, "EKSClusterStackDemo", {
  env: {
    region: process.env.AWS_REGION,
    account: process.env.AWS_ACCOUNT_ID,
  },
});
