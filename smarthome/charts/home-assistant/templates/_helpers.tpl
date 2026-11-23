{{- define "home-assistant.configKey" -}}
{{ trimPrefix "files/" . | replace "/" "__" }}
{{- end }}

{{- define "home-assistant.configDirs" -}}
{{- range list "integrations" "lovelace" "automations" "scripts" "scenes" }}
{{- if $.Files.Glob (printf "files/%s/**" .) }}
- {{ . }}
{{- end }}
{{- end }}
{{- end }}

{{- define "home-assistant.configItems" -}}
{{- $dir := printf "files/%s/" .dir -}}
{{- range $path, $_ := .ctx.Files.Glob (printf "%s**" $dir) }}
- key: {{ include "home-assistant.configKey" $path }}
  path: {{ trimPrefix $dir $path }}
{{- end }}
{{- end }}
