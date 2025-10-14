# Workspaces Cell - Composed Agent Environments

## Purpose

High-level workspace compositions that combine agents, MCP servers, prompts, and orchestration patterns. Provides pre-configured environments for common workflows.

## Key Features

- **Composition**: Combine multiple cells into cohesive environments
- **Pre-built**: Ready-to-use workspaces (python-dev, web-dev, etc.)
- **Extensible**: Users can create custom workspaces
- **Backward Compatible**: Maintains current workspace interface

## Three-Layer API

**Layer 1:**
```nix
workspaces.use "python-dev" "implement feature"
workspaces.use "full-stack" "build app"
```

**Layer 2:**
```nix
workspaces.compose {
  agents = [claude gemini];
  servers = ["git" "postgres"];
  orchestration = "langgraph";
  prompts = ["code-review"];
}
```

**Layer 3:**
```nix
workspaces.build {
  name = "custom";
  components = {...};
  lifecycle = {...};
}
```

## Files

```
cells/workspaces/
├── CLAUDE.md
├── lib.nix          # Workspace composition API
├── data.nix         # Pre-built workspaces
└── runnables.nix    # Workspace runners
```

## Implementation Plan

### Phase 1: Workspace Definitions (Week 6, Days 1-2)

**data.nix:**
```nix
{
  workspaces = {
    python-dev = {
      agent = "claude-code";
      servers = ["git" "sequential-thinking" "sqlite" "filesystem"];
      prompts = [];
      orchestration = null;
    };

    full-stack = {
      agents = ["claude-code" "gemini-cli"];
      servers = ["git" "postgres" "playwright" "github"];
      prompts = ["code-review" "security-audit"];
      orchestration = "langgraph";
    };

    # ... more workspaces
  };
}
```

### Phase 2: Composition API (Week 6, Days 3-5)

**lib.nix:**
```nix
{
  use = name: task:
    let ws = cell.data.workspaces.${name};
    in compose ws task;

  compose = { agents, servers, orchestration ? null, prompts ? [] }: task:
    if orchestration != null
    then inputs.cells.orchestrators.lib.${orchestration} agents task
    else inputs.cells.agents.${agents}.lib.useWorkspace servers task;

  build = { name, components, lifecycle }:
    # Custom workspace builder
}
```

### Phase 3: Runnable Workspaces (Week 6, Days 6-7)

**runnables.nix:**
```nix
{
  python-dev = # From agents/claude-code
  full-stack = # Orchestrated multi-agent
  # ... all workspace runners
}
```

## Dependencies

- Inputs: ALL cells
- Consumes: `agents/*`, `mcp`, `orchestrators`, `prompts`
- Produces for: User-facing interface

### Phase 4: Lifecycle Management (Week 7, Days 1-3)

Workspaces need proper lifecycle management for initialization, state persistence, session continuation, and cleanup.

#### Lifecycle Stages

```nix
# data.nix - Lifecycle hooks
{
  lifecycleHooks = {
    onInit = {
      description = "Called when workspace is initialized";
      params = ["workspace" "config"];
    };

    onStart = {
      description = "Called before task execution";
      params = ["workspace" "task"];
    };

    onComplete = {
      description = "Called after successful task completion";
      params = ["workspace" "result"];
    };

    onError = {
      description = "Called when task fails";
      params = ["workspace" "error"];
    };

    onCleanup = {
      description = "Called during workspace teardown";
      params = ["workspace"];
    };

    onSuspend = {
      description = "Called when session is suspended";
      params = ["workspace" "state"];
    };

    onResume = {
      description = "Called when session is resumed";
      params = ["workspace" "state"];
    };
  };

  # Workspace state schema
  stateSchema = {
    sessionId = "uuid";
    workspaceName = "string";
    startTime = "timestamp";
    lastActivity = "timestamp";

    context = {
      cwd = "path";
      environment = "object";
      mcpServers = "object";
      agents = "array";
    };

    history = {
      tasks = "array";
      results = "array";
      costs = "number";
      duration = "number";
    };

    resources = {
      tempFiles = "array";
      processes = "array";
      connections = "array";
    };

    checkpoint = {
      enabled = "boolean";
      path = "path";
      interval = "number";
    };
  };
}
```

#### Initialization

