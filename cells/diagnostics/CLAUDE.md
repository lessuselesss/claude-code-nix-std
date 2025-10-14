# Diagnostics Cell - Observability & Monitoring

## Purpose

Provide comprehensive observability, telemetry, and monitoring for the entire framework. Track costs, performance, errors, and agent behavior across all cells with structured logging, metrics, tracing, and alerting.

## Key Features

- **Telemetry**: Token usage, costs, latency metrics
- **Structured Logging**: JSON logs with correlation IDs
- **Distributed Tracing**: Multi-agent workflow visibility
- **Health Checks**: System component validation
- **Cost Tracking**: Real-time spending across models/workspaces
- **Alerting**: Threshold-based notifications
- **Dashboards**: Grafana/Prometheus visualization

## Three-Layer API

**Layer 1:**
```nix
diagnostics.log "info" "Message"
diagnostics.trackCost { model = "claude-3.5-sonnet"; tokens = 1000; }
diagnostics.startTrace "workspace-execution"
```

**Layer 2:**
```nix
diagnostics.withTracing {
  name = "multi-agent-workflow";
  metadata = { workspace = "python-dev"; };
} (task: /* execution */);
```

**Layer 3:**
```nix
diagnostics.buildObserver {
  collectors = ["prometheus" "opentelemetry"];
  exporters = ["grafana" "datadog"];
  sampling = 0.1;
}
```

## Files

```
cells/diagnostics/
├── CLAUDE.md
├── lib.nix          # Observability API
├── data.nix         # Telemetry schemas, collectors
├── functions.nix    # Logging, metrics, tracing
├── runnables.nix    # Diagnostic tools, dashboards
└── packages.nix     # Telemetry agents (Prometheus, OpenTelemetry)
```

## Implementation Plan

### Phase 1: Logging Infrastructure (Week 8, Days 1-2)

**data.nix:**
```nix
{inputs, cell}: {
  # Log levels
  logLevels = {
    debug = 10;
    info = 20;
    warning = 30;
    error = 40;
    critical = 50;
  };

  # Log format schema
  logSchema = {
    timestamp = "ISO8601";
    level = "string";
    message = "string";
    context = {
      cell = "string";
      function = "string";
      correlationId = "uuid";
      workspace = "string?";
      agent = "string?";
      model = "string?";
    };
    metadata = "object";
    error = {
      type = "string?";
      stack = "string?";
    };
  };

  # Structured log destinations
  logDestinations = {
    stdout = {
      enabled = true;
      format = "json";
      minLevel = "info";
    };

    file = {
      enabled = true;
      path = "$HOME/.config/comr/logs/comr.log";
      format = "json";
      minLevel = "debug";
      rotation = {
        maxSizeMb = 100;
        maxFiles = 10;
      };
    };

    syslog = {
      enabled = false;
      facility = "local0";
      minLevel = "warning";
    };

    remote = {
      enabled = false;
      endpoint = "https://logs.example.com/ingest";
      format = "json";
      minLevel = "info";
      batchSize = 100;
    };
  };

  # Log categories for filtering
  logCategories = [
    "agent.execution"
    "mcp.server.call"
    "llm.request"
    "llm.response"
    "cost.calculation"
    "config.load"
    "workspace.init"
    "orchestrator.coordination"
    "marketplace.plugin"
    "routing.selection"
  ];
}
```

