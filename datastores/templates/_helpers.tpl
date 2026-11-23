{{- define "datastores.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "datastores.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "datastores.selectorLabels" . }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
app.kubernetes.io/part-of: datastores
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "datastores.probe" -}}
{{- with .Values.probe }}
apiVersion: monitoring.coreos.com/v1
kind: Probe
metadata:
  name: {{ $.Chart.Name }}
  labels:
    {{- include "datastores.labels" $ | nindent 4 }}
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
