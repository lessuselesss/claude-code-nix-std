# Nushell Examples - User Templates for Custom Tools
#
# This file demonstrates how to create custom Nushell scripts and integrate
# them into the claude-code-nix-std framework.
#
# Examples show:
# - Basic Nushell scripts
# - Scripts with dependencies
# - Scripts using framework helpers
# - Integration with MCP servers
# - Custom diagnostic tools
# - Custom workspace management

{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};

  # Import Nushell writers from lib cell
  writeNu = inputs.cells.lib.functions.writeNushellScript;
  writeNuApp = inputs.cells.lib.functions.writeNushellApplication;
  helpers = inputs.cells.lib.functions.includeHelpers;
in {
  # Example 1: Simple Nushell script
  # No dependencies, just pure Nushell
  hello-nu = writeNu {
    name = "hello-nu";
    text = ''
      print "Hello from Nushell!"
      print $"Current directory: (pwd)"
      print $"Shell: ($nu.os-info.name)"
    '';
  };

  # Example 2: Script with command-line arguments
  greet = writeNuApp {
    name = "greet";
    runtimeInputs = [];
    text = ''
      def main [name: string, --greeting: string = "Hello"] {
        print $"($greeting), ($name)!"
        print $"Nice to meet you on (date now | format date '%Y-%m-%d')."
      }
    '';
  };

  # Example 3: Script with external dependencies
  # Uses curl and jq from runtime inputs
  fetch-json = writeNuApp {
    name = "fetch-json";
    runtimeInputs = [ pkgs.curl pkgs.jq ];
    text = ''
      def main [url: string] {
        print $"Fetching JSON from: ($url)"

        let data = (
          ^curl -s $url
            | complete
            | get stdout
            | from json
        )

        $data | table -e
      }
    '';
  };

  # Example 4: Using framework helpers
  # Demonstrates log, track-metric, safe-read-json, etc.
  framework-helpers-demo = writeNuApp {
    name = "framework-helpers";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [] {
        # Logging
        log "info" "Starting framework helpers demo"
        log "debug" "This is a debug message"

        # Metrics tracking
        track-metric "demo.execution" 1 {example: "helpers"}

        # Safe file operations
        let config = (safe-read-json "~/.config/comr/config.json" {
          default: "config"
        })

        if "default" in $config {
          print "Config file not found, using default"
        } else {
          print $"Loaded config: ($config.version? | default 'unknown')"
        }

        # Timed operation
        let result = (timed "demo-operation" {
          sleep 1sec
          "Operation complete"
        })

        print $"Result: ($result)"

        log "info" "Framework helpers demo complete"
      }
    '';
  };

  # Example 5: Custom MCP registry search
  # More advanced filtering than the built-in search
  custom-mcp-search = writeNuApp {
    name = "custom-mcp-search";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        --keyword: string        # Search keyword
        --min-ecosystems: int = 2  # Minimum ecosystem compatibility
        --provider: string       # Filter by provider
      ] {
        print "🔍 Custom MCP Server Search"
        print "============================"
        print ""

        # Load registry
        let registry_file = "~/.config/comr/server-registry.json"
        let registry = (safe-read-json $registry_file {})

        if ($registry | is-empty) {
          print "Registry not found. Run: comr mcp sync-registry"
          exit 1
        }

        let servers = $registry.servers

        # Advanced filtering
        let results = (
          $servers
            | transpose name info
            | where {|row|
                # Keyword match
                let keyword_match = if $keyword == null {
                  true
                } else {
                  let kw = ($keyword | str downcase)
                  ($row.name | str downcase | str contains $kw) or
                  ($row.info.description | str downcase | str contains $kw) or
                  ($row.info.keywords | any {|k| ($k | str downcase | str contains $kw)})
                }

                # Ecosystem count
                let eco_count = ($row.info.ecosystems | length)
                let eco_match = $eco_count >= $min_ecosystems

                # Provider match
                let prov_match = if $provider == null {
                  true
                } else {
                  $provider in ($row.info.providers | columns)
                }

                $keyword_match and $eco_match and $prov_match
              }
            | insert ecosystem_count {|row| $row.info.ecosystems | length}
            | insert provider_list {|row| $row.info.providers | columns | str join ", "}
        )

        if ($results | is-empty) {
          print "No servers found matching criteria"
          return
        }

        print $"Found ($results | length) server(s):"
        print ""

        $results
          | sort-by -r ecosystem_count
          | select name ecosystem_count provider_list
          | rename Server "Ecosystems" "Providers"
          | table -e

        print ""
        print "Top capabilities:"
        $results
          | get info.capabilities
          | flatten
          | group-by
          | transpose capability count
          | insert count {|row| $row.count | length}
          | select capability count
          | sort-by -r count
          | first 5
          | table
      }
    '';
  };

  # Example 6: Custom cost analysis tool
  # Analyzes cost patterns across workspaces
  cost-analyzer = writeNuApp {
    name = "cost-analyzer";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        --workspace: string      # Analyze specific workspace
        --threshold: float = 5.0 # Alert threshold (USD)
        --period: string = "week"
      ] {
        print "💰 Cost Analysis"
        print "================"
        print ""

        # Load cost data from logs
        let logs_dir = "~/.config/comr/logs"
        let log_file = ($logs_dir + "/comr.log")

        if not ($log_file | path exists) {
          print "No logs found"
          exit 1
        }

        # Parse cost entries
        let cutoff = match $period {
          "day" => { (date now) - 1day }
          "week" => { (date now) - 7day }
          "month" => { (date now) - 30day }
          _ => { (date now) - 7day }
        }

        let costs = (
          open $log_file
            | lines
            | each {|line| try { $line | from json } catch { null }}
            | where $it != null
            | where context.category? == "llm.request"
            | where ($it.timestamp | into datetime) > $cutoff
            | each {|entry|
                {
                  timestamp: $entry.timestamp
                  model: ($entry.context?.model? | default "unknown")
                  workspace: ($entry.context?.workspace? | default "unknown")
                  cost: ($entry.metadata?.cost? | default 0)
                  tokens_in: ($entry.metadata?.input_tokens? | default 0)
                  tokens_out: ($entry.metadata?.output_tokens? | default 0)
                }
              }
        )

        # Filter by workspace
        let filtered = if $workspace == null {
          $costs
        } else {
          $costs | where workspace == $workspace
        }

        if ($filtered | is-empty) {
          print "No cost data available"
          return
        }

        # Analysis
        let total = ($filtered | get cost | math sum)
        let avg = ($filtered | get cost | math avg)
        let max_cost = ($filtered | get cost | math max)

        print "Summary:"
        print $"  Total Cost: \$($total | into string)"
        print $"  Average per Request: \$($avg | into string)"
        print $"  Max Single Request: \$($max_cost | into string)"
        print $"  Total Requests: ($filtered | length)"
        print ""

        # Cost by workspace
        if $workspace == null {
          print "Cost by Workspace:"
          $filtered
            | group-by workspace
            | transpose workspace costs
            | insert total {|row| $row.costs | get cost | math sum}
            | insert count {|row| $row.costs | length}
            | select workspace count total
            | rename Workspace Requests "Total ($)"
            | sort-by -r "Total ($)"
            | table
          print ""
        }

        # Cost by model
        print "Cost by Model:"
        $filtered
          | group-by model
          | transpose model costs
          | insert total {|row| $row.costs | get cost | math sum}
          | insert count {|row| $row.costs | length}
          | select model count total
          | rename Model Requests "Total ($)"
          | sort-by -r "Total ($)"
          | table
        print ""

        # Alerts
        let over_threshold = (
          $filtered
            | where cost > $threshold
        )

        if ($over_threshold | length) > 0 {
          print $"⚠️  ($over_threshold | length) request(s) exceeded threshold of \$($threshold):"
          $over_threshold
            | select timestamp workspace model cost
            | rename Time Workspace Model "Cost ($)"
            | table
        }
      }
    '';
  };

  # Example 7: Custom session cleanup
  # More sophisticated cleanup than the built-in
  smart-session-cleanup = writeNuApp {
    name = "smart-session-cleanup";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        --dry-run               # Show what would be deleted without deleting
        --max-age: int = 30     # Max age in days
        --keep-recent: int = 5  # Keep N most recent per workspace
      ] {
        print "🧹 Smart Session Cleanup"
        print "======================="
        print ""

        if $dry_run {
          print "DRY RUN MODE - No sessions will be deleted"
          print ""
        }

        # Load all sessions
        let base_dir = $"($env.HOME)/.cache/comr/workspaces"

        let all_sessions = (
          glob ($base_dir + "/**/.comr-workspace-state.json")
            | each {|state_file|
                try {
                  let state = (open $state_file | from json)
                  {
                    file: $state_file
                    sessionId: $state.sessionId
                    workspace: $state.workspaceName
                    started: ($state.startTime | into datetime)
                    lastActivity: ($state.lastActivity | into datetime)
                    status: ($state.status? | default "active")
                    age_days: (((date now) - ($state.lastActivity | into datetime)) | into int) / 86400000000000
                  }
                } catch {
                  null
                }
              }
            | where $it != null
        )

        print $"Found ($all_sessions | length) total session(s)"
        print ""

        # Determine what to keep
        let by_workspace = ($all_sessions | group-by workspace)

        let to_keep = (
          $by_workspace
            | transpose workspace sessions
            | each {|row|
                # Keep N most recent per workspace
                $row.sessions
                  | sort-by -r lastActivity
                  | first $keep_recent
                  | get sessionId
              }
            | flatten
        )

        # Determine what to delete
        let to_delete = (
          $all_sessions
            | where {|sess|
                # Delete if:
                # 1. Completed AND older than max_age
                # 2. NOT in the keep-recent list
                let too_old = $sess.age_days > $max_age
                let not_recent = not ($sess.sessionId in $to_keep)
                let is_completed = $sess.status == "completed"

                ($too_old and $is_completed) or ($not_recent and $too_old)
              }
        )

        if ($to_delete | is-empty) {
          print "✅ No sessions to clean up"
          return
        }

        print $"Sessions to delete: ($to_delete | length)"
        print ""

        $to_delete
          | select workspace sessionId age_days status
          | rename Workspace "Session ID" "Age (days)" Status
          | table

        if not $dry_run {
          print ""
          print "Deleting sessions..."

          for session in $to_delete {
            let session_dir = ($session.file | path dirname)
            print $"  Removing: ($session.sessionId | str substring 0..8)..."

            try {
              rm -rf $session_dir
            } catch { |err|
              log "error" $"Failed to delete ($session.sessionId): ($err.msg)"
            }
          }

          print ""
          print $"✅ Deleted ($to_delete | length) session(s)"
        } else {
          print ""
          print "Run without --dry-run to actually delete these sessions"
        }
      }
    '';
  };

  # Example 8: Custom workspace report
  # Generate comprehensive workspace usage report
  workspace-report = writeNuApp {
    name = "workspace-report";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        --format: string = "terminal"  # terminal, json, markdown
        --output: string               # Output file
      ] {
        log "info" "Generating workspace report"

        # Gather data
        let sessions = (gather-session-data)
        let costs = (gather-cost-data)
        let registry = (gather-registry-data)

        # Build report
        let report = {
          generated: (date now | date to-record)
          summary: {
            total_sessions: ($sessions | length)
            active_sessions: ($sessions | where status == "active" | length)
            total_cost: ($costs | get cost | math sum)
            unique_workspaces: ($sessions | get workspace | uniq | length)
          }
          sessions_by_workspace: (
            $sessions
              | group-by workspace
              | transpose workspace sessions
              | insert count {|row| $row.sessions | length}
              | select workspace count
          )
          cost_by_workspace: (
            $costs
              | group-by workspace
              | transpose workspace costs
              | insert total {|row| $row.costs | get cost | math sum}
              | select workspace total
          )
          mcp_registry: {
            total_servers: ($registry | length)
            by_ecosystem: (
              $registry
                | get ecosystems
                | flatten
                | group-by
                | transpose ecosystem count
                | insert count {|row| $row.count | length}
                | select ecosystem count
            )
          }
        }

        # Format output
        match $format {
          "json" => {
            let json_output = ($report | to json)
            if $output == null {
              print $json_output
            } else {
              $json_output | save -f $output
              print $"Report saved to: ($output)"
            }
          }
          "markdown" => {
            let md = (format-markdown $report)
            if $output == null {
              print $md
            } else {
              $md | save -f $output
              print $"Report saved to: ($output)"
            }
          }
          _ => {
            print "📊 Workspace Report"
            print "==================="
            print ""
            print "Summary:"
            print $"  Total Sessions: ($report.summary.total_sessions)"
            print $"  Active: ($report.summary.active_sessions)"
            print $"  Total Cost: \$($report.summary.total_cost | into string)"
            print $"  Unique Workspaces: ($report.summary.unique_workspaces)"
            print ""

            print "Sessions by Workspace:"
            $report.sessions_by_workspace | table
            print ""

            print "Cost by Workspace:"
            $report.cost_by_workspace | table
          }
        }
      }

      # Helper: Gather session data
      def gather-session-data [] {
        let base_dir = $"($env.HOME)/.cache/comr/workspaces"
        glob ($base_dir + "/**/.comr-workspace-state.json")
          | each {|f| try { open $f | from json } catch { null }}
          | where $it != null
          | each {|s| {
              sessionId: $s.sessionId
              workspace: $s.workspaceName
              status: ($s.status? | default "active")
              started: $s.startTime
            }}
      }

      # Helper: Gather cost data
      def gather-cost-data [] {
        let log_file = "~/.config/comr/logs/comr.log"
        if not ($log_file | path exists) { return [] }

        open $log_file
          | lines
          | each {|line| try { $line | from json } catch { null }}
          | where $it != null
          | where context.category? == "llm.request"
          | each {|e| {
              workspace: ($e.context?.workspace? | default "unknown")
              cost: ($e.metadata?.cost? | default 0)
            }}
      }

      # Helper: Gather registry data
      def gather-registry-data [] {
        let registry_file = "~/.config/comr/server-registry.json"
        if not ($registry_file | path exists) { return [] }

        let registry = (open $registry_file | from json)
        $registry.servers
          | transpose name info
          | get info
      }

      # Helper: Format as markdown
      def format-markdown [report: record] {
        $"# Workspace Report

Generated: ($report.generated)

## Summary

- Total Sessions: ($report.summary.total_sessions)
- Active: ($report.summary.active_sessions)
- Total Cost: \$($report.summary.total_cost)
- Unique Workspaces: ($report.summary.unique_workspaces)

## Sessions by Workspace

| Workspace | Count |
|-----------|-------|
($report.sessions_by_workspace | each {|row| $"| ($row.workspace) | ($row.count) |"} | str join "\\n")

## Cost by Workspace

| Workspace | Total |
|-----------|-------|
($report.cost_by_workspace | each {|row| $"| ($row.workspace) | \$($row.total) |"} | str join "\\n")
"
      }
    '';
  };

  # Example 9: Template for creating custom Nushell tools
  # Copy and modify this template for your own tools
  custom-tool-template = writeNuApp {
    name = "custom-tool-template";
    runtimeInputs = [];  # Add pkgs.curl, pkgs.jq, etc. as needed
    text = ''
      # Include framework helpers for logging, metrics, etc.
      ${helpers}

      # Main entry point
      # Define your command-line arguments here
      def main [
        arg1: string                # Required argument
        --option1: string           # Optional flag
        --option2: int = 42         # Optional with default
        --flag                      # Boolean flag
      ] {
        # Log start
        log "info" $"Starting custom tool with arg1=($arg1)"

        # Your logic here
        print $"Processing with option1: ($option1? | default 'not set')"
        print $"Option2 value: ($option2)"
        print $"Flag set: ($flag)"

        # Use framework helpers
        let result = (timed "custom-operation" {
          # Your operation here
          sleep 1sec
          "Operation result"
        })

        # Track metrics
        track-metric "custom.tool.execution" 1 {arg1: $arg1}

        # Log completion
        log "info" "Custom tool completed"

        # Return or display result
        print $"Result: ($result)"
      }

      # Helper functions (define as many as needed)
      def helper-function [] {
        # Helper logic
      }
    '';
  };
}