**lib.nix (Logging API):**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in rec {
  # High-level: Simple logging
  log = level: message:
    cell.functions.writeLog {
      inherit level message;
      context = getCurrentContext {};
    };

  logDebug = message: log "debug" message;
  logInfo = message: log "info" message;
  logWarning = message: log "warning" message;
  logError = message: log "error" message;
  logCritical = message: log "critical" message;

  # High-level: Contextual logging
  logWith = context: level: message:
    cell.functions.writeLog {
      inherit level message;
      context = getCurrentContext context;
    };

  # Medium-level: Structured logging
  structuredLog = { level, message, category ? null, metadata ? {}, error ? null }:
    cell.functions.writeStructuredLog {
      inherit level message category metadata error;
      context = getCurrentContext {};
    };

  # Low-level: Raw log entry
  writeRawLog = entry:
    cell.functions.writeToDestinations entry;

  # Get current execution context
  getCurrentContext = additionalContext:
    {
      correlationId = generateCorrelationId {};
      timestamp = getCurrentTimestamp {};
    } // additionalContext;

  # Generate correlation ID for request tracing
  generateCorrelationId = {}:
    let
      pid = builtins.getEnv "BASHPID";
      timestamp = getCurrentTimestamp {};
    in builtins.hashString "sha256" "${pid}-${timestamp}";

  getCurrentTimestamp = {}:
    builtins.readFile (pkgs.runCommand "timestamp" {} ''
      date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" > $out
    '');
}
```

### Phase 2: Metrics Collection (Week 8, Days 3-4)

**data.nix (Metrics):**
```nix
{
  # Metric types
  metricTypes = {
    counter = "Monotonically increasing value";
    gauge = "Point-in-time value";
    histogram = "Distribution of values";
    summary = "Similar to histogram with quantiles";
  };

  # Core metrics
  metrics = {
    # Cost metrics
    "llm.cost.total" = {
      type = "counter";
      unit = "usd";
      labels = ["model" "workspace" "profile"];
      description = "Total LLM API costs";
    };

    "llm.cost.per_request" = {
      type = "histogram";
      unit = "usd";
      labels = ["model" "workspace"];
      buckets = [0.001 0.01 0.1 1.0 10.0];
      description = "Cost per individual request";
    };

    # Token metrics
    "llm.tokens.input" = {
      type = "counter";
      unit = "tokens";
      labels = ["model" "workspace"];
      description = "Total input tokens consumed";
    };

    "llm.tokens.output" = {
      type = "counter";
      unit = "tokens";
      labels = ["model" "workspace"];
      description = "Total output tokens generated";
    };

    # Performance metrics
    "llm.latency" = {
      type = "histogram";
      unit = "seconds";
      labels = ["model" "operation"];
      buckets = [0.1 0.5 1.0 5.0 10.0 30.0];
      description = "LLM request latency";
    };

    "workspace.execution_time" = {
      type = "histogram";
      unit = "seconds";
      labels = ["workspace"];
      buckets = [1 5 10 30 60 300];
      description = "Total workspace execution time";
    };

    # Error metrics
    "llm.errors.total" = {
      type = "counter";
      unit = "count";
      labels = ["model" "error_type"];
      description = "Total LLM API errors";
    };

    "mcp.server.errors" = {
      type = "counter";
      unit = "count";
      labels = ["server" "error_type"];
      description = "MCP server errors";
    };

    # Rate limit metrics
    "llm.rate_limit.hits" = {
      type = "counter";
      unit = "count";
      labels = ["model"];
      description = "Rate limit violations";
    };

    # Agent metrics
    "agent.invocations" = {
      type = "counter";
      unit = "count";
      labels = ["agent" "workspace"];
      description = "Agent invocation count";
    };

    "agent.success_rate" = {
      type = "gauge";
      unit = "percent";
      labels = ["agent"];
      description = "Agent task success rate";
    };

    # MCP server metrics
    "mcp.server.calls" = {
      type = "counter";
      unit = "count";
      labels = ["server" "method"];
      description = "MCP server method calls";
    };

    "mcp.server.latency" = {
      type = "histogram";
      unit = "seconds";
      labels = ["server" "method"];
      buckets = [0.01 0.1 0.5 1.0 5.0];
      description = "MCP server call latency";
    };

    # Orchestration metrics
    "orchestrator.workflows" = {
      type = "counter";
      unit = "count";
      labels = ["pattern" "status"];
      description = "Multi-agent workflow executions";
    };

    # Cache metrics
    "cache.hits" = {
      type = "counter";
      unit = "count";
      labels = ["cache_type"];
      description = "Cache hit count";
    };

    "cache.misses" = {
      type = "counter";
      unit = "count";
      labels = ["cache_type"];
      description = "Cache miss count";
    };
  };

  # Metric exporters
  exporters = {
    prometheus = {
      enabled = true;
      port = 9090;
      endpoint = "/metrics";
      format = "prometheus";
    };

    opentelemetry = {
      enabled = false;
      endpoint = "http://localhost:4318";
      protocol = "grpc";
    };

    statsd = {
      enabled = false;
      host = "localhost";
      port = 8125;
      prefix = "comr";
    };

    datadog = {
      enabled = false;
      apiKey = "$DATADOG_API_KEY";
      site = "datadoghq.com";
    };
  };
}
```

**lib.nix (Metrics API):**
```nix
{
  # High-level: Track cost
  trackCost = { model, inputTokens, outputTokens, workspace ? "unknown" }:
    let
      cost = inputs.cells.config.functions.estimateCost {
        inherit model inputTokens outputTokens;
      };
    in {
      cell.functions.incrementCounter "llm.cost.total" cost ["model=${model}" "workspace=${workspace}"];
      cell.functions.recordHistogram "llm.cost.per_request" cost ["model=${model}" "workspace=${workspace}"];
      cell.functions.incrementCounter "llm.tokens.input" inputTokens ["model=${model}" "workspace=${workspace}"];
      cell.functions.incrementCounter "llm.tokens.output" outputTokens ["model=${model}" "workspace=${workspace}"];
    };

  # High-level: Track latency
  trackLatency = operation: duration:
    cell.functions.recordHistogram "llm.latency" duration ["operation=${operation}"];

  # High-level: Track error
  trackError = errorType: labels:
    cell.functions.incrementCounter "llm.errors.total" 1 (["error_type=${errorType}"] ++ labels);

  # Medium-level: Custom metric
  recordMetric = { name, type, value, labels ? [] }:
    if type == "counter"
    then cell.functions.incrementCounter name value labels
    else if type == "gauge"
    then cell.functions.setGauge name value labels
    else if type == "histogram"
    then cell.functions.recordHistogram name value labels
    else throw "Unknown metric type: ${type}";

  # Low-level: Prometheus format
  exportPrometheus = metrics:
    cell.functions.formatPrometheus metrics;
}
```

### Phase 3: Distributed Tracing (Week 8, Days 5-6)

**data.nix (Tracing):**
```nix
{
  # Trace configuration
  tracing = {
    enabled = true;
    samplingRate = 1.0;  # 100% in dev, 0.1 (10%) in prod

    exporters = {
      jaeger = {
        enabled = false;
        endpoint = "http://localhost:14268/api/traces";
      };

      zipkin = {
        enabled = false;
        endpoint = "http://localhost:9411/api/v2/spans";
      };

      opentelemetry = {
        enabled = true;
        endpoint = "http://localhost:4318/v1/traces";
        protocol = "http";
      };

      stdout = {
        enabled = true;
        format = "json";
      };
    };

    # Span attributes
    spanAttributes = [
      "workspace"
      "agent"
      "model"
      "mcp_server"
      "operation"
      "user_id"
    ];

    # Automatic instrumentation
    autoInstrument = {
      llmCalls = true;
      mcpServerCalls = true;
      workspaceExecution = true;
      agentInvocation = true;
    };
  };

  # Span kinds
  spanKinds = {
    internal = "INTERNAL";
    server = "SERVER";
    client = "CLIENT";
    producer = "PRODUCER";
    consumer = "CONSUMER";
  };
}
```

**lib.nix (Tracing API):**
```nix
{
  # High-level: Start trace
  startTrace = name:
    let
      traceId = generateTraceId {};
      spanId = generateSpanId {};
    in cell.functions.createSpan {
      inherit name traceId spanId;
      kind = "internal";
      startTime = getCurrentTimestamp {};
    };

  # High-level: End trace
  endTrace = span:
    cell.functions.endSpan span {
      endTime = getCurrentTimestamp {};
    };

  # High-level: Trace function execution
  withTracing = { name, metadata ? {} }: fn:
    let
      span = startTrace name;
      result = fn span;
      finalSpan = span // { metadata = metadata; };
    in
      builtins.seq (endTrace finalSpan) result;

  # Medium-level: Create child span
  createChildSpan = parentSpan: name:
    cell.functions.createSpan {
      inherit name;
      traceId = parentSpan.traceId;
      parentSpanId = parentSpan.spanId;
      spanId = generateSpanId {};
      kind = "internal";
      startTime = getCurrentTimestamp {};
    };

  # Medium-level: Add span event
  addSpanEvent = span: event:
    span // {
      events = (span.events or []) ++ [{
        name = event.name;
        timestamp = getCurrentTimestamp {};
        attributes = event.attributes or {};
      }];
    };

  # Low-level: Export trace
  exportTrace = trace:
    cell.functions.sendToExporters "trace" trace;

  generateTraceId = {}:
    builtins.hashString "sha256" "${getCurrentTimestamp {}}-${builtins.getEnv "RANDOM"}";

  generateSpanId = {}:
    builtins.substring 0 16 (generateTraceId {});
}
```

### Phase 4: Health Checks & Monitoring (Week 8, Day 7)

**lib.nix (Health Checks):**
```nix
{
  # Health check API
  checkHealth = component:
    if component == "all"
    then cell.functions.checkAllComponents {}
    else cell.functions.checkComponent component;

  # Check all system components
  checkAllComponents = {}:
    let
      checks = {
        config = checkConfig {};
        llm = checkLlmProviders {};
        mcp = checkMcpServers {};
        storage = checkStorage {};
      };

      allHealthy = builtins.all (c: c.healthy) (builtins.attrValues checks);
    in {
      healthy = allHealthy;
      checks = checks;
      timestamp = getCurrentTimestamp {};
    };

  # Individual component checks
  checkConfig = {}:
    let
      configValid = inputs.cells.config.lib.validate inputs.cells.config.data.defaults;
    in {
      healthy = true;
      component = "config";
      message = "Configuration valid";
    };

  checkLlmProviders = {}:
    let
      apiKeys = {
        anthropic = inputs.cells.config.lib.getApiKey "anthropic";
        google = inputs.cells.config.lib.getApiKey "google";
      };

      keysSet = builtins.all (k: k != "" && k != null) (builtins.attrValues apiKeys);
    in {
      healthy = keysSet;
      component = "llm";
      message = if keysSet then "API keys configured" else "Missing API keys";
    };

  checkMcpServers = {}:
    let
      servers = inputs.cells.mcp.data.servers;
      serverCount = builtins.length (builtins.attrNames servers);
    in {
      healthy = serverCount > 0;
      component = "mcp";
      message = "Found ${builtins.toString serverCount} MCP servers";
    };

  checkStorage = {}:
    let
      configDir = inputs.cells.config.data.configPaths.unified.configDir;
      exists = builtins.pathExists configDir;
    in {
      healthy = exists;
      component = "storage";
      message = if exists then "Config directory accessible" else "Config directory missing";
    };
}
```

### Phase 5: Diagnostic Tools (Week 9, Days 1-3)

**runnables.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in {
  # Show real-time logs
  tail-logs = pkgs.writeShellScriptBin "comr-logs" ''
    #!/usr/bin/env bash
    LOG_FILE="${inputs.cells.config.data.configPaths.unified.configDir}/logs/comr.log"

    if [[ ! -f "$LOG_FILE" ]]; then
      echo "No logs found at $LOG_FILE"
      exit 1
    fi

    # Follow logs with jq formatting
    tail -f "$LOG_FILE" | ${pkgs.jq}/bin/jq -C '.'
  '';

  # Filter logs by level
  filter-logs = pkgs.writeShellScriptBin "comr-logs-filter" ''
    #!/usr/bin/env bash
    LEVEL="$1"
    LOG_FILE="${inputs.cells.config.data.configPaths.unified.configDir}/logs/comr.log"

    ${pkgs.jq}/bin/jq "select(.level == \"$LEVEL\")" "$LOG_FILE"
  '';

  # Search logs by category
  search-logs = pkgs.writeShellScriptBin "comr-logs-search" ''
    #!/usr/bin/env bash
    CATEGORY="$1"
    LOG_FILE="${inputs.cells.config.data.configPaths.unified.configDir}/logs/comr.log"

    ${pkgs.jq}/bin/jq "select(.context.category == \"$CATEGORY\")" "$LOG_FILE"
  '';

  # Cost report
  cost-report = pkgs.writeShellScriptBin "comr-cost-report" ''
    #!/usr/bin/env bash
    echo "💰 Cost Report"
    echo "============="

    # Query metrics database or logs
    # Parse and aggregate costs by model, workspace, time period
    # ... reporting logic ...
  '';

  # Performance report
  perf-report = pkgs.writeShellScriptBin "comr-perf-report" ''
    #!/usr/bin/env bash
    echo "⚡ Performance Report"
    echo "==================="

    # Query metrics for latency percentiles
    # Show slowest operations
    # ... reporting logic ...
  '';

  # Health check
  health-check = pkgs.writeShellScriptBin "comr-health" ''
    #!/usr/bin/env bash
    echo "🏥 System Health Check"
    echo "===================="

    # Run health checks
    RESULT=$(nix eval --json '.#diagnostics.lib.checkHealth' --apply 'f: f "all"')

    echo "$RESULT" | ${pkgs.jq}/bin/jq '.'

    # Exit with error if unhealthy
    HEALTHY=$(echo "$RESULT" | ${pkgs.jq}/bin/jq -r '.healthy')
    if [[ "$HEALTHY" != "true" ]]; then
      exit 1
    fi
  '';

  # Start Prometheus
  prometheus = pkgs.writeShellScriptBin "comr-prometheus" ''
    #!/usr/bin/env bash
    PROMETHEUS_CONFIG="${./prometheus.yml}"

    echo "📊 Starting Prometheus..."
    ${pkgs.prometheus}/bin/prometheus --config.file="$PROMETHEUS_CONFIG"
  '';

  # Start Grafana
  grafana = pkgs.writeShellScriptBin "comr-grafana" ''
    #!/usr/bin/env bash
    echo "📈 Starting Grafana..."
    ${pkgs.grafana}/bin/grafana-server \
      --config="${./grafana.ini}" \
      --homepath="${pkgs.grafana}/share/grafana"
  '';

  # Export metrics
  export-metrics = pkgs.writeShellScriptBin "comr-metrics-export" ''
    #!/usr/bin/env bash
    FORMAT="''${1:-json}"

    echo "📊 Exporting metrics in $FORMAT format..."

    # Query internal metrics store
    # Export to specified format
    # ... export logic ...
  '';

  # Trace viewer
  trace-viewer = pkgs.writeShellScriptBin "comr-traces" ''
    #!/usr/bin/env bash
    TRACE_ID="$1"

    if [[ -z "$TRACE_ID" ]]; then
      echo "Usage: comr-traces <trace-id>"
      exit 1
    fi

    # Query trace backend
    # Display trace tree
    # ... viewer logic ...
  '';

  # Alert simulator
  test-alerts = pkgs.writeShellScriptBin "comr-test-alerts" ''
    #!/usr/bin/env bash
    echo "🚨 Testing alerting system..."

    # Trigger test alerts
    # - Cost threshold exceeded
    # - Error rate spike
    # - Latency spike
    # ... test logic ...
  '';
}
```

