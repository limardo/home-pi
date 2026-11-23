{{- define "observability.yamlFile" -}}
{{- $content := required (printf "%s not found" .path) (.ctx.Files.Get .path) -}}
{{- $obj := fromYaml $content -}}
{{- if hasKey $obj "Error" }}
{{- fail (printf "%s is not valid YAML: %s" .path $obj.Error) }}
{{- end }}
{{- $content -}}
{{- end }}
