{{/*
Expand the name of the chart.
*/}}
{{- define "x-road-ss.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "x-road-ss.fullname" -}}
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
Generate a fullname that uses security-server.serverId if present, otherwise default fullname.
*/}}
{{- define "x-road-ss.fullnameWithId" -}}
{{- $base := include "x-road-ss.fullname" . -}}
{{- $sid := index .Values "security-server" "serverId" | default "" -}}
{{- if $sid -}}
{{ printf "%s-%s" $base $sid | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $base -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "x-road-ss.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "x-road-ss.labels" -}}
helm.sh/chart: {{ include "x-road-ss.chart" . }}
{{ include "x-road-ss.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/name: {{ include "x-road-ss.fullname" $ }}
app.kubernetes.io/component: security-server
{{- $sid := index .Values "security-server" "serverId" | default "" -}}
{{- if $sid }}
serverId: {{ $sid | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "x-road-ss.selectorLabels" -}}
app.kubernetes.io/instance: {{ include "x-road-ss.fullnameWithId" $ }}
{{- end }}

{{/*
Create the FQDN
*/}}
{{- define "x-road-ss.fqdn" -}}
{{- $serverId := index .Values "security-server" "serverId" | default "" -}}
{{- $domain   := .Values.tldDomain | default "bb.assembly.govstack.global" -}}
{{- if $serverId -}}
{{ printf "ss%s.%s" $serverId $domain }}
{{- else -}}
{{ printf "ss.%s" $domain }}
{{- end -}}
{{- end -}}

{{/*
Create the Ingress FQDN
*/}}
{{- define "x-road-ss.ingressFqdn" -}}
{{- $domain   := .Values.tldDomain | default "bb.assembly.govstack.global" -}}
{{ printf "ss-ui.%s" $domain }}
{{- end -}}

