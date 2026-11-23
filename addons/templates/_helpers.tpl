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
