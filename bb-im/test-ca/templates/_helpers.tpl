{{/*
Expand the name of the chart.
*/}}
{{- define "x-road-test-ca.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "x-road-test-ca.fullname" -}}
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
fullname that appends central-server.serverId if present
*/}}
{{- define "x-road-test-ca.fullnameWithId" -}}
{{- $base := include "x-road-test-ca.fullname" . -}}
{{- $sid := index .Values "test-ca" "serverId" | default "" -}}
{{- if $sid -}}
{{- printf "%s-%s" $base $sid | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $base -}}
{{- end -}}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "x-road-test-ca.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "x-road-test-ca.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "x-road-test-ca.chart" . }}
{{ include "x-road-test-ca.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/name: {{ include "x-road-test-ca.fullname" $ }}
app.kubernetes.io/component: test-ca
{{- $sid := index .Values "test-ca" "serverId" | default "" -}}
{{- if $sid }}
serverId: {{ $sid | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "x-road-test-ca.selectorLabels" -}}
app.kubernetes.io/instance: {{ include "x-road-test-ca.fullnameWithId" $ }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "x-road-test-ca.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "x-road-test-ca.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the FQDN
*/}}
{{- define "x-road-test-ca.fqdn" -}}
{{- $serverId := index .Values "test-ca" "serverId" | default "" -}}
{{- $domain   := index .Values "test-ca" "Ingress" "tldDomain" | default "" -}}
{{- if $serverId -}}
{{ printf "cs%s.%s" $serverId $domain }}
{{- else -}}
{{ printf "cs.%s" $domain }}
{{- end -}}
{{- end -}}