```nix
# lib.nix - Workspace initialization
{
  # Initialize workspace
  init = name: config:
    let
      workspace = cell.data.workspaces.${name};

      # Generate session ID
      sessionId = generateSessionId {};

      # Create workspace directory
      workspaceDir = createWorkspaceDir name sessionId;

      # Initialize state
      state = {
        inherit sessionId;
        workspaceName = name;
        startTime = getCurrentTimestamp {};
        lastActivity = getCurrentTimestamp {};

        context = {
          cwd = builtins.getEnv "PWD";
          environment = builtins.getEnv {};
          mcpServers = workspace.servers;
          agents = workspace.agents or [];
        };

        history = {
          tasks = [];
          results = [];
          costs = 0.0;
          duration = 0.0;
        };

        resources = {
          tempFiles = [];
          processes = [];
          connections = [];
        };

        checkpoint = {
          enabled = config.checkpointing or false;
          path = "${workspaceDir}/checkpoints";
          interval = config.checkpointInterval or 300;  # 5 minutes
        };
      };

      # Call onInit hook
      cell.functions.callHook "onInit" workspace state;

      # Save initial state
      cell.functions.saveState state;
    in state;

  # Generate unique session ID
  generateSessionId = {}:
    let
      timestamp = getCurrentTimestamp {};
      random = builtins.readFile (pkgs.runCommand "random" {} ''
        head -c 16 /dev/urandom | ${pkgs.coreutils}/bin/od -An -tx1 | tr -d ' \n' > $out
      '');
    in "${timestamp}-${random}";

  # Create workspace directory
  createWorkspaceDir = name: sessionId:
    let
      baseDir = "${builtins.getEnv "HOME"}/.cache/comr/workspaces";
      workspaceDir = "${baseDir}/${name}/${sessionId}";
    in pkgs.runCommand "create-workspace-dir" {} ''
      mkdir -p ${workspaceDir}/{state,checkpoints,logs,temp}
      echo ${workspaceDir} > $out
    '';
}
```

#### State Management

```nix
# functions.nix - State persistence
{
  # Save workspace state
  saveState = state:
    let
      stateFile = "${state.context.cwd}/.comr-workspace-state.json";
    in pkgs.writeText stateFile (builtins.toJSON state);

  # Load workspace state
  loadState = sessionId:
    let
      stateFile = findStateFile sessionId;
    in
      if builtins.pathExists stateFile
      then builtins.fromJSON (builtins.readFile stateFile)
      else null;

  # Find state file by session ID
  findStateFile = sessionId:
    let
      baseDir = "${builtins.getEnv "HOME"}/.cache/comr/workspaces";
      # Search all workspace dirs for matching sessionId
      matches = pkgs.runCommand "find-state" {} ''
        find ${baseDir} -name ".comr-workspace-state.json" \
          -exec grep -l "\"sessionId\": \"${sessionId}\"" {} \; \
          > $out
      '';
    in builtins.head (builtins.split "\n" (builtins.readFile matches));

  # Update state
  updateState = state: updates:
    let
      newState = pkgs.lib.recursiveUpdate state (updates // {
        lastActivity = getCurrentTimestamp {};
      });
    in saveState newState;

  # Create checkpoint
  createCheckpoint = state:
    let
      checkpointFile = "${state.checkpoint.path}/checkpoint-${getCurrentTimestamp {}}.json";
    in
      pkgs.writeText checkpointFile (builtins.toJSON state);

  # Restore from checkpoint
  restoreCheckpoint = checkpointFile:
    builtins.fromJSON (builtins.readFile checkpointFile);
}
```

#### Session Continuation

```nix
# lib.nix - Session continuation API
{
  # Continue existing session
  continue = sessionId: task:
    let
      # Load previous state
      state = cell.functions.loadState sessionId;

      # Validate state exists
      _ = if state == null
          then throw "Session ${sessionId} not found"
          else {};

      # Call onResume hook
      cell.functions.callHook "onResume" state.workspaceName state;

      # Execute task with restored context
      result = executeWithState state task;

      # Update state with new task
      newState = cell.functions.updateState state {
        history = {
          tasks = state.history.tasks ++ [task];
          results = state.history.results ++ [result];
        };
      };
    in result;

  # Execute task with existing state
  executeWithState = state: task:
    let
      workspace = cell.data.workspaces.${state.workspaceName};

      # Restore environment
      env = state.context.environment;

      # Reconnect MCP servers
      mcpServers = cell.functions.reconnectMcpServers state.context.mcpServers;

      # Execute task
      result = inputs.cells.agents.${workspace.agent}.lib.execute {
        inherit task mcpServers env;
        context = state.history;
      };
    in result;

  # List active sessions
  listSessions = {}:
    let
      baseDir = "${builtins.getEnv "HOME"}/.cache/comr/workspaces";
      stateFiles = pkgs.runCommand "list-sessions" {} ''
        find ${baseDir} -name ".comr-workspace-state.json" > $out
      '';

      sessions = builtins.map (file:
        let state = builtins.fromJSON (builtins.readFile file);
        in {
          sessionId = state.sessionId;
          workspace = state.workspaceName;
          startTime = state.startTime;
          lastActivity = state.lastActivity;
          taskCount = builtins.length state.history.tasks;
        }
      ) (builtins.split "\n" (builtins.readFile stateFiles));
    in sessions;

  # Resume most recent session
  resumeLatest = workspace:
    let
      sessions = listSessions {};
      workspaceSessions = builtins.filter (s: s.workspace == workspace) sessions;
      sorted = builtins.sort (a: b: a.lastActivity > b.lastActivity) workspaceSessions;
      latest = builtins.head sorted;
    in continue latest.sessionId;
}
```

