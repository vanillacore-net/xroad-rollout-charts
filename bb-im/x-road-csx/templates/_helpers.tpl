{{/*
Expand the name of the chart.
*/}}
{{- define "x-road-csx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "x-road-csx.fullname" -}}
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
{{- define "x-road-csx.fullnameWithId" -}}
{{- $base := include "x-road-csx.fullname" . -}}
{{- $sid := index .Values "central-server" "serverId" | default "" -}}
{{- if $sid -}}
{{- printf "%s-%s" $base $sid | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $base -}}
{{- end -}}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "x-road-csx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "x-road-csx.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "x-road-csx.chart" . }}
{{ include "x-road-csx.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/name: {{ include "x-road-csx.fullname" $ }}
app.kubernetes.io/component: central-server
{{- $sid := index .Values "central-server" "serverId" | default "" -}}
{{- if $sid }}
serverId: {{ $sid | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "x-road-csx.selectorLabels" -}}
app.kubernetes.io/instance: {{ include "x-road-csx.fullnameWithId" $ }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "x-road-csx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "x-road-csx.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the FQDN
*/}}
{{- define "x-road-csx.fqdn" -}}
{{- $serverId := index .Values "central-server" "serverId" | default "" -}}
{{- $domain   := index .Values "central-server" "Ingress" "tldDomain" | default "" -}}
{{- if $serverId -}}
{{ printf "cs%s.%s" $serverId $domain }}
{{- else -}}
{{ printf "cs.%s" $domain }}
{{- end -}}
{{- end -}}

{{/*
Create the Ingress FQDN (separate from LoadBalancer FQDN)
*/}}
{{- define "x-road-csx.ingressFqdn" -}}
{{- $domain   := index .Values "central-server" "Ingress" "tldDomain" | default "" -}}
{{ printf "cs.%s" $domain }}
{{- end -}}
