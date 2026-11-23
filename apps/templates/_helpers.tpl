{{- define "apps.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "apps.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "apps.selectorLabels" . }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
app.kubernetes.io/part-of: apps
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "apps.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "apps.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  ports:
    - name: http
      port: {{ .Values.http.port }}
      targetPort: http
      protocol: TCP
  selector:
    {{- include "apps.selectorLabels" . | nindent 4 }}
{{- end }}

{{- define "apps.httproute" -}}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ .Chart.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "apps.labels" . | nindent 4 }}
spec:
  parentRefs:
    - name: {{ .Values.global.gateway.name }}
      namespace: {{ .Values.global.gateway.namespace }}
  hostnames:
    {{- range .Values.hostnames }}
    - {{ . | quote }}
    {{- end }}
  rules:
    - backendRefs:
        - name: {{ .Chart.Name }}
          port: {{ .Values.http.port }}
{{- end }}

{{- define "apps.pvc" -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .Chart.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "apps.labels" . | nindent 4 }}
  annotations:
    helm.sh/resource-policy: keep
spec:
  storageClassName: {{ .Values.storage.storageClass }}
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.storage.size }}
{{- end }}

{{- define "apps.probe" -}}
{{- with .Values.probe }}
apiVersion: monitoring.coreos.com/v1
kind: Probe
metadata:
  name: {{ $.Chart.Name }}
  namespace: {{ $.Release.Namespace }}
  labels:
    {{- include "apps.labels" $ | nindent 4 }}
    release: prometheus
spec:
  interval: 60s
  module: {{ .module | default "http_2xx" }}
  prober:
    url: {{ $.Values.global.blackbox.prober }}
  targets:
    staticConfig:
      static:
        - {{ tpl .url $ }}
      labels:
        target: {{ $.Chart.Name }}
{{- end }}
{{- end }}

{{- define "apps.servicemonitor" -}}
{{- with .Values.metrics }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ $.Chart.Name }}
  namespace: {{ $.Release.Namespace }}
  labels:
    {{- include "apps.labels" $ | nindent 4 }}
    release: prometheus
spec:
  selector:
    matchLabels:
      {{- include "apps.selectorLabels" $ | nindent 6 }}
  endpoints:
    - port: http
      path: {{ .path }}
      interval: 60s
{{- end }}
{{- end }}
