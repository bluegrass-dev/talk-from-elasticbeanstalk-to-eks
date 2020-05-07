export function getKubernetesTemplates(
  repo: any,
  name: string,
  hostPort: number,
  containerPort: number,
  replicaNumber: number,
  minReplicas: number,
  maxReplicas: number,
  targetCPUUtilizationPercentage: number,
  env: any
) {
  return [
    {
      apiVersion: "v1",
      kind: "Service",
      metadata: { name },
      spec: {
        type: "LoadBalancer",
        ports: [{ port: hostPort, targetPort: containerPort }],
        selector: { app: name },
      },
    },
    {
      apiVersion: "apps/v1",
      kind: "Deployment",
      metadata: { name },
      spec: {
        replicas: replicaNumber,
        selector: { matchLabels: { app: name } },
        template: {
          metadata: {
            labels: { app: name },
          },
          spec: {
            containers: [
              {
                name: name,
                image: repo.imageUri,
                ports: [{ containerPort }],
                env: env,
              },
            ],
          },
        },
      },
    },
  ];
}
