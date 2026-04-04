{{- define "registry.url" -}}
{{- if .Values.registry.url }}
{{- .Values.registry.url -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}
