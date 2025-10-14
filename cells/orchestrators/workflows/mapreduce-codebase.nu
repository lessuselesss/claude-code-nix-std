#!/usr/bin/env nu
# MapReduce Codebase Analysis - Parallel Analysis Pattern
# Based on UserJot's Agentic AI Best Practices
# Pattern: Horizontal decomposition with parallel subagents

# Main orchestration function
def main [root: string, ...args] {
  print "📊 Codebase Analysis - MapReduce Pattern"
  print $"Root: ($root)"
  print ""

  # Initialize workflow state
  let state = {
    correlationId: (random uuid)
    root: $root
    started: (date now | date to-record)
    pattern: "mapreduce"
  }

  # Log workflow start
  log-workflow-start $state

  # Identify components to analyze
  let components = (discover-components $root)
  print $"Found ($components | length) components to analyze"
  print ""

  # MAP PHASE: Analyze each component in parallel
  print "🗺️  MAP: Analyzing components in parallel..."
  let analyses = $components
    | par-each { |component|
        timed-operation $"analyze-($component.name)" {
          analyze-component $component
        }
      }

  print $"✓ Analyzed ($analyses | length) components"
  print ""

  # REDUCE PHASE: Aggregate results
  print "🔄 REDUCE: Aggregating results..."
  let aggregated = (aggregate-analyses $analyses)

  print "✓ Aggregation complete"
  print ""

  # Final summary
  print-summary $aggregated

  # Save results
  let output_file = $"codebase-analysis-(date now | format date '%Y%m%d-%H%M%S').json"
  let final_state = {
    ...$state
    components: $components
    analyses: $analyses
    aggregated: $aggregated
    completed: (date now | date to-record)
    duration: ((date now) - ($state.started | into datetime))
  }

  $final_state | to json | save $output_file
  print $"Report saved: ($output_file)"

  $final_state
}

# Discover components in codebase
def discover-components [root: string] {
  # Identify distinct parts of codebase
  [
    {
      name: "backend"
      path: $"($root)/backend"
      type: "python"
      focus: ["API design" "Database queries" "Business logic"]
    }
    {
      name: "frontend"
      path: $"($root)/frontend"
      type: "javascript"
      focus: ["UI components" "State management" "Performance"]
    }
    {
      name: "tests"
      path: $"($root)/tests"
      type: "mixed"
      focus: ["Coverage" "Quality" "E2E scenarios"]
    }
    {
      name: "docs"
      path: $"($root)/docs"
      type: "markdown"
      focus: ["Completeness" "Accuracy" "Examples"]
    }
  ]
}

# Analyze single component (stateless subagent)
def analyze-component [component: record] {
  print $"  🔍 Analyzing ($component.name)..."

  try {
    # Get file list from MCP
    let files = (call-mcp-server "filesystem" {
      method: "files/list"
      params: {path: $component.path}
    })

    # Call AI agent for analysis
    let analysis = (call-agent $"analyzer-($component.type)" {
      component: $component.name
      files: $files
      focus: $component.focus
      task: $"Analyze ($component.name) component"
    })

    # Parse analysis results
    let results = (parse-analysis-results $analysis)

    # Track success
    track-metric "mapreduce.component_analyzed" 1 {
      component: $component.name
      status: "success"
    }

    {
      component: $component.name
      status: "success"
      files_analyzed: ($files | length)
      findings: $results.findings
      metrics: $results.metrics
      recommendations: $results.recommendations
      quality_score: $results.quality_score
    }

  } catch { |err|
    print $"  ⚠️  Failed to analyze ($component.name): ($err.msg)"

    # Track failure
    track-metric "mapreduce.component_analyzed" 1 {
      component: $component.name
      status: "failed"
    }

    {
      component: $component.name
      status: "failed"
      error: $err.msg
    }
  }
}

# Aggregate analyses (reduce phase)
def aggregate-analyses [analyses: list] {
  # Separate successful and failed analyses
  let successful = $analyses | where status == "success"
  let failed = $analyses | where status == "failed"

  print $"  ✓ Successful: ($successful | length)"
  print $"  ✗ Failed: ($failed | length)"

  # Aggregate findings across all components
  let all_findings = $successful
    | get findings
    | flatten
    | group-by severity
    | transpose severity findings
    | insert count { |row| $row.findings | length }

  # Aggregate metrics
  let metrics = {
    total_files: ($successful | get files_analyzed | math sum)
    total_findings: ($all_findings | get count | math sum)
    average_quality: ($successful | get quality_score | math avg)
    components_analyzed: ($successful | length)
    components_failed: ($failed | length)
  }

  # Synthesize recommendations
  let recommendations = (synthesize-recommendations $successful)

  # Calculate overall assessment
  let assessment = (calculate-assessment $metrics $all_findings)

  {
    metrics: $metrics
    findings_by_severity: $all_findings
    recommendations: $recommendations
    assessment: $assessment
    failed_components: $failed
  }
}