### Phase 6: Dashboards & Visualization (Week 9, Days 4-5)

**Grafana Dashboards:**

Create pre-configured Grafana dashboards:

1. **Cost Dashboard** (`dashboards/cost.json`)
   - Total spend (daily/weekly/monthly)
   - Cost by model
   - Cost by workspace
   - Cost trend over time
   - Budget utilization

2. **Performance Dashboard** (`dashboards/performance.json`)
   - Request latency percentiles (p50, p95, p99)
   - Slowest operations
   - Throughput (requests/second)
   - MCP server latency
   - Agent execution time

3. **Errors Dashboard** (`dashboards/errors.json`)
   - Error rate over time
   - Errors by type
   - Errors by component
   - Rate limit hits
   - Failed requests

4. **Agent Dashboard** (`dashboards/agents.json`)
   - Agent invocations
   - Success rate
   - Most used agents
   - Agent latency
   - Multi-agent workflow stats

5. **MCP Dashboard** (`dashboards/mcp.json`)
   - Server call frequency
   - Server latency
   - Server errors
   - Most used servers
   - Server availability

**Prometheus Configuration:**

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'comr'
    static_configs:
      - targets: ['localhost:9090']

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

rule_files:
  - 'alerts.yml'
```

**Alert Rules:**

```yaml
# alerts.yml
groups:
  - name: cost_alerts
    interval: 1m
    rules:
      - alert: DailyCostExceeded
        expr: llm_cost_total{period="day"} > 100
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Daily cost limit exceeded"

      - alert: CostWarningThreshold
        expr: llm_cost_total{period="day"} > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Approaching daily cost limit"

  - name: performance_alerts
    interval: 1m
    rules:
      - alert: HighLatency
        expr: histogram_quantile(0.95, llm_latency_bucket) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "LLM latency p95 > 10s"

  - name: error_alerts
    interval: 1m
    rules:
      - alert: HighErrorRate
        expr: rate(llm_errors_total[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Error rate > 10%"
```

### Phase 7: Nushell Integration for Diagnostics (Week 9, Days 6-7)

**Rationale:** Diagnostic tools heavily parse JSON logs, filter data, aggregate metrics, and calculate statistics - all perfect use cases for Nushell's structured data handling. Converting bash+jq scripts to Nushell improves performance, readability, and maintainability.

**Commands to Convert:**
- `tail-logs` - Parse JSON logs with real-time filtering
- `filter-logs` - Multi-criteria filtering (level, category, workspace)
- `search-logs` - Complex queries across log fields
- `cost-report` - Aggregate and visualize costs
- `perf-report` - Calculate p50/p95/p99 latencies

**Keep Bash:**
- `prometheus`, `grafana` - Daemon launchers
- `health-check` - Can use nix eval

**runnables.nix - Nushell Version:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
  writeNuApp = inputs.cells.lib.functions.writeNushellApplication;
  helpers = inputs.cells.lib.functions.includeHelpers;
in {
  # Nushell: Real-time log viewer with filtering
  tail-logs = writeNuApp {
    name = "comr-logs";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        --level: string        # Filter by level
        --category: string     # Filter by category
        --workspace: string    # Filter by workspace
        --follow (-f)          # Follow logs (tail -f style)
      ] {
        let log_file = "~/.config/comr/logs/comr.log"

        if not ($log_file | path exists) {
          print "No logs found"
          exit 1
        }

        if $follow {
          # Tail -f with filtering
          ^tail -f $log_file
            | lines
            | each { |line|
                try {
                  let entry = ($line | from json)
                  if (should-show $entry $level $category $workspace) {
                    format-log-entry $entry
                  }
                } catch {
                  $line  # Pass through non-JSON lines
                }
              }
        } else {
          # Static log view
          open $log_file
            | lines
            | each { |line| try { $line | from json } catch { null } }
            | where $it != null
            | where { |entry| should-show $entry $level $category $workspace }
            | each { |entry| format-log-entry $entry }
        }
      }

      # Filter logic
      def should-show [entry: record, level: string, category: string, workspace: string] {
        let level_match = if $level == null { true } else { $entry.level == $level }
        let cat_match = if $category == null { true } else { ($entry.context?.category? | default "") == $category }
        let ws_match = if $workspace == null { true } else { ($entry.context?.workspace? | default "") == $workspace }

        $level_match and $cat_match and $ws_match
      }

      # Format log entry with colors
      def format-log-entry [entry: record] {
        let level_icon = match $entry.level {
          "debug" => { "🔍" }
          "info" => { "ℹ️ " }
          "warning" => { "⚠️ " }
          "error" => { "❌" }
          "critical" => { "🚨" }
          _ => { "  " }
        }

        let timestamp = ($entry.timestamp | into datetime | format date "%Y-%m-%d %H:%M:%S")

        $"($level_icon) ($timestamp) [($entry.level)] ($entry.message)"
      }
    '';
  };

  # Nushell: Advanced log filtering
  filter-logs = writeNuApp {
    name = "comr-logs-filter";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        --level: string
        --category: string
        --workspace: string
        --agent: string
        --model: string
        --since: string = "1day"    # Time window
        --limit: int = 100           # Max results
      ] {
        let log_file = "~/.config/comr/logs/comr.log"

        let cutoff = (date now) - ($since | into duration)

        open $log_file
          | lines
          | each { |line| try { $line | from json } catch { null } }
          | where $it != null
          | where { |entry| ($entry.timestamp | into datetime) > $cutoff }
          | where { |entry|
              ($level == null or $entry.level == $level) and
              ($category == null or ($entry.context?.category? | default "") == $category) and
              ($workspace == null or ($entry.context?.workspace? | default "") == $workspace) and
              ($agent == null or ($entry.context?.agent? | default "") == $agent) and
              ($model == null or ($entry.context?.model? | default "") == $model)
            }
          | first $limit
          | table
      }
    '';
  };

  # Nushell: Log search with text matching
  search-logs = writeNuApp {
    name = "comr-logs-search";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        query: string              # Search query
        --field: string = "message"  # Field to search in
        --regex (-r)                # Use regex matching
      ] {
        let log_file = "~/.config/comr/logs/comr.log"

        open $log_file
          | lines
          | each { |line| try { $line | from json } catch { null } }
          | where $it != null
          | where { |entry|
              let value = match $field {
                "message" => { $entry.message }
                "level" => { $entry.level }
                "category" => { $entry.context?.category? | default "" }
                _ => { $entry | get $field }
              }

              if $regex {
                $value =~ $query
              } else {
                $value | str contains $query
              }
            }
          | select timestamp level message context
          | table
      }
    '';
  };

  # Nushell: Comprehensive cost report
  cost-report = writeNuApp {
    name = "comr-cost-report";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        --period: string = "day"  # day, week, month, all
        --group-by: string = "model"  # model, workspace, agent
      ] {
        print "💰 Cost Report"
        print "=" * 50
        print ""

        # Parse cost data from logs
        let costs = (parse-costs $period)

        if ($costs | length) == 0 {
          print "No cost data available"
          return
        }

        # Summary stats
        let total = ($costs | get cost | math sum)
        let avg = ($costs | get cost | math avg)
        let count = ($costs | length)

        print $"Period: ($period)"
        print $"Total Requests: ($count)"
        print $"Total Cost: \$($total | into string)"
        print $"Average Cost: \$($avg | into string)"
        print ""

        # Group and display
        print $"Breakdown by ($group_by):"
        $costs
          | group-by $group_by
          | transpose key entries
          | insert total_cost { |row| $row.entries | get cost | math sum }
          | insert calls { |row| $row.entries | length }
          | insert avg_cost { |row| $row.entries | get cost | math avg }
          | select key calls total_cost avg_cost
          | sort-by -r total_cost
          | rename $group_by calls "total ($)" "avg ($)"
          | table
      }

      # Parse cost entries from logs
      def parse-costs [period: string] {
        let log_file = "~/.config/comr/logs/comr.log"

        let cutoff = match $period {
          "day" => { (date now) - 1day }
          "week" => { (date now) - 7day }
          "month" => { (date now) - 30day }
          "all" => { (date now) - 365day }
          _ => { (date now) - 1day }
        }

        open $log_file
          | lines
          | each { |line| try { $line | from json } catch { null } }
          | where $it != null
          | where context.category? == "llm.request"
          | where ($it.timestamp | into datetime) > $cutoff
          | each { |entry|
              {
                timestamp: $entry.timestamp
                model: ($entry.context?.model? | default "unknown")
                workspace: ($entry.context?.workspace? | default "unknown")
                agent: ($entry.context?.agent? | default "unknown")
                cost: ($entry.metadata?.cost? | default 0)
              }
            }
      }
    '';
  };

  # Nushell: Performance report with percentiles
  perf-report = writeNuApp {
    name = "comr-perf-report";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        --operation: string    # Filter by operation type
        --since: string = "1hour"
      ] {
        print "⚡ Performance Report"
        print "=" * 50
        print ""

        let cutoff = (date now) - ($since | into duration)

        # Parse latency data from logs
        let latencies = (
          open ~/.config/comr/logs/comr.log
            | lines
            | each { |line| try { $line | from json } catch { null } }
            | where $it != null
            | where context.category? == "llm.request"
            | where ($it.timestamp | into datetime) > $cutoff
            | where { |entry|
                $operation == null or ($entry.context?.operation? | default "") == $operation
              }
            | each { |entry|
                {
                  operation: ($entry.context?.operation? | default "unknown")
                  model: ($entry.context?.model? | default "unknown")
                  latency_ms: ($entry.metadata?.latency_ms? | default 0)
                }
              }
        )

        if ($latencies | length) == 0 {
          print "No performance data available"
          return
        }

        # Calculate percentiles
        let sorted = ($latencies | get latency_ms | sort)
        let count = ($sorted | length)

        let p50 = ($sorted | get (($count * 0.5) | math floor))
        let p95 = ($sorted | get (($count * 0.95) | math floor))
        let p99 = ($sorted | get (($count * 0.99) | math floor))
        let max = ($sorted | last)

        print "Latency Percentiles:"
        print $"  P50 (median): ($p50)ms"
        print $"  P95: ($p95)ms"
        print $"  P99: ($p99)ms"
        print $"  Max: ($max)ms"
        print ""

        # Slowest operations
        print "Slowest 10 Operations:"
        $latencies
          | sort-by latency_ms
          | reverse
          | first 10
          | table
        print ""

        # By operation type
        print "By Operation:"
        $latencies
          | group-by operation
          | transpose operation entries
          | insert count { |row| $row.entries | length }
          | insert p95_ms { |row|
              let sorted = ($row.entries | get latency_ms | sort)
              $sorted | get ((($sorted | length) * 0.95) | math floor)
            }
          | select operation count p95_ms
          | sort-by -r p95_ms
          | table
      }
    '';
  };

  # Keep bash for daemon launchers
  prometheus = pkgs.writeShellScriptBin "comr-prometheus" ''
    # ... same as before (daemon launcher) ...
  '';

  grafana = pkgs.writeShellScriptBin "comr-grafana" ''
    # ... same as before (daemon launcher) ...
  '';

  health-check = pkgs.writeShellScriptBin "comr-health" ''
    # ... same as before (nix eval works well) ...
  '';

  export-metrics = pkgs.writeShellScriptBin "comr-metrics-export" ''
    # ... same as before ...
  '';

  trace-viewer = pkgs.writeShellScriptBin "comr-traces" ''
    # ... same as before ...
  '';

  test-alerts = pkgs.writeShellScriptBin "comr-test-alerts" ''
    # ... same as before ...
  '';
}
```

**Benefits of Nushell for Diagnostics:**

1. **Native JSON Parsing**: No more `jq` pipelines - `from json` is built-in
2. **Statistical Functions**: `math sum`, `math avg`, percentiles without external tools
3. **Group-By Operations**: Native `group-by` for aggregations
4. **Table Formatting**: Beautiful tables with `| table`
5. **Time Operations**: Native date/duration handling
6. **Error Handling**: try/catch instead of bash's error-prone conditionals

**Example Output:**

```
$ comr-logs --level error --workspace python-dev --follow
❌ 2025-01-15 10:30:45 [error] LLM request failed: rate limit exceeded
❌ 2025-01-15 10:31:02 [error] MCP server timeout: postgres

$ comr-cost-report --period week --group-by workspace
💰 Cost Report
==================================================

Period: week
Total Requests: 234
Total Cost: $12.45
Average Cost: $0.053

Breakdown by workspace:
╭───────────────┬───────┬───────────┬───────────╮
│ workspace     │ calls │ total ($) │ avg ($)   │
├───────────────┼───────┼───────────┼───────────┤
│ python-dev    │ 120   │ 6.80      │ 0.057     │
│ web-dev       │ 80    │ 4.20      │ 0.053     │
│ security-audit│ 34    │ 1.45      │ 0.043     │
╰───────────────┴───────┴───────────┴───────────╯

$ comr-perf-report --since 1hour
⚡ Performance Report
==================================================

Latency Percentiles:
  P50 (median): 450ms
  P95: 1200ms
  P99: 2800ms
  Max: 3500ms

Slowest 10 Operations:
╭─────────────┬────────────────┬────────────╮
│ operation   │ model          │ latency_ms │
├─────────────┼────────────────┼────────────┤
│ code-review │ claude-sonnet  │ 3500       │
│ analysis    │ gemini-flash   │ 2900       │
╰─────────────┴────────────────┴────────────╯
```

## Dependencies

- Inputs: `nixpkgs`, `cells.config`, `cells.lib` (for Nushell writers)
- External: Prometheus, Grafana, OpenTelemetry Collector (optional), `nushell`
- Consumes: `config` (for cost calculation), `lib` (Nushell writers)
- Produces for: ALL cells (provides observability)

## Integration Points

All cells should integrate diagnostics:

```nix
# Example: llm cell
{inputs, cell}: {
  ask = model: prompt:
    let
      # Start trace
      span = inputs.cells.diagnostics.lib.startTrace "llm.ask";

      # Execute
      startTime = getCurrentTime {};
      result = executeRequest model prompt;
      endTime = getCurrentTime {};

      # Log
      inputs.cells.diagnostics.lib.logInfo "LLM request completed";

      # Track metrics
      inputs.cells.diagnostics.lib.trackCost {
        inherit model;
        inputTokens = result.usage.input_tokens;
        outputTokens = result.usage.output_tokens;
      };

      inputs.cells.diagnostics.lib.trackLatency "llm.ask" (endTime - startTime);

      # End trace
      inputs.cells.diagnostics.lib.endTrace span;
    in result;
}
```

## Success Criteria

- [ ] Structured logging implemented (JSON format)
- [ ] Metrics collection works (Prometheus-compatible)
- [ ] Distributed tracing functional (OpenTelemetry)
- [ ] Health checks validate all components
- [ ] Cost tracking accurate and real-time
- [ ] Performance metrics captured (latency, throughput)
- [ ] Error tracking and alerting functional
- [ ] Grafana dashboards created (5 dashboards)
- [ ] CLI diagnostic tools provided
- [ ] All cells integrated with diagnostics
- [ ] Documentation complete