#### Resource Management

```nix
# functions.nix - Resource tracking and cleanup
{
  # Track temporary file
  trackTempFile = state: path:
    cell.functions.updateState state {
      resources = {
        tempFiles = state.resources.tempFiles ++ [path];
      };
    };

  # Track process
  trackProcess = state: pid:
    cell.functions.updateState state {
      resources = {
        processes = state.resources.processes ++ [pid];
      };
    };

  # Track MCP connection
  trackConnection = state: connection:
    cell.functions.updateState state {
      resources = {
        connections = state.resources.connections ++ [connection];
      };
    };

  # Cleanup resources
  cleanupResources = state:
    let
      # Remove temp files
      _ = builtins.map (file:
        pkgs.runCommand "remove-temp" {} ''rm -f ${file}''
      ) state.resources.tempFiles;

      # Kill processes
      _ = builtins.map (pid:
        pkgs.runCommand "kill-process" {} ''kill -TERM ${builtins.toString pid} 2>/dev/null || true''
      ) state.resources.processes;

      # Close connections
      _ = builtins.map (conn:
        cell.functions.closeMcpConnection conn
      ) state.resources.connections;

      # Log cleanup
      _ = inputs.cells.diagnostics.lib.logInfo "Cleaned up resources for session ${state.sessionId}";
    in state;

  # Close MCP connection
  closeMcpConnection = connection:
    # Send shutdown signal to MCP server
    pkgs.runCommand "close-mcp" {} ''
      kill -TERM ${builtins.toString connection.pid} 2>/dev/null || true
    '';

  # Reconnect MCP servers
  reconnectMcpServers = mcpServers:
    # Re-establish MCP connections from saved state
    builtins.mapAttrs (name: config:
      inputs.cells.mcp.lib.connect name config
    ) mcpServers;
}
```

#### Cleanup and Teardown

```nix
# lib.nix - Workspace cleanup
{
  # Graceful shutdown
  shutdown = state:
    let
      # Call onCleanup hook
      _ = cell.functions.callHook "onCleanup" state.workspaceName state;

      # Cleanup resources
      _ = cell.functions.cleanupResources state;

      # Save final state
      _ = cell.functions.saveState (state // {
        endTime = getCurrentTimestamp {};
        status = "completed";
      });

      # Archive workspace data
      _ = cell.functions.archiveWorkspace state;

      # Log metrics
      _ = inputs.cells.diagnostics.lib.trackMetric {
        name = "workspace.session_duration";
        value = state.history.duration;
        labels = ["workspace=${state.workspaceName}"];
      };

      _ = inputs.cells.diagnostics.lib.trackCost {
        model = "unknown";  # Aggregate from history
        inputTokens = sumInputTokens state.history;
        outputTokens = sumOutputTokens state.history;
        workspace = state.workspaceName;
      };
    in {};

  # Archive workspace data
  archiveWorkspace = state:
    let
      archiveDir = "${builtins.getEnv "HOME"}/.cache/comr/archives";
      archiveName = "${state.workspaceName}-${state.sessionId}.tar.gz";
    in pkgs.runCommand "archive-workspace" {} ''
      mkdir -p ${archiveDir}
      tar -czf ${archiveDir}/${archiveName} \
        -C ${state.checkpoint.path} . \
        ${state.context.cwd}/.comr-workspace-state.json
    '';

  # Emergency cleanup (for unexpected shutdowns)
  emergencyCleanup = {}:
    let
      # Find all active sessions
      sessions = listSessions {};

      # Kill orphaned processes
      orphanedProcesses = pkgs.runCommand "find-orphans" {} ''
        pgrep -f "comr-workspace" > $out
      '';

      _ = builtins.map (pid:
        pkgs.runCommand "kill-orphan" {} ''kill -KILL ${pid} 2>/dev/null || true''
      ) (builtins.split "\n" (builtins.readFile orphanedProcesses));

      # Remove stale temp files
      _ = pkgs.runCommand "cleanup-temp" {} ''
        find /tmp -name "comr-*" -mtime +1 -delete
      '';

      # Log cleanup
      _ = inputs.cells.diagnostics.lib.logWarning "Emergency cleanup performed";
    in {};
}
```

#### Workspace Templates

