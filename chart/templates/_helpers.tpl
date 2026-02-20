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
{{- if eq .Values.webhook.tls.type "secret" }}
{{- .Values.webhook.tls.name }}
{{- else }}
{{- include "nixhorn-webhook.fullname" . }}-tls
{{- end }}
{{- end }}

{{- define "nixhorn-webhook.genCerts" -}}
{{- $serviceName := include "nixhorn-webhook.fullname" . }}
{{- $namespace := .Release.Namespace }}
{{- $cn := printf "%s.%s.svc.cluster.local" $serviceName $namespace }}
{{- $altNames := list $serviceName (printf "%s.%s" $serviceName $namespace) (printf "%s.%s.svc" $serviceName $namespace) $cn }}
{{- $cert := genSelfSignedCert $cn nil $altNames 3650 }}
tls.crt: {{ $cert.Cert | b64enc }}
tls.key: {{ $cert.Key | b64enc }}
caBundle: {{ $cert.Cert | b64enc }}
{{- end }}