# Synthesize recommendations from multiple analyses
def synthesize-recommendations [analyses: list] {
  # Collect all recommendations
  let all_recs = $analyses
    | get recommendations
    | flatten
    | group-by category
    | transpose category items
    | insert priority { |row|
        # Calculate priority based on frequency
        if ($row.items | length) > 2 {
          "high"
        } else if ($row.items | length) > 1 {
          "medium"
        } else {
          "low"
        }
      }
    | sort-by priority

  $all_recs
}

# Calculate overall assessment
def calculate-assessment [metrics: record, findings: list] {
  let quality = $metrics.average_quality

  let assessment = if $quality > 80 {
    "excellent"
  } else if $quality > 60 {
    "good"
  } else if $quality > 40 {
    "needs improvement"
  } else {
    "critical issues"
  }

  let critical_count = $findings
    | where severity == "critical"
    | get count
    | math sum

  {
    overall: $assessment
    quality_score: $quality
    critical_issues: $critical_count
    requires_attention: ($critical_count > 0)
  }
}

# Print summary
def print-summary [aggregated: record] {
  print "📈 SUMMARY"
  print "=========="
  print ""

  print $"Overall Assessment: ($aggregated.assessment.overall)"
  print $"Quality Score: ($aggregated.assessment.quality_score | into string)"
  print $"Total Files Analyzed: ($aggregated.metrics.total_files)"
  print $"Total Findings: ($aggregated.metrics.total_findings)"
  print ""

  print "Findings by Severity:"
  $aggregated.findings_by_severity | each { |row|
    print $"  ($row.severity): ($row.count)"
  }
  print ""

  print "Top Recommendations:"
  $aggregated.recommendations | first 3 | each { |rec|
    print $"  [($rec.priority)] ($rec.category): ($rec.items | length) items"
  }
  print ""

  if $aggregated.assessment.requires_attention {
    print $"⚠️  ($aggregated.assessment.critical_issues) critical issues require immediate attention!"
  } else {
    print "✅ No critical issues found"
  }
}

# Helper: Call MCP server
def call-mcp-server [server: string, command: record] {
  # Placeholder - would integrate with actual MCP protocol
  [
    {file: "main.py", lines: 150}
    {file: "api.py", lines: 200}
    {file: "models.py", lines: 100}
  ]
}

# Helper: Call AI agent
def call-agent [agent: string, task: record] {
  # Placeholder - would call actual LLM
  $"
  Analysis of ($task.component):

  Findings:
  - 2 performance issues
  - 1 security concern
  - 3 code quality issues

  Metrics:
  - Test coverage: 75%
  - Complexity score: 6.5
  - Maintainability: B+

  Quality Score: 72/100
  "
}

# Helper: Parse analysis results
def parse-analysis-results [analysis: string] {
  # Placeholder - would actually parse LLM output
  {
    findings: [
      {severity: "medium", type: "performance", description: "N+1 query detected"}
      {severity: "high", type: "security", description: "Missing input validation"}
    ]
    metrics: {
      coverage: 75
      complexity: 6.5
    }
    recommendations: [
      {category: "performance", description: "Add query optimization"}
      {category: "security", description: "Implement input validation"}
    ]
    quality_score: 72
  }
}

# Helper: Timed operation
def timed-operation [name: string, operation: closure] {
  let start = (date now)

  let result = try {
    do $operation
  } catch { |err|
    {error: $err}
  }

  let duration = ((date now) - $start | into duration | into int)

  track-metric "mapreduce.operation_duration" $duration {operation: $name}

  if "error" in $result {
    error make $result.error
  } else {
    $result
  }
}

# Helper: Log workflow start
def log-workflow-start [state: record] {
  let log_dir = $"($env.HOME)/.config/comr/logs"
  mkdir $log_dir

  let log_entry = {
    timestamp: (date now | date to-record)
    level: "info"
    category: "orchestrator.workflow"
    message: "Starting MapReduce codebase analysis"
    context: {
      correlationId: $state.correlationId
      pattern: $state.pattern
      root: $state.root
    }
  }

  $log_entry | to json | save --append $"($log_dir)/orchestrator.log"
}

# Helper: Track metrics
def track-metric [name: string, value: number, labels: record] {
  let metrics_dir = $"($env.HOME)/.cache/comr/metrics"
  mkdir $metrics_dir

  let metric = {
    timestamp: (date now | date to-record)
    metric: $name
    value: $value
    labels: $labels
  }

  $metric | to json | save --append $"($metrics_dir)/orchestrator.jsonl"
}
