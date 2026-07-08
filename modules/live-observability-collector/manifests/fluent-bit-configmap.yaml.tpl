apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: ${observability_namespace}
  labels:
    app.kubernetes.io/name: fluent-bit
    app.kubernetes.io/managed-by: bnk-forge
    app.kubernetes.io/part-of: bnk-live-observability
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Log_Level     warn
        Daemon        off
        Parsers_File  parsers.conf
        HTTP_Server   On
        HTTP_Listen   0.0.0.0
        HTTP_Port     2020

    # ------------------------------------------------------------------
    # INPUT: tail all container logs from /var/log/containers/*.log
    # ------------------------------------------------------------------
    [INPUT]
        Name              tail
        Tag               kube.*
        Path              /var/log/containers/*.log
        Parser            cri
        DB                /fluent-bit/state/flb_kube.db
        Mem_Buf_Limit     10MB
        Skip_Long_Lines   on
        Refresh_Interval  10

    # ------------------------------------------------------------------
    # FILTER: enrich with Kubernetes pod/namespace metadata
    # ------------------------------------------------------------------
    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix     kube.var.log.containers.
        Merge_Log           on
        Merge_Log_Key       log_processed
        Keep_Log            off
        K8S-Logging.Parser  on
        K8S-Logging.Exclude off

    # ------------------------------------------------------------------
    # FILTER: extract job / model / status from the parsed JSON payload
    # and promote them as top-level record fields so the Loki output
    # plugin can index them as stream labels.
    #
    # Producer contract:
    #   Log lines MUST contain a JSON object with at minimum:
    #     {"job":"llm-gateway","model":"<name>","status":"<2xx|4xx|5xx>"}
    #   Optional fields: latency_ms, prompt_tk, comp_tk, total_tk, etc.
    # ------------------------------------------------------------------
    [FILTER]
        Name    lua
        Match   kube.*
        Script  /fluent-bit/etc/promote_labels.lua
        Call    promote_loki_labels

    # ------------------------------------------------------------------
    # OUTPUT: forward to Loki push API
    #
    # Host / Port / URI are specified separately; passing a full URL to
    # Host is incorrect for the Fluent Bit Loki output plugin.
    # ------------------------------------------------------------------
    [OUTPUT]
        Name              loki
        Match             kube.*
        Host              ${loki_host}
        Port              ${loki_port}
        URI               /loki/api/v1/push
        tls               off
        Label_Keys        $job,$model,$status
        Remove_Keys       job,model,status
        Line_Format       json
        Auto_Kubernetes_Labels off

  parsers.conf: |
    [PARSER]
        Name        cri
        Format      regex
        Regex       ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<log>.*)$
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z

    [PARSER]
        Name        json
        Format      json
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z

  promote_labels.lua: |
    -- promote_labels.lua
    -- Extract job / model / status from a parsed JSON log record so that
    -- the Loki output plugin can use them as stream labels.
    -- Records without these fields are forwarded with empty label values.
    function promote_loki_labels(tag, timestamp, record)
      local log = record["log_processed"]
      if type(log) == "table" then
        record["job"]    = log["job"]    or ""
        record["model"]  = log["model"]  or ""
        record["status"] = log["status"] or ""
      else
        record["job"]    = ""
        record["model"]  = ""
        record["status"] = ""
      end
      return 1, timestamp, record
    end