```nix
# data.nix - Reusable templates
{
  templates = {
    basic = {
      description = "Minimal workspace with essential tools";
      servers = ["git" "sequential-thinking"];
      prompts = [];
      lifecycle = {
        checkpointing = false;
      };
    };

    data-science = {
      description = "Data science workspace with notebook support";
      servers = ["git" "sequential-thinking" "jupyter" "postgres" "sqlite"];
      prompts = ["data-analysis"];
      lifecycle = {
        checkpointing = true;
        checkpointInterval = 600;  # 10 minutes
      };
    };

    full-featured = {
      description = "Full-featured workspace with all tools";
      servers = ["git" "sequential-thinking" "filesystem" "postgres" "github" "playwright"];
      prompts = ["code-review" "security-audit" "performance-optimization"];
      lifecycle = {
        checkpointing = true;
        checkpointInterval = 300;  # 5 minutes
        autoArchive = true;
      };
    };
  };

  # Create workspace from template
  fromTemplate = templateName: overrides:
    let
      template = cell.data.templates.${templateName};
    in pkgs.lib.recursiveUpdate template overrides;
}
```

#### Dynamic Composition

```nix
# lib.nix - Runtime composition
{
  # Add MCP server to running workspace
  addServer = state: serverName:
    let
      server = inputs.cells.mcp.lib.getServer serverName;
      connection = inputs.cells.mcp.lib.connect serverName server;

      newState = cell.functions.updateState state {
        context = {
          mcpServers = state.context.mcpServers // {
            ${serverName} = server;
          };
        };
        resources = {
          connections = state.resources.connections ++ [connection];
        };
      };
    in newState;

  # Remove MCP server from running workspace
  removeServer = state: serverName:
    let
      connection = builtins.find (c: c.name == serverName) state.resources.connections;
      _ = cell.functions.closeMcpConnection connection;

      newState = cell.functions.updateState state {
        context = {
          mcpServers = builtins.removeAttrs state.context.mcpServers [serverName];
        };
        resources = {
          connections = builtins.filter (c: c.name != serverName) state.resources.connections;
        };
      };
    in newState;

  # Switch agent in running workspace
  switchAgent = state: newAgent:
    let
      newState = cell.functions.updateState state {
        context = {
          agents = [newAgent];
        };
      };
    in newState;

  # Merge two workspaces
  merge = state1: state2:
    let
      merged = {
        sessionId = generateSessionId {};
        workspaceName = "${state1.workspaceName}+${state2.workspaceName}";
        startTime = getCurrentTimestamp {};

        context = {
          cwd = state1.context.cwd;
          environment = pkgs.lib.recursiveUpdate state1.context.environment state2.context.environment;
          mcpServers = state1.context.mcpServers // state2.context.mcpServers;
          agents = state1.context.agents ++ state2.context.agents;
        };

        history = {
          tasks = state1.history.tasks ++ state2.history.tasks;
          results = state1.history.results ++ state2.history.results;
          costs = state1.history.costs + state2.history.costs;
        };

        resources = {
          tempFiles = state1.resources.tempFiles ++ state2.resources.tempFiles;
          processes = state1.resources.processes ++ state2.resources.processes;
          connections = state1.resources.connections ++ state2.resources.connections;
        };
      };
    in cell.functions.saveState merged;
}
```

#### Lifecycle Tools

```nix
# runnables.nix - Lifecycle management tools
{
  # List active sessions
  sessions = pkgs.writeShellScriptBin "comr-sessions" ''
    #!/usr/bin/env bash
    echo "📋 Active Workspace Sessions"
    echo "=========================="

    SESSIONS=$(nix eval --json '.#workspaces.lib.listSessions' --apply 'f: f {}')

    echo "$SESSIONS" | ${pkgs.jq}/bin/jq -r '.[] | "\(.sessionId) | \(.workspace) | \(.taskCount) tasks | Last: \(.lastActivity)"'
  '';

  # Resume session
  resume = pkgs.writeShellScriptBin "comr-resume" ''
    #!/usr/bin/env bash
    SESSION_ID="$1"
    TASK="$2"

    echo "🔄 Resuming session: $SESSION_ID"

    nix eval '.#workspaces.lib.continue' --apply "f: f \"$SESSION_ID\" \"$TASK\""
  '';

  # Cleanup sessions
  cleanup = pkgs.writeShellScriptBin "comr-cleanup" ''
    #!/usr/bin/env bash
    echo "🧹 Cleaning up workspace sessions..."

    # Emergency cleanup
    nix eval '.#workspaces.lib.emergencyCleanup' --apply 'f: f {}'

    echo "✅ Cleanup complete"
  '';

  # Archive old sessions
  archive = pkgs.writeShellScriptBin "comr-archive" ''
    #!/usr/bin/env bash
    DAYS_OLD="''${1:-7}"

    echo "📦 Archiving sessions older than $DAYS_OLD days..."

    # Find old sessions
    find "$HOME/.cache/comr/workspaces" -name ".comr-workspace-state.json" -mtime +$DAYS_OLD \
      -exec dirname {} \; | while read -r dir; do
        SESSION_ID=$(basename "$dir")
        nix eval '.#workspaces.lib.archiveWorkspace' --apply "f: f \"$SESSION_ID\""
      done

    echo "✅ Archive complete"
  '';
}
```

