#!/usr/bin/env nu
# CrewAI Code Review - Hierarchical Delegation Pattern
# Based on UserJot's Agentic AI Best Practices
# Pattern: Manager coordinates workers with defined roles

# Main orchestration function
def main [target: string, ...args] {
  print "👥 Code Review - CrewAI Pattern"
  print $"Target: ($target)"
  print ""

  # Initialize workflow state
  let state = {
    correlationId: (random uuid)
    target: $target
    started: (date now | date to-record)
    pattern: "crewai"
    round: 0
  }

  # Log workflow start
  log-workflow-start $state

  # Define the crew
  let crew = {
    manager: {
      name: "senior-reviewer"
      model: "claude-3.5-sonnet"
      role: "Lead code reviewer and coordinator"
      responsibilities: ["Coordinate review" "Aggregate findings" "Make final decisions"]
    }
    workers: [
      {
        name: "security-reviewer"
        model: "claude-3.5-sonnet"
        role: "Security specialist"
        focus: ["OWASP Top 10" "Authentication" "Input validation" "Cryptography"]
      }
      {
        name: "performance-reviewer"
        model: "gemini-2.0-flash"
        role: "Performance specialist"
        focus: ["Algorithms" "Database queries" "Caching" "Resource usage"]
      }
      {
        name: "maintainability-reviewer"
        model: "gemini-2.0-flash"
        role: "Code quality specialist"
        focus: ["Readability" "Documentation" "Test coverage" "Design patterns"]
      }
    ]
  }

  print $"Crew assembled: 1 manager + ($crew.workers | length) workers"
  print ""

  # HIERARCHICAL PROCESS
  let result = (hierarchical-review $crew $state)

  print ""
  print "✅ Code review complete"

  # Save results
  let output_file = $"code-review-(date now | format date '%Y%m%d-%H%M%S').json"
  let final_state = {
    ...$result
    completed: (date now | date to-record)
    duration: ((date now) - ($state.started | into datetime))
  }

  $final_state | to json | save $output_file
  print $"Review saved: ($output_file)"

  $final_state
}

# Hierarchical review process (manager supervises workers)
def hierarchical-review [crew: record, state: record] {
  let max_rounds = 3
  mut current_state = $state

  # Manager creates initial review plan
  print "📋 PHASE 1: Manager creating review plan..."
  let plan = (manager-create-plan $crew.manager $crew.workers $current_state)

  print $"  ✓ Plan created: ($plan.tasks | length) tasks"
  print ""

  # Initial worker execution
  print "🔍 PHASE 2: Workers performing review..."
  let worker_results = (workers-execute $crew.workers $plan.tasks $current_state)

  print $"  ✓ Workers completed: ($worker_results | where status == "success" | length)/($worker_results | length)"
  print ""

  # Update state
  $current_state = ($current_state | upsert worker_results $worker_results)

  # Manager reviews and decides if more rounds needed
  print "👔 PHASE 3: Manager reviewing worker outputs..."
  let review = (manager-review $crew.manager $current_state)

  print $"  Decision: ($review.decision)"
  print ""

  # Supervision loop (if needed)
  if $review.decision == "needs-revision" and $current_state.round < $max_rounds {
    print $"🔄 ROUND ($current_state.round + 1): Manager requesting revisions..."
    print $"  Feedback: ($review.feedback)"
    print ""

    # Recursive supervision
    $current_state = ($current_state | upsert round ($current_state.round + 1))
    hierarchical-review $crew $current_state

  } else {
    # Final aggregation
    print "📊 PHASE 4: Manager aggregating final report..."
    let final_report = (manager-aggregate $crew.manager $current_state)

    print "  ✓ Final report ready"
    print ""

    print-review-summary $final_report

    {
      ...$current_state
      plan: $plan
      final_report: $final_report
      status: "complete"
    }
  }
}

