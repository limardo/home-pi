{{- define "addons.namespace" -}}
{{- .Values.namespace | default .Release.Namespace -}}
{{- end }}

{{- define "addons.labels" -}}
helm.sh/chart: {{ .ctx.Chart.Name }}-{{ .ctx.Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/component: {{ .ctx.Chart.Name }}
app.kubernetes.io/part-of: addons
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
{{- end }}

{{- define "addons.namespaceResource" -}}
apiVersion: v1
kind: Namespace
metadata:
  name: {{ include "addons.namespace" . }}
  labels:
    {{- include "addons.labels" (dict "ctx" . "name" (include "addons.namespace" .)) | nindent 4 }}
{{- end }}

{{- define "addons.k0sChart" -}}
{{- $chart := .chart -}}
{{- $name := required (printf "charts.%s.name is required" .key) $chart.name -}}
apiVersion: helm.k0sproject.io/v1beta1
kind: Chart
metadata:
  name: {{ $name }}
  namespace: kube-system
  labels:
    {{- include "addons.labels" (dict "ctx" .ctx "name" $name) | nindent 4 }}
spec:
  releaseName: {{ $name }}
  namespace: {{ include "addons.namespace" .ctx }}
  chartName: {{ required (printf "charts.%s.chart is required" .key) $chart.chart }}
  {{- with $chart.version }}
  version: {{ . | quote }}
  {{- end }}
  {{- if not (hasPrefix "oci://" $chart.chart) }}
  repository:
    url: {{ required (printf "charts.%s.repository is required" .key) $chart.repository }}
  {{- end }}
  {{- /* k0s defaults to true, and helm upgrade --force replaces bound PVCs */}}
  {{- if hasKey $chart "forceUpgrade" }}
  forceUpgrade: {{ $chart.forceUpgrade }}
  {{- end }}
  {{- with $chart.config }}
  values: |
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}

{{- define "addons.k0sCharts" -}}
{{- $overrides := .overrides | default dict }}
{{- range $key, $chart := .ctx.Values.charts }}
{{- if $chart.enabled }}
{{- with get $overrides $key }}
{{- $chart = deepCopy $chart }}
{{- $_ := set $chart "config" (mergeOverwrite ($chart.config | default dict) .) }}
{{- end }}
---
{{ include "addons.k0sChart" (dict "ctx" $.ctx "key" $key "chart" $chart) }}
{{- end }}
{{- end }}
{{- end }}

{{- define "addons.nfsStorageClasses" -}}
{{- range $key, $chart := .Values.charts }}
{{- if and $chart.enabled $chart.storageClass }}
{{- $sc := $chart.storageClass }}
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: {{ required (printf "charts.%s.storageClass.name is required" $key) $sc.name }}
  labels:
    {{- include "addons.labels" (dict "ctx" $ "name" $chart.name) | nindent 4 }}
provisioner: nfs.csi.k8s.io
parameters:
  server: {{ $.Values.global.nfs.server }}
  share: {{ $sc.share }}
reclaimPolicy: {{ $sc.reclaimPolicy }}
volumeBindingMode: Immediate
allowVolumeExpansion: true
mountOptions:
  {{- toYaml $sc.mountOptions | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{- define "addons.service" -}}
{{- range $name, $svc := .Values.services }}
{{- if $svc.enabled }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $name }}
  namespace: {{ include "addons.namespace" $ }}
  labels:
    {{- include "addons.labels" (dict "ctx" $ "name" $name) | nindent 4 }}
spec:
  type: ClusterIP
  ports:
    - name: {{ $svc.portName }}
      protocol: TCP
      port: {{ $svc.servicePort }}
      targetPort: {{ $svc.serverPort }}
{{- end }}
{{- end }}
{{- end }}

{{- define "addons.httproute" -}}
{{- range $name, $svc := .Values.services }}
{{- if $svc.enabled }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ $name }}-ingress
  namespace: {{ include "addons.namespace" $ }}
  labels:
    {{- include "addons.labels" (dict "ctx" $ "name" $name) | nindent 4 }}
