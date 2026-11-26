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

{{- /* Keep in sync with addons.grafanaRules */}}
{{- define "datastores.alertRules" -}}
{{- $files := .ctx.Files.Glob "files/alerts/*.yaml" }}
{{- if $files }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .ctx.Chart.Name }}-alert-rules
  labels:
    {{- include "datastores.labels" .ctx | nindent 4 }}
    grafana_alert: "1"
data:
  {{- range $path, $_ := $files }}
  {{ $.ctx.Chart.Name }}-{{ base $path }}: |-
    {{- include "datastores.grafanaRules" (dict "content" ($.ctx.Files.Get $path) "folder" $.folder) | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "datastores.grafanaRules" -}}
apiVersion: 1
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
