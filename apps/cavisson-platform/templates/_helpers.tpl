{{/*
Expand the name of the chart.
*/}}
{{- define "cavisson-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cavisson-platform.fullname" -}}
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
{{- define "cavisson-platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cavisson-platform.labels" -}}
helm.sh/chart: {{ include "cavisson-platform.chart" . }}
{{ include "cavisson-platform.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
tenant-id: {{ .Values.tenantId | quote }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cavisson-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cavisson-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Controller labels
*/}}
{{- define "cavisson-platform.controllerLabels" -}}
{{ include "cavisson-platform.labels" . }}
app.kubernetes.io/component: controller
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cavisson-platform.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cavisson-platform.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
UI (Portal) hostname: ui.<tenantId>.<baseDomain>
*/}}
{{- define "cavisson-platform.uiHost" -}}
{{- printf "ui.%s.%s" .Values.tenantId .Values.baseDomain -}}
{{- end }}

{{/*
Data collection hostname: data.<tenantId>.<baseDomain>
*/}}
{{- define "cavisson-platform.dataHost" -}}
{{- printf "data.%s.%s" .Values.tenantId .Values.baseDomain -}}
{{- end }}

{{/*
TLS secret name for the UI Ingress.
Defaults to <tenantId>-ui-tls if not explicitly set.
*/}}
{{- define "cavisson-platform.uiTlsSecret" -}}
{{- if .Values.ingress.tls.uiSecretName -}}
{{- .Values.ingress.tls.uiSecretName -}}
{{- else -}}
{{- printf "%s-ui-tls" .Values.tenantId -}}
{{- end -}}
{{- end }}

{{/*
TLS secret name for the data Ingress.
Defaults to <tenantId>-data-tls if not explicitly set.
*/}}
{{- define "cavisson-platform.dataTlsSecret" -}}
{{- if .Values.ingress.tls.dataSecretName -}}
{{- .Values.ingress.tls.dataSecretName -}}
{{- else -}}
{{- printf "%s-data-tls" .Values.tenantId -}}
{{- end -}}
{{- end }}
