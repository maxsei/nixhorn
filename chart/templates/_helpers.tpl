{{- define "nixhorn-webhook.name" -}}
{{- .Chart.Name }}
{{- end }}

{{- define "nixhorn-webhook.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name }}
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
{{- .Values.webhook.tls.name }}
{{- end }}

{{- define "nixhorn-webhook.tlsConfigMapName" -}}
{{- include "nixhorn-webhook.fullname" . }}-tls-insecure
{{- end }}