# Manager creates review plan
def manager-create-plan [manager: record, workers: list, state: record] {
  try {
    # Manager analyzes target and delegates tasks
    let prompt = $"
    You are the ($manager.role).

    Target for review: ($state.target)

    Available workers:
    ($workers | each { |w| $"- ($w.name): ($w.role) - Focus: ($w.focus | str join ', ')" } | str join "\n")

    Create a review plan by assigning specific tasks to each worker.
    Output JSON format: {\"tasks\": [{\"worker\": \"name\", \"task\": \"description\", \"priority\": \"high|medium|low\"}]}
    "

    let plan_json = (call-agent $manager.name $manager.model {
      task: "Create review plan"
      prompt: $prompt
    })

    # Parse plan (placeholder - would actually parse JSON)
    let plan = {
      tasks: [
        {worker: "security-reviewer", task: "Review authentication and authorization", priority: "high"}
        {worker: "performance-reviewer", task: "Analyze algorithm complexity and database queries", priority: "medium"}
        {worker: "maintainability-reviewer", task: "Assess code structure and documentation", priority: "medium"}
      ]
    }

    track-metric "crewai.plan_created" 1 {status: "success", tasks: ($plan.tasks | length)}

    $plan

  } catch { |err|
    print $"⚠️  Planning failed: ($err.msg)"

    # Fallback: simple task distribution
    {
      tasks: $workers | each { |w|
        {worker: $w.name, task: $"Review using ($w.role) expertise", priority: "medium"}
      }
    }
  }
}

# Workers execute their assigned tasks (in parallel)
def workers-execute [workers: list, tasks: list, state: record] {
  $tasks
    | par-each { |task|
        let worker = $workers | where name == $task.worker | first

        print $"  🤖 ($worker.name) working..."

        try {
          let start = (date now)

          # Worker performs review
          let prompt = $"
          You are a ($worker.role).

          Task: ($task.task)
          Target: ($state.target)
          Focus areas: ($worker.focus | str join ', ')

          Perform your review and report findings.
          "

          let result = (call-agent $worker.name $worker.model {
            task: $task.task
            prompt: $prompt
          })

          let duration = ((date now) - $start | into duration | into int)

          # Parse findings
          let findings = (parse-review-findings $result)

          track-metric "crewai.worker_task" 1 {
            worker: $worker.name
            status: "success"
          }

          {
            worker: $worker.name
            task: $task.task
            status: "success"
            findings: $findings
            duration_ms: $duration
          }

        } catch { |err|
          print $"  ⚠️  ($worker.name) failed: ($err.msg)"

          track-metric "crewai.worker_task" 1 {
            worker: $worker.name
            status: "failed"
          }

          {
            worker: $worker.name
            task: $task.task
            status: "failed"
            error: $err.msg
          }
        }
      }
}

# Manager reviews worker outputs
def manager-review [manager: record, state: record] {
  try {
    let worker_results = $state.worker_results
    let successful = $worker_results | where status == "success"

    # Manager evaluates completeness and quality
    let prompt = $"
    You are the ($manager.role).

    Round: ($state.round)
    Target: ($state.target)

    Worker Results:
    ($successful | each { |r| $"($r.worker): Found ($r.findings | length) issues" } | str join "\n")

    Evaluate:
    1. Is the review complete and thorough?
    2. Do any areas need more investigation?
    3. Are the findings consistent and actionable?

    Respond with JSON: {\"decision\": \"complete|needs-revision\", \"feedback\": \"...\", \"reasoning\": \"...\"}
    "

    let decision_json = (call-agent $manager.name $manager.model {
      task: "Review worker outputs"
      prompt: $prompt
    })

    # Parse decision (placeholder)
    let decision = {
      decision: "complete"
      feedback: "All areas adequately covered"
      reasoning: "Workers provided thorough analysis in their domains"
    }

    track-metric "crewai.manager_review" 1 {round: $state.round, decision: $decision.decision}

    $decision

  } catch { |err|
    print $"⚠️  Manager review failed: ($err.msg)"

    # Default to complete
    {
      decision: "complete"
      feedback: "Proceeding with available results"
      reasoning: "Error in review process"
    }
  }
}

# Manager aggregates final report
def manager-aggregate [manager: record, state: record] {
  try {
    let all_findings = $state.worker_results
      | where status == "success"
      | get findings
      | flatten

    # Manager synthesizes findings
    let prompt = $"
    You are the ($manager.role).

    Target: ($state.target)
    Total findings: ($all_findings | length)

    Findings by worker:
    ($state.worker_results | each { |r|
      if $r.status == "success" {
        $"($r.worker): ($r.findings | length) findings"
      } else {
        $"($r.worker): FAILED"
      }
    } | str join "\n")

    Create a final code review report with:
    1. Executive summary
    2. Critical issues (must fix)
    3. Recommendations (should fix)
    4. Overall assessment

    Be concise and actionable.
    "

    let report = (call-agent $manager.name $manager.model {
      task: "Aggregate final report"
      prompt: $prompt
    })

    # Structure report
    let structured = {
      executive_summary: (extract-summary $report)
      critical_issues: ($all_findings | where severity == "critical")
      recommendations: ($all_findings | where severity in ["high" "medium"])
      overall_assessment: (calculate-assessment $all_findings)
      worker_contributions: ($state.worker_results | length)
      total_findings: ($all_findings | length)
    }

    track-metric "crewai.report_generated" 1 {findings: ($all_findings | length)}

    $structured

  } catch { |err|
    print $"⚠️  Aggregation failed: ($err.msg)"

    # Minimal report
    {
      executive_summary: "Review completed with errors"
      error: $err.msg
    }
  }
}

# Parse review findings from worker output
def parse-review-findings [result: string] {
  # Placeholder - would actually parse LLM output
  [
    {
      severity: "high"
      category: "security"
      description: "Missing input validation in user endpoint"
      location: "api/users.py:42"
      recommendation: "Add input sanitization"
    }
    {
      severity: "medium"
      category: "performance"
      description: "N+1 query in user listing"
      location: "models/user.py:67"
      recommendation: "Use eager loading"
    }
  ]
}

# Extract summary from report
def extract-summary [report: string] {
  # Placeholder - would extract from LLM output
  "Code review identified 5 issues: 1 critical, 2 high priority, 2 medium priority. Main concerns are security and performance."
}

# Calculate overall assessment
def calculate-assessment [findings: list] {
  let critical = $findings | where severity == "critical" | length
  let high = $findings | where severity == "high" | length

  if $critical > 0 {
    "Critical issues found - do not merge"
  } else if $high > 2 {
    "Multiple high-priority issues - needs work"
  } else if $high > 0 {
    "Some issues found - address before merging"
  } else {
    "Looks good - approved"
  }
}

# Print review summary
def print-review-summary [report: record] {
  print "📋 REVIEW SUMMARY"
  print "================="
  print ""

  print $"Executive Summary:"
  print $"  ($report.executive_summary)"
  print ""

  print $"Overall Assessment: ($report.overall_assessment)"
  print ""

  print "Findings:"
  print $"  Critical: ($report.critical_issues | length)"
  print $"  Recommendations: ($report.recommendations | length)"
  print $"  Total: ($report.total_findings)"
  print ""

  print $"Worker Contributions: ($report.worker_contributions)"
}

# Helper: Call AI agent
def call-agent [agent: string, model: string, task: record] {
  # Placeholder - would call actual LLM
  $"
  Review findings from ($agent):

  ($task.task)

  Findings:
  1. Security issue in authentication flow
  2. Performance concern with database queries
  3. Missing test coverage for error cases

  Recommendations:
  - Add input validation
  - Optimize query patterns
  - Increase test coverage to 80%
  "
}

# Helper: Log workflow start
def log-workflow-start [state: record] {
  let log_dir = $"($env.HOME)/.config/comr/logs"
  mkdir $log_dir

  let log_entry = {
    timestamp: (date now | date to-record)
    level: "info"
    category: "orchestrator.workflow"
    message: "Starting CrewAI code review"
    context: {
      correlationId: $state.correlationId
      pattern: $state.pattern
      target: $state.target
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