spec:
  parentRefs:
    - name: {{ $.Values.global.gateway.name }}
      namespace: {{ $.Values.global.gateway.namespace }}
  hostnames:
    {{- range $svc.hostnames }}
    - {{ . | quote }}
    {{- end }}
  rules:
    - backendRefs:
        - name: {{ $name }}
          port: {{ $svc.servicePort }}
{{- end }}
{{- end }}
{{- end }}

{{- define "addons.probe" -}}
{{- range $name, $svc := .Values.services }}
{{- if and $svc.enabled $svc.probe }}
---
apiVersion: monitoring.coreos.com/v1
kind: Probe
metadata:
  name: {{ $name }}
  namespace: {{ include "addons.namespace" $ }}
  labels:
    {{- include "addons.labels" (dict "ctx" $ "name" $name) | nindent 4 }}
    release: prometheus
spec:
  interval: 60s
  module: {{ $svc.probe.module | default "http_2xx" }}
  prober:
    url: {{ $.Values.global.blackbox.prober }}
  targets:
    staticConfig:
      static:
        - {{ tpl $svc.probe.url $ }}
      labels:
        target: {{ $name }}
{{- end }}
{{- end }}
{{- end }}

{{- define "addons.alertRules" -}}
{{- $files := .ctx.Files.Glob "files/alerts/*.yaml" }}
{{- if $files }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .ctx.Chart.Name }}-alert-rules
  namespace: {{ include "addons.namespace" .ctx }}
  labels:
    {{- include "addons.labels" (dict "ctx" .ctx "name" (printf "%s-alert-rules" .ctx.Chart.Name)) | nindent 4 }}
    grafana_alert: "1"
data:
  {{- range $path, $_ := $files }}
  {{- $enabled := true }}
  {{- range $.ctx.Values.charts }}
  {{- if eq .name (base $path | trimSuffix ".yaml") }}{{ $enabled = .enabled }}{{ end }}
  {{- end }}
  {{ $.ctx.Chart.Name }}-{{ base $path }}: |-
    {{- include "addons.grafanaRules" (dict "content" ($.ctx.Files.Get $path) "folder" $.folder "enabled" $enabled) | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "addons.grafanaRules" -}}
apiVersion: 1
{{- /* Grafana keeps provisioned rules whose file is gone */}}
{{- if not .enabled }}
deleteRules:
{{- range (fromYaml .content).groups }}
{{- range .rules }}
  - orgId: 1
    uid: {{ .alert | kebabcase | trunc 40 | toJson }}
{{- end }}
{{- end }}
{{- else }}
groups:
{{- range (fromYaml .content).groups }}
  - orgId: 1
    name: {{ .name | toJson }}
    folder: {{ $.folder | toJson }}
    interval: {{ .interval | default "1m" }}
    rules:
    {{- range .rules }}
      - uid: {{ .alert | kebabcase | trunc 40 | toJson }}
        title: {{ .alert | toJson }}
        condition: C
        data:
          - refId: A
            datasourceUid: PBFA97CFB590B2093
            relativeTimeRange:
              from: 600
              to: 0
            model:
              refId: A
              expr: {{ .expr | toJson }}
              instant: true
          - refId: B
            datasourceUid: __expr__
            model:
              refId: B
              type: reduce
              expression: A
              reducer: last
          - refId: C
            datasourceUid: __expr__
            model:
              refId: C
              type: threshold
              expression: B
              {{- /* Fires on any series A returns: a missing metric needs absent() in expr */}}
              conditions:
                - evaluator:
                    type: gt
                    params:
                      - -1e+300
        noDataState: OK
        execErrState: Error
        for: {{ .for | default "0s" }}
        labels: {{ .labels | default dict | toJson }}
        {{- $annotations := dict }}
        {{- range $key, $text := .annotations }}
        {{- $_ := set $annotations $key (regexReplaceAll "\\$value\\b" $text "$$values.B.Value") }}
        {{- end }}
        annotations: {{ $annotations | toJson }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