### Phase 5: Nushell Integration for Session Management (Week 7, Days 4-7)

**Rationale:** Workspace session management involves inspecting JSON state files, filtering sessions, displaying tables, and aggregating statistics. Nushell's native structured data handling makes these operations clean and intuitive.

**Commands to Convert:**
- `sessions` / `list-sessions` - Rich session listing with filtering and sorting
- `show-session` - Detailed session inspection with state visualization
- `session-stats` - Aggregate statistics across sessions
- `compare-sessions` - Compare multiple session states

**Keep Bash:**
- `resume` - Integrates with nix eval (bash is fine)
- `cleanup` - Process killing and file deletion (bash is better)
- `archive` - File operations with find (bash is better)

**runnables.nix - Nushell Version:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
  writeNuApp = inputs.cells.lib.functions.writeNushellApplication;
  helpers = inputs.cells.lib.functions.includeHelpers;
in {
  # Nushell: Rich session listing
  sessions = writeNuApp {
    name = "comr-sessions";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        --workspace: string      # Filter by workspace
        --active                 # Show only active sessions
        --since: string = "7day" # Sessions since timeframe
        --sort-by: string = "lastActivity"  # Sort field
      ] {
        print "📋 Workspace Sessions"
        print "===================="
        print ""

        # Find all session state files
        let base_dir = $"($env.HOME)/.cache/comr/workspaces"

        if not ($base_dir | path exists) {
          print "No sessions found"
          return
        }

        # Load all session states
        let sessions = (
          glob ($base_dir + "/**/.comr-workspace-state.json")
            | each {|state_file|
                try {
                  let state = (open $state_file | from json)
                  {
                    sessionId: $state.sessionId
                    workspace: $state.workspaceName
                    status: ($state.status? | default "active")
                    started: ($state.startTime | into datetime)
                    lastActivity: ($state.lastActivity | into datetime)
                    tasks: ($state.history.tasks | length)
                    cost: ($state.history.costs? | default 0)
                    duration: ($state.history.duration? | default 0)
                    agents: ($state.context.agents | length)
                    servers: ($state.context.mcpServers | length)
                  }
                } catch {
                  null
                }
              }
            | where $it != null
        )

        if ($sessions | is-empty) {
          print "No sessions found"
          return
        }

        # Apply filters
        let filtered = (
          $sessions
            | where {|sess|
                let ws_match = if $workspace == null { true } else { $sess.workspace == $workspace }
                let active_match = if $active { $sess.status == "active" } else { true }
                let time_match = $sess.lastActivity > ((date now) - ($since | into duration))

                $ws_match and $active_match and $time_match
              }
        )

        if ($filtered | is-empty) {
          print "No matching sessions"
          return
        }

        # Sort and display
        let sorted = match $sort_by {
          "lastActivity" => { $filtered | sort-by -r lastActivity }
          "started" => { $filtered | sort-by -r started }
          "tasks" => { $filtered | sort-by -r tasks }
          "cost" => { $filtered | sort-by -r cost }
          _ => { $filtered }
        }

        print $"Found ($sorted | length) session(s):"
        print ""

        $sorted
          | each {|sess|
              {
                "Session ID": ($sess.sessionId | str substring 0..8)
                Workspace: $sess.workspace
                Status: $sess.status
                "Last Activity": ($sess.lastActivity | format date "%Y-%m-%d %H:%M")
                Tasks: $sess.tasks
                "Cost ($)": ($sess.cost | into string)
              }
            }
          | table -e

        print ""
        print "Totals:"
        print $"  Sessions: ($sorted | length)"
        print $"  Total tasks: ($sorted | get tasks | math sum)"
        print $"  Total cost: \$($sorted | get cost | math sum | into string)"
      }
    '';
  };

  # Nushell: Show detailed session info
  show-session = writeNuApp {
    name = "comr-session-show";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        session_id: string  # Session ID (full or partial)
      ] {
        # Find matching session
        let base_dir = $"($env.HOME)/.cache/comr/workspaces"

        let matches = (
          glob ($base_dir + "/**/.comr-workspace-state.json")
            | each {|state_file|
                try {
                  let state = (open $state_file | from json)
                  if ($state.sessionId | str starts-with $session_id) {
                    {file: $state_file, state: $state}
                  } else {
                    null
                  }
                } catch {
                  null
                }
              }
            | where $it != null
        )

        if ($matches | is-empty) {
          print $"Session not found: ($session_id)"
          exit 1
        }

        if ($matches | length) > 1 {
          print $"Multiple sessions match '($session_id)'. Please be more specific:"
          $matches
            | each {|m| $m.state.sessionId}
            | each { print $"  ($in)" }
          exit 1
        }

        let session = ($matches | first)
        let state = $session.state

        # Display session details
        print "📋 Session Details"
        print "================="
        print ""

        print $"Session ID: ($state.sessionId)"
        print $"Workspace: ($state.workspaceName)"
        print $"Status: ($state.status? | default 'active')"
        print ""

        print "Timeline:"
        print $"  Started: ($state.startTime | into datetime | format date '%Y-%m-%d %H:%M:%S')"
        print $"  Last Activity: ($state.lastActivity | into datetime | format date '%Y-%m-%d %H:%M:%S')"
        if "endTime" in $state {
          print $"  Ended: ($state.endTime | into datetime | format date '%Y-%m-%d %H:%M:%S')"
        }
        print ""

        # Context
        print "Context:"
        print $"  Working Directory: ($state.context.cwd)"
        print $"  Agents: ($state.context.agents | length)"
        print $"  MCP Servers: ($state.context.mcpServers | transpose name info | get name | str join ', ')"
        print ""

        # History
        print "History:"
        print $"  Tasks Completed: ($state.history.tasks | length)"
        print $"  Total Cost: \$($state.history.costs? | default 0)"
        print $"  Duration: ($state.history.duration? | default 0) seconds"
        print ""

        # Resources
        print "Resources:"
        print $"  Temp Files: ($state.resources.tempFiles | length)"
        print $"  Processes: ($state.resources.processes | length)"
        print $"  Connections: ($state.resources.connections | length)"
        print ""

        # Recent tasks
        if ($state.history.tasks | length) > 0 {
          print "Recent Tasks:"
          $state.history.tasks
            | last 5
            | enumerate
            | each {|item|
                print $"  ($item.index + 1). ($item.item)"
              }
          print ""
        }

        # Checkpoints
        if $state.checkpoint.enabled {
          print "Checkpoints:"
          print $"  Enabled: Yes"
          print $"  Path: ($state.checkpoint.path)"
          print $"  Interval: ($state.checkpoint.interval)s"

          if ($state.checkpoint.path | path exists) {
            let checkpoint_count = (ls ($state.checkpoint.path + "/*.json") | length)
            print $"  Available: ($checkpoint_count)"
          }
        } else {
          print "Checkpoints: Disabled"
        }
      }
    '';
  };

  # Nushell: Session statistics
  session-stats = writeNuApp {
    name = "comr-session-stats";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        --workspace: string      # Filter by workspace
        --period: string = "all" # all, day, week, month
      ] {
        print "📊 Session Statistics"
        print "===================="
        print ""

        # Load all sessions
        let base_dir = $"($env.HOME)/.cache/comr/workspaces"

        let all_sessions = (
          glob ($base_dir + "/**/.comr-workspace-state.json")
            | each {|state_file|
                try {
                  open $state_file | from json
                } catch {
                  null
                }
              }
            | where $it != null
        )

        # Filter by workspace
        let sessions = if $workspace == null {
          $all_sessions
        } else {
          $all_sessions | where workspaceName == $workspace
        }

        # Filter by period
        let cutoff = match $period {
          "day" => { (date now) - 1day }
          "week" => { (date now) - 7day }
          "month" => { (date now) - 30day }
          _ => { (date now) - 365day }
        }

        let filtered = (
          $sessions
            | where ($it.startTime | into datetime) > $cutoff
        )

        if ($filtered | is-empty) {
          print "No sessions found"
          return
        }

        # Overall stats
        print "Overall:"
        print $"  Total Sessions: ($filtered | length)"
        print $"  Active: ($filtered | where ($it.status? | default 'active') == 'active' | length)"
        print $"  Completed: ($filtered | where ($it.status? | default 'active') == 'completed' | length)"
        print ""

        # Task stats
        let total_tasks = ($filtered | get history.tasks | each { length } | math sum)
        let avg_tasks = ($total_tasks / ($filtered | length) | math round)
        print "Tasks:"
        print $"  Total: ($total_tasks)"
        print $"  Average per session: ($avg_tasks)"
        print ""

        # Cost stats
        let total_cost = ($filtered | get history.costs | each { $in | default 0 } | math sum)
        let avg_cost = ($total_cost / ($filtered | length))
        print "Costs:"
        print $"  Total: \$($total_cost | into string)"
        print $"  Average per session: \$($avg_cost | into string)"
        print ""

        # By workspace
        if $workspace == null {
          print "By Workspace:"
          $filtered
            | group-by workspaceName
            | transpose workspace sessions
            | insert session_count {|row| $row.sessions | length}
            | insert total_tasks {|row| $row.sessions | get history.tasks | each { length } | math sum}
            | insert total_cost {|row| $row.sessions | get history.costs | each { $in | default 0 } | math sum}
            | select workspace session_count total_tasks total_cost
            | sort-by -r session_count
            | table
        }

        print ""

        # Time distribution
        print "Session Durations:"
        let durations = (
          $filtered
            | get history.duration
            | each { $in | default 0 }
        )

        let sorted_durations = ($durations | sort)
        let count = ($sorted_durations | length)

        if $count > 0 {
          let p50 = ($sorted_durations | get (($count * 0.5) | math floor))
          let p95 = ($sorted_durations | get (($count * 0.95) | math floor))
          let max = ($sorted_durations | last)

          print $"  Median: ($p50)s"
          print $"  P95: ($p95)s"
          print $"  Max: ($max)s"
        }
      }
    '';
  };

  # Nushell: Compare sessions
  compare-sessions = writeNuApp {
    name = "comr-session-compare";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        ...session_ids: string  # Session IDs to compare
      ] {
        if ($session_ids | length) < 2 {
          print "Usage: comr session compare <id1> <id2> [<id3> ...]"
          exit 1
        }

        print "🔄 Comparing Sessions"
        print "===================="
        print ""

        # Load sessions
        let base_dir = $"($env.HOME)/.cache/comr/workspaces"

        let sessions = (
          $session_ids
            | each {|id|
                let matches = (
                  glob ($base_dir + "/**/.comr-workspace-state.json")
                    | each {|state_file|
                        try {
                          let state = (open $state_file | from json)
                          if ($state.sessionId | str starts-with $id) {
                            $state
                          } else {
                            null
                          }
                        } catch {
                          null
                        }
                      }
                    | where $it != null
                )

                if ($matches | is-empty) {
                  null
                } else {
                  $matches | first
                }
              }
            | where $it != null
        )

        if ($sessions | length) != ($session_ids | length) {
          print "⚠️  Some sessions not found"
        }

        # Compare workspaces
        print "Workspaces:"
        $sessions
          | enumerate
          | each {|item|
              print $"  Session ($item.index + 1): ($item.item.workspaceName)"
            }
        print ""

        # Compare metrics
        print "Metrics Comparison:"
        [
          {
            metric: "Tasks Completed"
            values: ($sessions | get history.tasks | each { length })
          }
          {
            metric: "Total Cost ($)"
            values: ($sessions | get history.costs | each { $in | default 0 })
          }
          {
            metric: "Duration (s)"
            values: ($sessions | get history.duration | each { $in | default 0 })
          }
          {
            metric: "Agents"
            values: ($sessions | get context.agents | each { length })
          }
          {
            metric: "MCP Servers"
            values: ($sessions | get context.mcpServers | each { length })
          }
        ]
        | table -e

        print ""

        # MCP Server differences
        print "MCP Server Differences:"
        let all_servers = (
          $sessions
            | get context.mcpServers
            | each { transpose name config | get name }
            | flatten
            | uniq
        )

        $all_servers
          | each {|server|
              let in_sessions = (
                $sessions
                  | enumerate
                  | each {|sess|
                      if $server in ($sess.item.context.mcpServers | columns) {
                        $"✅ Session ($sess.index + 1)"
                      } else {
                        $"❌ Session ($sess.index + 1)"
                      }
                    }
                  | str join "  "
              )

              print $"  ($server): ($in_sessions)"
            }
      }
    '';
  };

  # Keep bash for resume (integrates with nix eval)
  resume = pkgs.writeShellScriptBin "comr-resume" ''
    #!/usr/bin/env bash
    SESSION_ID="$1"
    TASK="$2"

    echo "🔄 Resuming session: $SESSION_ID"

    nix eval '.#workspaces.lib.continue' --apply "f: f \"$SESSION_ID\" \"$TASK\""
  '';

  # Keep bash for cleanup (process management)
  cleanup = pkgs.writeShellScriptBin "comr-cleanup" ''
    #!/usr/bin/env bash
    echo "🧹 Cleaning up workspace sessions..."

    # Emergency cleanup
    nix eval '.#workspaces.lib.emergencyCleanup' --apply 'f: f {}'

    echo "✅ Cleanup complete"
  '';

  # Keep bash for archive (file operations with find)
  archive = pkgs.writeShellScriptBin "comr-archive" ''
    #!/usr/bin/env bash
    DAYS_OLD="''${1:-7}"

    echo "📦 Archiving sessions older than $DAYS_OLD days..."

    # Find old sessions
    find "$HOME/.cache/comr/workspaces" -name ".comr-workspace-state.json" -mtime +$DAYS_OLD \
      -exec dirname {} \; | while read -r dir; do
        SESSION_ID=$(basename "$dir")
        nix eval '.#workspaces.lib.archiveWorkspace' --apply "f: f \"$SESSION_ID\""
      done

    echo "✅ Archive complete"
  '';
}
```

**Benefits of Nushell for Workspaces:**

1. **Session Inspection**: JSON state files parsed and displayed beautifully
2. **Filtering**: Rich multi-criteria filtering (workspace, status, time)
3. **Statistics**: Native aggregation (sum, avg, percentiles) without external tools
4. **Table Display**: Sessions shown as formatted tables
5. **Comparison**: Side-by-side session comparison with structured data
6. **Error Handling**: try/catch instead of bash error checks

**Example Output:**

```
$ comr sessions --workspace python-dev --since 3day
📋 Workspace Sessions
====================

