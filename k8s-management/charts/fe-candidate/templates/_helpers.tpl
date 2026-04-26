{{/*
Expand the name of the chart.
*/}}
{{- define "fe-candidate.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "fe-candidate.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "fe-candidate.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fe-candidate.labels" -}}
helm.sh/chart: {{ include "fe-candidate.chart" . }}
{{ include "fe-candidate.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ include "fe-candidate.ztaLabels" . }}
{{- end }}

{{/*
ZTA workload labels (PR #9 — doc/19-label-schema.md)
*/}}
{{- define "fe-candidate.ztaLabels" -}}
{{- with .Values.zta }}
zta.job7189/role: {{ .role | default "ui" | quote }}
zta.job7189/tier: {{ .tier | default "T3" | quote }}
zta.job7189/env: {{ .env | default "prod" | quote }}
zta.job7189/data-classification: {{ .dataClassification | default "public" | quote }}
zta.job7189/exposure: {{ .exposure | default "internal" | quote }}
zta.job7189/team: {{ .team | default "frontend" | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "fe-candidate.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fe-candidate.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "fe-candidate.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "fe-candidate.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
