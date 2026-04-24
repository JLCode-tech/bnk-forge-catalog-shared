# Bedrock Smart-LLM Client

A load-generator pod that POSTs varied prompts to the BNK Gateway at a Poisson-distributed rate — bursty, like real clients. Part of the **EKS + BNK Intelligent AI Load Balancing Demo** blueprint.

## What this deploys

| Resource | Qty | Purpose |
|---|---|---|
| Namespace | 0 or 1 | Default: `bnk-demo-client`. Creation gated by `create_namespace`. |
| ConfigMap (source) | 1 | `client.py` + `requirements.txt` |
| ConfigMap (prompts) | 1 | `prompts.txt` — 20 varied prompts spanning short Q&A, reasoning, creative, code-gen. Edit to tailor the demo. |
| Deployment | 1 | `replicas` pods each running an independent Poisson loop |
| Service (headless) | 1 | Backs the ServiceMonitor — no routing target |
| ServiceMonitor | 1 | Labels-matched to kube-prometheus-stack by default |

## Metric names emitted

- `smartllm_client_requests_total{client_id, status, model_served}` — counter
- `smartllm_client_request_duration_seconds{client_id, model_served}` — histogram
- `smartllm_client_tokens_total{client_id, model_served, direction}` — counter (`direction=prompt|completion`)

`model_served` comes from the `model` field in the chat response, which the backend shim sets to whichever Bedrock-backed pod was picked — so you can aggregate `rate(smartllm_client_requests_total[1m])` by `model_served` to see the weight-shift from the client's perspective.

## Runtime shape — why Poisson

`time.sleep(random.expovariate(rate))` produces exponentially-distributed inter-arrival times, which by definition is a Poisson process. Net effect: a **naturally bursty** stream averaging `rate` req/s, without hand-rolling a state machine. Tune `request_rate` to exercise different load levels.

## Cross-namespace routing note

The client intentionally deploys to a different namespace from the backend. The BNK Gateway listener has `allowedRoutes.namespaces.from: Same`, but that applies to **HTTPRoutes attaching to the Gateway**, not to **clients sending traffic through it**. Once the Gateway has a VIP, anything that can reach the VIP can POST to the HTTPRoute's `/v1/*` paths.

## Common failure modes

| Symptom | Likely cause |
|---|---|
| Pod CrashLoops with `KeyError: 'GATEWAY_URL'` | `gateway_url` not wired from the backend module. In forge, both modules must be in the same project/plan so the dependency is resolved. |
| All requests `status="http_502"` | Backend shim pods not ready yet. Give it a minute. Check `kubectl logs -n default -l app.kubernetes.io/component=bedrock-shim`. |
| All requests succeed but `model_served="unknown"` | Backend shim isn't returning `model` in the response body. Verify the backend module's shim is the one from this catalog (not a demo bundle). |
| Prometheus shows zero `smartllm_client_*` series | `prometheus_release_label` doesn't match the operator's `serviceMonitorSelector`. |

## Tuning the demo

- **More bursty**: increase `replicas` (e.g. 3) with `request_rate=0.5` — three independent Poisson processes combined is more realistic than one process at 1.5/s.
- **Heavier calls**: raise `max_tokens` to 512+ — you'll see `vllm:request_generation_tokens` histograms spread wider in the backend shims' metrics.
- **Custom prompts**: edit `client/prompts.txt` in the catalog and redeploy. Lines starting with `#` are comments.

## Outputs

| Output | Purpose |
|---|---|
| `namespace` | Where the client Deployment landed |
| `deployment_name` | Useful for `kubectl logs -n <ns> deployment/<name>` |
