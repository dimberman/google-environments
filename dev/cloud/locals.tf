locals {
  worker_node_size = "n1-standard-4"
  db_instance_size = "db-custom-4-15360"
  public_signups   = true
  max_worker_node_count = 5
  helm_values      = <<EOF
---
global:
  istio:
    enabled: true
  postgresqlEnabled: false
  # Base domain for all subdomains exposed through ingress
  baseDomain: dev.steven-google-development.com
  tlsSecret: astronomer-tls
  platformNodePool:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: "astronomer.io/multi-tenant"
              operator: In
              values:
              - "false"
    tolerations:
      - key: "platform"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
  veleroEnabled: true
nginx:
  replicas: 1
  resources:
    limits:
      cpu: 3
      memory: 2Gi
  requests:
    cpu: 100m
    memory: 1Gi
  loadBalancerIP: ${module.astronomer_cloud.load_balancer_ip == "" ? "~" : module.astronomer_cloud.load_balancer_ip}
  # For cloud, the load balancer should be public
  privateLoadBalancer: false
  perserveSourceIP: true
elasticsearch:
  client:
    replicas: 1
    resources:
      limits:
        cpu: 3
        memory: 4Gi
      requests:
        cpu: 100m
        memory: 1Gi
    podAnnotations:
      sidecar.istio.io/proxyCPU: 300m
  data:
    heapMemory: 1g
    resources:
      limits:
        cpu:     4
        memory:  6Gi
      requests:
        cpu:     100m
        memory:  2Gi
    replicas: 1
  master:
    replicas: 1
    resources:
      requests:
        cpu: "100m"
astronomer:
  images:
    commander:
      repository: astronomerinc/ap-commander
      tag: latest
      pullPolicy: Always
    registry:
      repository: astronomerinc/ap-registry
      tag: latest
      pullPolicy: Always
    houston:
      repository: astronomerinc/ap-houston-api
      tag: latest
      pullPolicy: Always
    astroUI:
      repository: astronomerinc/ap-astro-ui
      tag: latest
      pullPolicy: Always
    dbBootstrapper:
      repository: astronomerinc/ap-db-bootstrapper
      tag: latest
      pullPolicy: Always
    cliInstall:
      repository: astronomerinc/ap-cli-install
      tag: latest
      pullPolicy: Always
    prisma:
      repository: astronomerinc/ap-prisma
      tag: latest
      pullPolicy: Always
  houston:
    resources:
      requests:
        cpu: 500m
    expireDeployments:
      enabled: true
      dryRun: true
      canary: false
    cleanupDeployments:
      enabled: true
      dryRun: true
      canary: false
    upgradeDeployments:
      enabled: true
      enabled: true
      canary: false
    env:
      - name: ANALYTICS__ENABLED
        value: "true"
      - name: ANALYTICS__WRITE_KEY
        # not a secret
        value: "vNeuM2RjMa71fK1t2Bg7jac7UI7dVHT5"
      - name: AUTH__LOCAL__ENABLED
        value: "true"
      - name: STRIPE__ENABLED
        value: "false"
    config:
      publicSignups: ${local.public_signups}
      email:
        enabled: true
        smtpUrl: "${chomp(data.http.smtp_uri.body)}"
      deployments:
        maxExtraAu: 1000
        maxPodAu: 100
        sidecars:
          cpu: 400
          memory: 248
        components:
          - name: scheduler
            au:
              default: 10
              limit: 100
          - name: webserver
            au:
              default: 5
              limit: 100
          - name: statsd
            au:
              default: 2
              limit: 30
          - name: pgbouncer
            au:
              default: 2
              limit: 2
          - name: flower
            au:
              default: 2
              limit: 2
          - name: redis
            au:
              default: 2
              limit: 2
          - name: workers
            au:
              default: 10
              limit: 100
            extra:
              - name: terminationGracePeriodSeconds
                default: 600
                limit: 36000
              - name: replicas
                default: 1
                limit: 20
        namespaceLabels:
          istio-injection: enabled
        astroUnit:
          price: 10
        chart:
          version: 0.12.0-alpha.1
        images:
          - version: 1.10.7
            channel: stable
            tag: 1.10.7-alpine3.10-onbuild
          - version: 1.10.5
            channel: stable
            tag: 1.10.5-alpine3.10-onbuild
        helm:
          data:
            metadataConnection:
              sslmode: disable
            resultBackendConnection:
              sslmode: disable
          scheduler:
            airflowLocalSettings: |
              from airflow.contrib.kubernetes.pod import Pod
              from airflow.configuration import conf
              def pod_mutation_hook(pod: Pod):
                # This is the default airflow-chart pod mutation hook
                extra_labels = {
                    "kubernetes-executor": "False",
                    "kubernetes-pod-operator": "False"
                }
                if 'airflow-worker' in pod.labels.keys() or \
                        conf.get('core', 'EXECUTOR') == "KubernetesExecutor":
                    extra_labels["kubernetes-executor"] = "True"
                else:
                    extra_labels["kubernetes-pod-operator"] = "True"
                pod.labels.update(extra_labels)
                pod.tolerations += []
                pod.affinity.update({})
                # Ensure our entrypoint is respected
                if not pod.args:
                  pod.args = []
                pod.args = pod.cmds + pod.args
                pod.cmds = ["tini", "--", "/entrypoint"]
          pgbouncer:
            resultBackendPoolSize: 10
            resources:
              requests:
                cpu: 20m
                memory: 64Mi
              limits:
                cpu: 250m
                memory: 256Mi
          redis:
            resources:
              requests:
                cpu: 20m
                memory: 64Mi
              limits:
                cpu: 250m
                memory: 256Mi
          flower:
            resources:
              requests:
                cpu: 20m
                memory: 64Mi
              limits:
                cpu: 250m
                memory: 512Mi
          statsd:
            resources:
              requests:
                cpu: 20m
                memory: 64Mi
              limits:
                cpu: 1000m
                memory: 256Mi
          webserver:
            initialDelaySeconds: 15
            timeoutSeconds: 30
            failureThreshold: 60
            periodSeconds: 8
          workers:
            keda:
              enabled: true
            resources:
              limits:
                ephemeral-storage: "10Gi"
              requests:
                ephemeral-storage: "1Gi"
          quotas:
            requests.ephemeral-storage: "50Gi"
            limits.ephemeral-storage: "256Gi"
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: "astronomer.io/multi-tenant"
                    operator: In
                    values:
                    - "true"
          podMutation:
            tolerations:
              - key: "dynamic-pods"
                operator: "Equal"
                value: "true"
                effect: "NoSchedule"
            affinity:
              nodeAffinity:
                requiredDuringSchedulingIgnoredDuringExecution:
                  nodeSelectorTerms:
                    - matchExpressions:
                        - key: "astronomer.io/dynamic-pods"
                          operator: In
                          values:
                            - "true"
  registry:
    gcs:
      enabled: true
      bucket: "${module.astronomer_cloud.container_registry_bucket_name}"
kubed:
  # Configure resources
  resources:
    requests:
      cpu: "100m"
      memory: "512Mi"
    limits:
      cpu: "2"
      memory: "1024Mi"
prometheus:
  replicas: 1
  persistence:
    size: "20Gi"
  retention: "2d"
  # Configure resources
  resources:
    requests:
      cpu: "1"
      memory: "4Gi"
    limits:
      # this is the maximum possible value for n1-standard-16
      cpu: "4"
      # this is the maximum possible value for n1-standard-16
      memory: "16Gi"
fluentd:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: "astronomer.io/multi-tenant"
                operator: In
                values:
                  - "true"
  tolerations:
    - effect: NoSchedule
      key: dynamic-pods
      operator: Equal
      value: "true"
EOF

}
