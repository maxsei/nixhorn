{{- define "nixhorn-webhook.name" -}}
{{- default .Chart.Name .Values.nameOverride }}
{{- end }}

{{- define "nixhorn-webhook.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name }}
{{- end }}
{{- end }}
{{- end }}

{{- define "nixhorn-webhook.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}

{{- define "nixhorn-webhook.labels" -}}
helm.sh/chart: {{ include "nixhorn-webhook.chart" . }}
{{ include "nixhorn-webhook.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: admission-webhook
{{- end }}

{{- define "nixhorn-webhook.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nixhorn-webhook.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "nixhorn-webhook.tlsSecretName" -}}
{{- if eq .Values.webhook.tls.type "secret" }}
{{- .Values.webhook.tls.name }}
{{- else }}
{{- include "nixhorn-webhook.fullname" . }}-tls
{{- end }}
{{- end }}
