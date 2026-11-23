{{- define "smarthome.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "smarthome.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "smarthome.selectorLabels" . }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
app.kubernetes.io/part-of: smarthome
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "smarthome.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "smarthome.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  ports:
    {{- range .Values.service }}
    - name: {{ .name }}
      port: {{ .port }}
      targetPort: {{ .name }}
      protocol: {{ .protocol }}
    {{- end }}
  selector:
    {{- include "smarthome.selectorLabels" . | nindent 4 }}
{{- end }}

{{- define "smarthome.httproute" -}}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ .Chart.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "smarthome.labels" . | nindent 4 }}
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
          port: {{ (first .Values.service).port }}
{{- end }}

{{- define "smarthome.pvc" -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .Chart.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "smarthome.labels" . | nindent 4 }}
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

{{- define "smarthome.probe" -}}
{{- with .Values.probe }}
apiVersion: monitoring.coreos.com/v1
kind: Probe
metadata:
  name: {{ $.Chart.Name }}
  namespace: {{ $.Release.Namespace }}
  labels:
    {{- include "smarthome.labels" $ | nindent 4 }}
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