Found 5 session(s):

╭────────────┬────────────┬────────┬─────────────────┬───────┬──────────╮
│ Session ID │ Workspace  │ Status │ Last Activity   │ Tasks │ Cost ($) │
├────────────┼────────────┼────────┼─────────────────┼───────┼──────────┤
│ 2025-01... │ python-dev │ active │ 2025-01-15 14:30│ 8     │ 2.45     │
│ 2025-01... │ python-dev │ active │ 2025-01-15 10:15│ 5     │ 1.80     │
│ 2025-01... │ python-dev │ completed│ 2025-01-14 16:45│ 12    │ 4.20     │
╰────────────┴────────────┴────────┴─────────────────┴───────┴──────────╯

Totals:
  Sessions: 5
  Total tasks: 32
  Total cost: $10.25

$ comr session show 2025-01-15-abc123
📋 Session Details
=================

Session ID: 2025-01-15-abc123def456
Workspace: python-dev
Status: active

Timeline:
  Started: 2025-01-15 09:00:00
  Last Activity: 2025-01-15 14:30:15

Context:
  Working Directory: /home/user/projects/my-app
  Agents: 1
  MCP Servers: git, sequential-thinking, sqlite, filesystem

History:
  Tasks Completed: 8
  Total Cost: $2.45
  Duration: 19815 seconds

