locals {
  worker_node_size      = "n1-standard-16"
  db_instance_size      = "db-custom-4-15360"
  public_signups        = false
  max_worker_node_count = 12
  helm_values           = <<EOF
---
global:
  # Base domain for all subdomains exposed through ingress
  baseDomain: staging.astronomer.io
  tlsSecret: astronomer-tls
  istioEnabled: true
  # the platform components go in the non-multi tenant
  # node pool, regardless of if we are using gvisor or not
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
  replicas: 3
  resources:
    limits:
      cpu: 3
      memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
  loadBalancerIP: ${module.astronomer_cloud.load_balancer_ip == "" ? "~" : module.astronomer_cloud.load_balancer_ip}
  # For cloud, the load balancer should be public
  privateLoadBalancer: false
  perserveSourceIP: true
elasticsearch:
  client:
    replicas: 4
    resources:
      limits:
        cpu: 3
        memory: 4Gi
      requests:
        cpu: 1
        memory: 2Gi
    podAnnotations:
      sidecar.istio.io/proxyCPU: 1000m
  data:
    heapMemory: 2g
    resources:
      limits:
        cpu:     4
        memory:  6Gi
      requests:
        cpu:     100m
        memory:  2Gi
    replicas: 8
astronomer:
  orbit:
    env:
      - name: ANALYTICS_TRACKING_ID
        value: "tH2XzkxCDpdC8Jvn8YroJ"
      - name: STRIPE_PK
        value: "${data.http.stripe_pk.body}"
  houston:
    expireDeployments:
      enabled: true
      dryRun: true
      canary: false
    cleanupDeployments:
      dryRun: true
      canary: false
    upgradeDeployments:
      enabled: true
      canary: false
    env:
      - name: ANALYTICS__ENABLED
        value: "true"
      - name: ANALYTICS__WRITE_KEY
        # not a secret
        value: "d8f1dqq4uXo24anKBADSn8MFqgTq32Rx"
      - name: AUTH__LOCAL__ENABLED
        value: "true"
      - name: STRIPE__SECRET_KEY
        value: "${data.http.stripe_secret_key.body}"
      - name: STRIPE__ENABLED
        value: "true"
    config:
      publicSignups: true
      email:
        enabled: true
        smtpUrl: "${data.http.smtp_uri.body}"
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
          version: 0.11.1
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
              enabled: false
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
alertmanager:
  receivers:
    platform:
      slack_configs:
      - channel: "${var.slack_alert_channel}"
        api_url: "${data.http.slack_alert_url.body}"
        title: "{{ .CommonAnnotations.summary }}"
        text: |-
          {{ range .Alerts }}
            *Alert:* {{ .Annotations.summary }}
            *Description:* {{ .Annotations.description }}
            *Details:*
            {{ range .Labels.SortedPairs }} • *{{ .Name }}:* `{{ .Value }}`
            {{ end }}
          {{ end }}
      - channel: "${var.slack_alert_channel_platform}"
        api_url: "${data.http.slack_alert_url_platform.body}"
        title: "{{ .CommonAnnotations.summary }}"
        text: |-
          {{ range .Alerts }}
            *Alert:* {{ .Annotations.summary }}
            *Description:* {{ .Annotations.description }}
            *Details:*
            {{ range .Labels.SortedPairs }} • *{{ .Name }}:* `{{ .Value }}`
            {{ end }}
          {{ end }}
      pagerduty_configs:
      - routing_key: "${data.http.pagerduty_service_key.body}"
        description: "{{ .CommonAnnotations.summary }}"
    airflow:
      webhook_configs:
      - url: "http://astronomer-houston:8871/v1/alerts"
        send_resolved: true
      slack_configs:
      - channel: "${var.slack_alert_channel}"
        api_url: "${data.http.slack_alert_url.body}"
        title: "{{ .CommonAnnotations.summary }}"
        text: |-
          {{ range .Alerts }}
            *Alert:* {{ .Annotations.summary }}
            *Description:* {{ .Annotations.description }}
            *Details:*
            {{ range .Labels.SortedPairs }} • *{{ .Name }}:* `{{ .Value }}`
            {{ end }}
          {{ end }}
kubed:
  # Configure resources
  resources:
    requests:
      cpu: "250m"
      memory: "512Mi"
    limits:
      cpu: "2"
      memory: "1024Mi"
prometheus:
  replicas: 2
  persistence:
    size: "600Gi"
  # We bill ~30d, so let's retain all metrics for
  # 30d plus a grace period of 5 days
  # This will require more memory for some queries,
  # so we will up the resource limits as well.
  retention: "35d"
  ingressNetworkPolicyExtraSelectors:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          release: celestial-wormhole-4369
          tier: airflow
  # Configure resources
  resources:
    requests:
      cpu: "1000m"
      memory: "32Gi"
    limits:
      # this is the maximum possible value for n1-standard-16
      cpu: "15000m"
      # this is the maximum possible value for n1-standard-16
      memory: "57Gi"
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
