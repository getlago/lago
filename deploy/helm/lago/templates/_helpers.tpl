{{/* Common helpers for the Lago chart. */}}

{{- define "lago.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "lago.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "lago.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "lago.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "lago.labels" -}}
helm.sh/chart: {{ include "lago.chart" . }}
{{ include "lago.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "lago.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lago.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Pinned, fully-qualified image references. */}}
{{- define "lago.image.api" -}}
{{- printf "%s:%s" .Values.image.api.repository .Values.image.api.tag -}}
{{- end -}}

{{- define "lago.image.front" -}}
{{- printf "%s:%s" .Values.image.front.repository .Values.image.front.tag -}}
{{- end -}}

{{- define "lago.image.pdf" -}}
{{- printf "%s:%s" .Values.image.pdf.repository .Values.image.pdf.tag -}}
{{- end -}}