Resources:
  Temp Files: 3
  Processes: 2
  Connections: 4

Recent Tasks:
  1. Implement user authentication
  2. Add database migrations
  3. Write unit tests
  4. Fix validation bug
  5. Update documentation

Checkpoints:
  Enabled: Yes
  Path: /home/user/.cache/comr/workspaces/python-dev/.../checkpoints
  Interval: 300s
  Available: 12

$ comr session-stats --period week
📊 Session Statistics
====================

Overall:
  Total Sessions: 15
  Active: 8
  Completed: 7

Tasks:
  Total: 124
  Average per session: 8

Costs:
  Total: $42.50
  Average per session: $2.83

By Workspace:
╭────────────────┬───────────────┬────────────┬────────────╮
│ workspace      │ session_count │ total_tasks│ total_cost │
├────────────────┼───────────────┼────────────┼────────────┤
│ python-dev     │ 6             │ 52         │ 18.40      │
│ web-dev        │ 5             │ 42         │ 15.20      │
│ security-audit │ 4             │ 30         │ 8.90       │
╰────────────────┴───────────────┴────────────┴────────────╯

Session Durations:
  Median: 1820s
  P95: 5400s
  Max: 7200s

$ comr session compare 2025-01-15 2025-01-14
🔄 Comparing Sessions
====================

