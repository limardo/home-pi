{{- define "security.kyverno-policies.excludeNamespaces" -}}
{{- $ns := list -}}
{{- range .Values.charts.kyverno.policies.excludedNamespaces -}}
{{- $ns = append $ns (printf "%q" .) -}}
{{- end -}}
!(request.namespace in [{{ join ", " $ns }}])
{{- end }}

{{- define "security.kyverno-policies.hasResources" -}}
has(c.resources) &&
has(c.resources.requests) && has(c.resources.limits) &&
has(c.resources.requests.cpu) && has(c.resources.requests.memory) &&
has(c.resources.limits.cpu) && has(c.resources.limits.memory)
{{- end }}
