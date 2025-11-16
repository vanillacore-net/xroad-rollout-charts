{{/*
Expand the name of the chart.
*/}}
{{- define "hurl-auto-config.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "hurl-auto-config.fullname" -}}
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
{{- define "hurl-auto-config.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "hurl-auto-config.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "hurl-auto-config.chart" . }}
{{ include "hurl-auto-config.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "hurl-auto-config.selectorLabels" -}}
app.kubernetes.io/instance: {{ include "hurl-auto-config.fullname" $ }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "hurl-auto-config.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "hurl-auto-config.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the FQDN
*/}}
{{- define "hurl-auto-config.fqdn" -}}
{{- $serverId := index .Values "security-server" "serverId" | default "" -}}
{{- $domain   := index .Values "security-server" "Ingress" "tldDomain" | default "" -}}
{{- if $serverId -}}
{{ printf "ss%s.%s" $serverId $domain }}
{{- else -}}
{{ printf "ss.%s" $domain }}
{{- end -}}
{{- end -}}