Workspaces:
  Session 1: python-dev
  Session 2: web-dev

Metrics Comparison:
╭───────────────────┬──────────────╮
│ metric            │ values       │
├───────────────────┼──────────────┤
│ Tasks Completed   │ [8, 12]      │
│ Total Cost ($)    │ [2.45, 4.20] │
│ Duration (s)      │ [1980, 3200] │
│ Agents            │ [1, 2]       │
│ MCP Servers       │ [4, 6]       │
╰───────────────────┴──────────────╯

MCP Server Differences:
  git: ✅ Session 1  ✅ Session 2
  sequential-thinking: ✅ Session 1  ✅ Session 2
  sqlite: ✅ Session 1  ❌ Session 2
  filesystem: ✅ Session 1  ✅ Session 2
  postgres: ❌ Session 1  ✅ Session 2
  playwright: ❌ Session 1  ✅ Session 2
```

**When to Use Each:**

**Use Nushell:**
- ✅ Session listing and filtering (`sessions`)
- ✅ State inspection (`show-session`)
- ✅ Statistics aggregation (`session-stats`)
- ✅ Session comparison (`compare-sessions`)
- ✅ Any JSON state file operations

**Keep Bash:**
- ✅ Resume (integrates with nix eval)
- ✅ Cleanup (process killing, file deletion)
- ✅ Archive (file operations with find)
- ✅ Integration with other Nix commands

## Success Criteria

- [ ] All current workspaces migrated
- [ ] Composition API works
- [ ] Multi-agent workspaces functional
- [ ] Backward compatible
- [ ] Workspace lifecycle hooks implemented
- [ ] State persistence and restoration functional
- [ ] Session continuation works
- [ ] Resource tracking and cleanup automatic
- [ ] Checkpoint/restore system operational
- [ ] Workspace templates available
- [ ] Dynamic composition (add/remove servers) works
- [ ] Lifecycle management CLI tools provided
- [ ] **Nushell session management commands (sessions, show-session, session-stats, compare-sessions) functional**
- [ ] **Rich table display for session listing working**
- [ ] **JSON state file inspection intuitive**
- [ ] **Session filtering and aggregation accurate**
