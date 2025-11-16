{{/*
Expand the name of the chart.
*/}}
{{- define "x-road-ssx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "x-road-ssx.fullname" -}}
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
{{- define "x-road-ssx.fullnameWithId" -}}
{{- $base := include "x-road-ssx.fullname" . -}}
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
{{- define "x-road-ssx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "x-road-ssx.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "x-road-ssx.chart" . }}
{{ include "x-road-ssx.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/name: {{ include "x-road-ssx.fullname" $ }}
app.kubernetes.io/component: security-server
{{- $sid := index .Values "security-server" "serverId" | default "" -}}
{{- if $sid }}
serverId: {{ $sid | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "x-road-ssx.selectorLabels" -}}
app.kubernetes.io/instance: {{ include "x-road-ssx.fullnameWithId" $ }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "x-road-ssx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "x-road-ssx.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the FQDN
*/}}
{{- define "x-road-ssx.fqdn" -}}
{{- $serverId := index .Values "security-server" "serverId" | default "" -}}
{{- $domain   := index .Values "security-server" "Ingress" "tldDomain" | default "" -}}
{{- if $serverId -}}
{{ printf "ss%s.%s" $serverId $domain }}
{{- else -}}
{{ printf "mss.%s" $domain }}
{{- end -}}
{{- end -}}

{{/*
Create the Ingress FQDN (separate from LoadBalancer FQDN)
*/}}
{{- define "x-road-ssx.ingressFqdn" -}}
{{- $domain   := index .Values "security-server" "Ingress" "tldDomain" | default "" -}}
{{ printf "mss.%s" $domain }}
{{- end -}}