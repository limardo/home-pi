{{- define "apps.servarr.env" -}}
{{- $prefix := .Chart.Name | upper -}}
- name: PUID
  value: "1000"
- name: PGID
  value: "1000"
- name: TZ
  value: Europe/Rome
- name: {{ $prefix }}__SERVER__PORT
  value: {{ .Values.http.port | quote }}
- name: {{ $prefix }}__AUTH__APIKEY
  valueFrom:
    secretKeyRef:
      name: {{ .Chart.Name }}-apikey
      key: token
- name: {{ $prefix }}__POSTGRES__HOST
  value: {{ .Values.global.postgresql.host }}
- name: {{ $prefix }}__POSTGRES__PORT
  value: "5432"
- name: {{ $prefix }}__POSTGRES__USER
  value: {{ .Chart.Name }}
- name: {{ $prefix }}__POSTGRES__PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Chart.Name }}-database
      key: password
{{- range .Values.databases }}
- name: {{ $prefix }}__POSTGRES__{{ . | upper }}DB
  value: {{ $.Chart.Name }}-{{ . }}
{{- end }}
{{- end }}

{{/* The *arr answer 400 "Invalid Hostname" to an IP Host header, as kubelet probes send */}}
{{- define "apps.servarr.ping" -}}
path: /ping
port: http
httpHeaders:
  - name: Host
    value: localhost
{{- end }}

{{- define "apps.servarr.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "apps.labels" . | nindent 4 }}
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      {{- include "apps.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "apps.labels" . | nindent 8 }}
      annotations:
        checksum/secrets: {{ include "apps.servarr.secretValues" . | sha256sum }}
    spec:
      automountServiceAccountToken: false
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          env:
            {{- include "apps.servarr.env" . | nindent 12 }}
          ports:
            - name: http
              containerPort: {{ .Values.http.port }}
              protocol: TCP
          startupProbe:
            httpGet:
              {{- include "apps.servarr.ping" . | nindent 14 }}
            periodSeconds: 10
            failureThreshold: 30
          livenessProbe:
            httpGet:
              {{- include "apps.servarr.ping" . | nindent 14 }}
            periodSeconds: 20
          readinessProbe:
            httpGet:
              {{- include "apps.servarr.ping" . | nindent 14 }}
            periodSeconds: 20
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          volumeMounts:
            {{- range $name, $nfs := .Values.nfs }}
            - name: {{ $name }}
              mountPath: {{ $nfs.mountPath }}
            {{- end }}
      volumes:
        {{- range $name, $nfs := .Values.nfs }}
        - name: {{ $name }}
          nfs:
            server: {{ $.Values.global.nfs.server }}
            path: {{ $nfs.path }}
        {{- end }}
{{- end }}

{{- define "apps.servarr.secretValues" -}}
{{- if not (hasKey .Values "_secretValues") -}}
{{- $apikey := lookup "v1" "Secret" .Release.Namespace (printf "%s-apikey" .Chart.Name) -}}
{{- $database := lookup "v1" "Secret" .Values.global.postgresql.namespace (printf "%s-database" .Chart.Name) -}}
{{- $_ := set .Values "_secretValues" (dict
  "apikey" (dig "data" "token" (randAlphaNum 32 | b64enc) $apikey)
  "password" (dig "data" "password" (randAlphaNum 32 | b64enc) $database)) -}}
{{- end -}}
{{- toYaml .Values._secretValues -}}
{{- end }}

{{- define "apps.servarr.apikey" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Chart.Name }}-apikey
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "apps.labels" . | nindent 4 }}
type: Opaque
data:
  token: {{ (include "apps.servarr.secretValues" . | fromYaml).apikey }}
{{- end }}

{{- define "apps.servarr.database" -}}
{{- $pg := .Values.global.postgresql -}}
{{- $name := .Chart.Name -}}
{{- $password := (include "apps.servarr.secretValues" . | fromYaml).password -}}
{{- range list $pg.namespace .Release.Namespace }}
---
apiVersion: v1
kind: Secret
metadata:
  name: {{ $name }}-database
  namespace: {{ . }}
  labels:
    {{- include "apps.labels" $ | nindent 4 }}
type: kubernetes.io/basic-auth
data:
  username: {{ $name | b64enc }}
  password: {{ $password }}
{{- end }}
---
apiVersion: postgresql.cnpg.io/v1
kind: DatabaseRole
metadata:
  name: {{ $name }}
  namespace: {{ $pg.namespace }}
  labels:
    {{- include "apps.labels" . | nindent 4 }}
spec:
  cluster:
    name: {{ $pg.cluster }}
  name: {{ $name }}
  login: true
  inRoles:
    {{- range .Values.databases }}
    - {{ $name }}-{{ . }}
    {{- end }}
  passwordSecret:
    name: {{ $name }}-database
  databaseRoleReclaimPolicy: retain
{{- range .Values.databases }}
---
apiVersion: postgresql.cnpg.io/v1
kind: DatabaseRole
metadata:
  name: {{ $name }}-{{ . }}
  namespace: {{ $pg.namespace }}
  labels:
    {{- include "apps.labels" $ | nindent 4 }}
spec:
  cluster:
    name: {{ $pg.cluster }}
  name: {{ $name }}-{{ . }}
  login: false
  databaseRoleReclaimPolicy: retain
---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: {{ $name }}-{{ . }}
  namespace: {{ $pg.namespace }}
  labels:
    {{- include "apps.labels" $ | nindent 4 }}
spec:
  cluster:
    name: {{ $pg.cluster }}
  name: {{ $name }}-{{ . }}
  owner: {{ $name }}
  databaseReclaimPolicy: retain
{{- end }}
{{- end }}
