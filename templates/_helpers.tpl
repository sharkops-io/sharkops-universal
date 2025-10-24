{{/*
Expand the name of the chart.
*/}}
{{- define "common.names.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "common.names.fullname" -}}
{{- $fullnameOverride := "" -}}
{{- if hasKey .Values "fullnameOverride" -}}
{{- $fullnameOverride = .Values.fullnameOverride -}}
{{- end -}}
{{- if $fullnameOverride }}
{{- $fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name (default "" .Values.nameOverride) }}
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
{{- define "common.labels.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "common.labels.standard" -}}
helm.sh/chart: {{ include "common.labels.chart" . }}
{{ include "common.labels.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "common.labels.selectorLabels" -}}
app.kubernetes.io/name: {{ include "common.names.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "common.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create a short app name based on the image repository
*/}}
{{- define "common.names.appName" -}}
{{- if .Values.image.repository }}
{{- $repo := .Values.image.repository }}
{{- $repo = $repo | replace "nginxinc/" "" }}
{{- $repo = $repo | replace "linuxserver/" "" }}
{{- $repo = $repo | replace "plexinc/" "" }}
{{- $repo = $repo | replace "ghcr.io/" "" }}
{{- $repo = $repo | replace "docker.io/" "" }}
{{- $repo = $repo | replace "quay.io/" "" }}
{{- $repo = $repo | replace "registry.gitlab.com/" "" }}
{{- $repo = $repo | replace ":latest" "" }}
{{- $repo = $repo | replace ":alpine" "" }}
{{- $repo = $repo | replace ":stable" "" }}
{{- $repo | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- "app" }}
{{- end }}
{{- end }}

{{/*
Create a short deployment name based on the image repository
*/}}
{{- define "common.names.deploymentName" -}}
{{- if .Values.image.repository }}
{{- $appName := include "common.names.appName" . }}
{{- printf "%s-%s" .Release.Name $appName | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- include "common.names.fullname" . }}
{{- end }}
{{- end }}
