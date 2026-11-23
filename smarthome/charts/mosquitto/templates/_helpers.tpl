{{- define "mosquitto.passwords" -}}
{{- if not (hasKey .Values "_passwords") -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace (printf "%s-users" .Chart.Name) -}}
{{- $passwords := dict -}}
{{- range .Values.users -}}
{{- $_ := set $passwords . (dig "data" . (randAlphaNum 32 | b64enc) $secret) -}}
{{- end -}}
{{- $_ := set .Values "_passwords" $passwords -}}
{{- end -}}
{{- toYaml .Values._passwords -}}
{{- end }}
