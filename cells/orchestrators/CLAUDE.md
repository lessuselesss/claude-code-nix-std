# Orchestrators Cell - Multi-Agent Coordination Patterns

## Purpose

Implement agent orchestration patterns (LangGraph, CrewAI, AutoGen) that coordinate multiple CLI agents to solve complex tasks through structured collaboration.

## Architecture

### Supported Patterns

**1. LangGraph (State Machine)**
- Agents as nodes in a directed graph
- State passed between nodes
- Conditional edges for dynamic routing
- Best for: Complex workflows with branching logic

**2. CrewAI (Role-Based)**
- Agents with defined roles and responsibilities
- Sequential or hierarchical task execution
- Manager-worker patterns
- Best for: Team-like collaboration with clear roles

**3. AutoGen (Conversational)**
- Agents communicate through messages
- Flexible conversation patterns
- Human-in-the-loop support
- Best for: Discussion-based problem solving

### Three-Layer API Design

**Layer 1: High-Level (Use Pattern)**
```nix
orchestrators.langgraph [agent1 agent2 agent3] "complex task"
orchestrators.crewai { manager = agent1; workers = [agent2 agent3]; } "task"
orchestrators.autogen [agent1 agent2] "discuss this problem"
```

**Layer 2: Medium-Level (Build Pattern)**
```nix
orchestrators.buildGraph {
  nodes = { analyzer = agent1; reviewer = agent2; writer = agent3; };
  edges = [
    { from = "analyzer"; to = "reviewer"; }
    { from = "reviewer"; to = "writer"; condition = "approved"; }
  ];
  state = { code = "..."; feedback = null; };
}
```

**Layer 3: Low-Level (Custom Orchestrator)**
```nix
orchestrators.orchestrate {
  agents = [...];
  coordination = "sequential" | "parallel" | "custom";
  communication = "shared-state" | "messages" | "events";
  hooks = { onStart, onAgentComplete, onError };
}
```

## Files Structure

```
cells/orchestrators/
├── CLAUDE.md (this file)
├── lib.nix          # Public orchestration API
├── functions.nix    # Pattern implementations
├── data.nix         # Pattern configurations
└── runnables.nix    # Orchestration runners
```

## Implementation Plan

### Phase 1: Core Orchestration Infrastructure (Week 4, Days 1-3)

**lib.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
  llm = inputs.cells.llm.lib;
in rec {
  # High-level: LangGraph pattern
  langgraph = agents: task: buildGraph {
    nodes = builtins.listToAttrs (
      builtins.map (a: { name = a.name; value = a; }) agents
    );
    edges = cell.functions.inferEdges agents;
    state = { task = task; results = {}; };
  };

  # High-level: CrewAI pattern
  crewai = { manager, workers }: task: buildCrew {
    roles = {
      manager = {
        agent = manager;
        responsibilities = ["coordinate" "delegate" "aggregate"];
      };
      workers = builtins.listToAttrs (
        builtins.map (w: { name = w.name; value = { agent = w; }; }) workers
      );
    };
    task = task;
  };

  # High-level: AutoGen pattern
  autogen = agents: task: buildConversation {
    participants = agents;
    initiator = builtins.head agents;
    task = task;
    maxRounds = 10;
  };

  # Medium-level: Build custom graph
  buildGraph = { nodes, edges, state, entrypoint ? null }:
    cell.functions.executeGraph { inherit nodes edges state entrypoint; };

  # Medium-level: Build custom crew
  buildCrew = { roles, task, process ? "sequential" }:
    cell.functions.executeCrew { inherit roles task process; };

  # Medium-level: Build custom conversation
  buildConversation = { participants, initiator, task, maxRounds ? 10 }:
    cell.functions.executeConversation { inherit participants initiator task maxRounds; };

  # Low-level: Custom orchestrator
  orchestrate = { agents, coordination ? "sequential", communication ? "shared-state", hooks ? {} }:
    cell.functions.customOrchestrator { inherit agents coordination communication hooks; };
}
```

### Phase 2: LangGraph Implementation (Week 4, Days 4-5)

**functions.nix - LangGraph:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
  llm = inputs.cells.llm.lib;
in rec {
  # Execute LangGraph pattern
  executeGraph = { nodes, edges, state, entrypoint ? null }:
    let
      # Find entry node (no incoming edges or specified)
      entry = if entrypoint != null
              then entrypoint
              else findEntryNode edges;

      # Execute graph traversal
      result = traverseGraph {
        current = entry;
        visited = [];
        inherit nodes edges state;
      };
    in result;

  # Traverse graph nodes
  traverseGraph = { current, visited, nodes, edges, state }:
    if builtins.elem current visited
    then state  # Avoid cycles
    else
      let
        node = nodes.${current};
        # Execute current node
        nodeResult = executeNode node state;
        newState = state // { results = state.results // { ${current} = nodeResult; }; };
        newVisited = visited ++ [current];

        # Find next nodes based on edges
        nextNodes = findNextNodes current edges newState;

        # Execute next nodes (could be parallel or sequential)
        finalState = builtins.foldl' (s: next:
          traverseGraph {
            current = next;
            visited = newVisited;
            inherit nodes edges;
            state = s;
          }
        ) newState nextNodes;
      in finalState;

  # Execute a single node (agent)
  executeNode = agent: state:
    let
      # Prepare context from state
      context = builtins.toJSON state;
      prompt = ''
        Task: ${state.task}

        Current State:
        ${context}

        Your role: ${agent.description or agent.name}

        Analyze the current state and provide your contribution.
      '';

      # Execute agent via llm
      response = llm.ask agent.model prompt;
    in response;

  # Find nodes with no incoming edges
  findEntryNode = edges:
    let
      allNodes = builtins.concatMap (e: [e.from e.to]) edges;
      incomingNodes = builtins.map (e: e.to) edges;
      entryNodes = builtins.filter (n: !(builtins.elem n incomingNodes)) allNodes;
    in builtins.head entryNodes;

  # Find next nodes from current
  findNextNodes = current: edges: state:
    let
      outgoing = builtins.filter (e: e.from == current) edges;
      # Check conditions if present
      valid = builtins.filter (e:
        if e ? condition
        then evaluateCondition e.condition state
        else true
      ) outgoing;
    in builtins.map (e: e.to) valid;

  # Evaluate edge condition
  evaluateCondition = condition: state:
    # Simple condition evaluation (extend as needed)
    builtins.hasAttr condition state.results &&
    state.results.${condition} != null;

  # Infer edges from agent dependencies
  inferEdges = agents:
    # Create sequential edges by default
    let
      pairs = builtins.genList (i:
        if i < (builtins.length agents - 1)
        then {
          from = (builtins.elemAt agents i).name;
          to = (builtins.elemAt agents (i + 1)).name;
        }
        else null
      ) (builtins.length agents);
    in builtins.filter (p: p != null) pairs;
}
```

### Phase 3: CrewAI Implementation (Week 4, Days 6-7)

**functions.nix - CrewAI:**
```nix
{inputs, cell}: rec {
  # Execute CrewAI pattern
  executeCrew = { roles, task, process ? "sequential" }:
    if process == "sequential"
    then executeSequential roles task
    else if process == "hierarchical"
    then executeHierarchical roles task
    else throw "Unknown process: ${process}";

  # Sequential execution
  executeSequential = roles: task:
    let
      # Manager delegates to workers in sequence
      manager = roles.manager.agent;
      workers = builtins.attrValues roles.workers;

      # Manager creates plan
      plan = llm.ask manager.model ''
        Task: ${task}

        Workers available:
        ${builtins.concatStringsSep "\n" (builtins.map (w: "- ${w.agent.name}: ${w.agent.description}") workers)}

        Create a sequential plan delegating subtasks to workers.
        Output JSON: [{"worker": "name", "subtask": "description"}]
      '';

      # Parse plan
      steps = builtins.fromJSON plan;

      # Execute each step
      results = builtins.map (step:
        let
          worker = builtins.find (w: w.agent.name == step.worker) workers;
          result = llm.ask worker.agent.model step.subtask;
        in { worker = step.worker; result = result; }
      ) steps;

      # Manager aggregates results
      final = llm.ask manager.model ''
        Task: ${task}

        Worker Results:
        ${builtins.toJSON results}

        Aggregate these results into a final answer.
      '';
    in final;

  # Hierarchical execution (manager supervises workers)
  executeHierarchical = roles: task:
    let
      manager = roles.manager.agent;
      workers = builtins.attrValues roles.workers;

      # Manager delegates and supervises
      supervision = superviseWorkers manager workers task 0;
    in supervision.final;

  # Recursive supervision
  superviseWorkers = manager: workers: task: round:
    if round > 5  # Max 5 rounds of supervision
    then { final = "Max supervision rounds reached"; }
    else
      let
        # Workers work in parallel
        workerResults = builtins.map (w:
          let
            prompt = ''
              Task: ${task}
              Round: ${toString round}
              Your role: ${w.agent.description}

              Provide your contribution to solving this task.
            '';
            result = llm.ask w.agent.model prompt;
          in { worker = w.agent.name; result = result; }
        ) workers;

        # Manager reviews and decides
        review = llm.ask manager.model ''
          Task: ${task}

          Worker Results (Round ${toString round}):
          ${builtins.toJSON workerResults}

          Evaluate: Is this task complete?
          Output JSON: {"complete": true/false, "feedback": "...", "final": "..."}
        '';

        decision = builtins.fromJSON review;
      in
        if decision.complete
        then decision
        else superviseWorkers manager workers "${task}\n\nFeedback: ${decision.feedback}" (round + 1);
}
```

### Phase 4: AutoGen Implementation (Week 5, Days 1-2)

**functions.nix - AutoGen:**
```nix
{inputs, cell}: rec {
  # Execute AutoGen conversational pattern
  executeConversation = { participants, initiator, task, maxRounds ? 10 }:
    let
      # Initialize conversation
      conversation = {
        messages = [{
          speaker = "system";
          content = "Task: ${task}";
        }];
        round = 0;
      };

      # Run conversation rounds
      final = converseRound conversation participants initiator maxRounds;
    in final;

  # Single conversation round
  converseRound = conversation: participants: currentSpeaker: maxRounds:
    if conversation.round >= maxRounds
    then {
      result = "Max rounds reached";
      messages = conversation.messages;
    }
    else
      let
        # Current speaker responds
        context = formatMessages conversation.messages;
        prompt = ''
          Conversation so far:
          ${context}

          You are: ${currentSpeaker.name}
          Your role: ${currentSpeaker.description}

          Respond to continue the conversation. If the task is complete, start your response with "TERMINATE:".
        '';

        response = llm.ask currentSpeaker.model prompt;

        newMessage = {
          speaker = currentSpeaker.name;
          content = response;
        };

        newConversation = {
          messages = conversation.messages ++ [newMessage];
          round = conversation.round + 1;
        };

        # Check for termination
        isTerminated = builtins.match "TERMINATE:.*" response != null;
      in
        if isTerminated
        then {
          result = builtins.replaceStrings ["TERMINATE:"] [""] response;
          messages = newConversation.messages;
        }
        else
          # Next speaker
          let
            nextSpeaker = selectNextSpeaker participants currentSpeaker newConversation;
          in converseRound newConversation participants nextSpeaker maxRounds;

  # Select next speaker (round-robin or dynamic)
  selectNextSpeaker = participants: current: conversation:
    let
      currentIndex = builtins.elemIndex current participants;
      nextIndex = if currentIndex + 1 >= builtins.length participants
                  then 0
                  else currentIndex + 1;
    in builtins.elemAt participants nextIndex;

  # Format messages for context
  formatMessages = messages:
    builtins.concatStringsSep "\n\n" (
      builtins.map (m: "${m.speaker}: ${m.content}") messages
    );
}
```

### Phase 5: Pattern Configurations (Week 5, Days 3-4)

**data.nix:**
```nix
{inputs, cell}: {
  # Pattern metadata
  patterns = {
    langgraph = {
      name = "LangGraph";
      description = "State machine with conditional routing";
      use_cases = [
        "Complex workflows with branching logic"
        "Multi-stage analysis pipelines"
        "Conditional agent activation"
      ];
      complexity = "high";
      best_for = "deterministic workflows";
    };

    crewai = {
      name = "CrewAI";
      description = "Role-based team collaboration";
      use_cases = [
        "Team-like task delegation"
        "Manager-worker patterns"
        "Sequential task execution"
      ];
      complexity = "medium";
      best_for = "clear role separation";
    };

    autogen = {
      name = "AutoGen";
      description = "Conversational multi-agent";
      use_cases = [
        "Discussion-based problem solving"
        "Brainstorming sessions"
        "Peer review workflows"
      ];
      complexity = "medium";
      best_for = "collaborative discussions";
    };
  };

  # Example orchestrations
  examples = {
    # Security audit with LangGraph
    security-audit-graph = {
      pattern = "langgraph";
      nodes = {
        scanner = {
          name = "static-analyzer";
          model = "claude-3.5-sonnet";
          description = "Static code analysis for vulnerabilities";
        };
        validator = {
          name = "security-validator";
          model = "gemini-2.0-flash";
          description = "Validate findings and check false positives";
        };
        reporter = {
          name = "report-generator";
          model = "claude-3.5-sonnet";
          description = "Generate comprehensive security report";
        };
      };
      edges = [
        { from = "scanner"; to = "validator"; }
        { from = "validator"; to = "reporter"; condition = "has_findings"; }
      ];
    };

    # Code review with CrewAI
    code-review-crew = {
      pattern = "crewai";
      manager = {
        name = "senior-reviewer";
        model = "claude-3.5-sonnet";
        description = "Coordinates code review process";
      };
      workers = [
        {
          name = "security-reviewer";
          model = "claude-3.5-sonnet";
          description = "Reviews security aspects";
        }
        {
          name = "performance-reviewer";
          model = "gemini-2.0-flash";
          description = "Reviews performance aspects";
        }
        {
          name = "style-reviewer";
          model = "gemini-2.0-flash";
          description = "Reviews code style and maintainability";
        }
      ];
      process = "hierarchical";
    };

    # Architecture discussion with AutoGen
    architecture-discussion = {
      pattern = "autogen";
      participants = [
        {
          name = "architect";
          model = "claude-3.5-sonnet";
          description = "Systems architect with 15+ years experience";
        }
        {
          name = "security-expert";
          model = "claude-3.5-sonnet";
          description = "Security specialist";
        }
        {
          name = "performance-expert";
          model = "gemini-2.0-flash";
          description = "Performance optimization expert";
        }
      ];
      maxRounds = 10;
    };
  };
}
```

### Phase 6: Runnable Orchestrators (Week 5, Days 5-7)

**runnables.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in {
  # LangGraph runner
  langgraph-security-audit = pkgs.writeShellScriptBin "langgraph-security-audit" ''
    #!${pkgs.bash}/bin/bash
    TASK="$*"
    echo "🔍 Running LangGraph security audit..."
    echo "Task: $TASK"
    # Execute the graph (this would call into lib.nix)
  '';

  # CrewAI runner
  crewai-code-review = pkgs.writeShellScriptBin "crewai-code-review" ''
    #!${pkgs.bash}/bin/bash
    TASK="$*"
    echo "👥 Running CrewAI code review..."
    echo "Task: $TASK"
    # Execute the crew (this would call into lib.nix)
  '';

  # AutoGen runner
  autogen-discussion = pkgs.writeShellScriptBin "autogen-discussion" ''
    #!${pkgs.bash}/bin/bash
    TASK="$*"
    echo "💬 Starting AutoGen discussion..."
    echo "Task: $TASK"
    # Execute the conversation (this would call into lib.nix)
  '';
}
```

### Phase 7: Agent Communication Protocol (Week 6, Days 1-4)

Multi-agent orchestration requires standardized communication protocols for message passing, state sharing, error handling, and coordination.

#### Communication Patterns

```nix
# data.nix - Communication patterns
{
  communicationPatterns = {
    # Pattern 1: Shared State (LangGraph)
    shared-state = {
      description = "All agents read/write to shared state object";
      pros = ["Simple", "Consistent view", "Easy state inspection"];
      cons = ["Potential conflicts", "Sequential only"];
      use_cases = ["LangGraph state machines"];
    };

    # Pattern 2: Message Passing (AutoGen)
    message-passing = {
      description = "Agents send messages to each other";
      pros = ["Decoupled", "Async capable", "Flexible routing"];
      cons = ["Complex coordination", "Ordering concerns"];
      use_cases = ["AutoGen conversations", "Event-driven systems"];
    };

    # Pattern 3: Command/Response (CrewAI)
    command-response = {
      description = "Manager sends commands, workers respond";
      pros = ["Clear hierarchy", "Deterministic", "Easy debugging"];
      cons = ["Centralized bottleneck", "Manager complexity"];
      use_cases = ["CrewAI hierarchical", "Task delegation"];
    };

    # Pattern 4: Event Streaming
    event-streaming = {
      description = "Agents publish/subscribe to event streams";
      pros = ["Decoupled", "Highly scalable", "Async"];
      cons = ["Complex setup", "Eventual consistency"];
      use_cases = ["Real-time workflows", "High-throughput"];
    };
  };
}
```

#### Message Format Schema

```nix
# data.nix - Message schema
{
  messageSchema = {
    # Standard message format
    version = "1.0";

    fields = {
      id = {
        type = "uuid";
        required = true;
        description = "Unique message identifier";
      };

      correlationId = {
        type = "uuid";
        required = true;
        description = "Links messages in same workflow";
      };

      timestamp = {
        type = "iso8601";
        required = true;
        description = "When message was created";
      };

      sender = {
        type = "object";
        required = true;
        schema = {
          agentId = "string";
          agentName = "string";
          agentType = "string";
        };
      };

      recipient = {
        type = "object";
        required = false;  # Null for broadcast
        schema = {
          agentId = "string";
          agentName = "string";
        };
      };

      messageType = {
        type = "enum";
        required = true;
        values = [
          "task"        # New task assignment
          "result"      # Task completion result
          "query"       # Request for information
          "response"    # Response to query
          "error"       # Error notification
          "status"      # Status update
          "terminate"   # End workflow
        ];
      };

      priority = {
        type = "enum";
        required = false;
        default = "normal";
        values = ["low" "normal" "high" "critical"];
      };

      payload = {
        type = "object";
        required = true;
        description = "Message content (varies by messageType)";
      };

      metadata = {
        type = "object";
        required = false;
        schema = {
          retryCount = "int";
          timeout = "int";
          ttl = "int";  # Time to live (seconds)
          tags = "array<string>";
        };
      };

      trace = {
        type = "object";
        required = false;
        schema = {
          traceId = "string";
          spanId = "string";
          parentSpanId = "string";
        };
      };
    };
  };

  # Example messages
  exampleMessages = {
    task = {
      id = "msg-123";
      correlationId = "workflow-456";
      timestamp = "2025-01-15T10:30:00Z";
      sender = {
        agentId = "agent-manager";
        agentName = "code-review-manager";
        agentType = "crewai-manager";
      };
      recipient = {
        agentId = "agent-worker-1";
        agentName = "security-reviewer";
      };
      messageType = "task";
      priority = "high";
      payload = {
        task = "Review authentication code for security vulnerabilities";
        context = {
          files = ["src/auth.py"];
          framework = "FastAPI";
        };
        deadline = "2025-01-15T11:00:00Z";
      };
      metadata = {
        retryCount = 0;
        timeout = 300;  # 5 minutes
      };
    };

    result = {
      id = "msg-124";
      correlationId = "workflow-456";
      timestamp = "2025-01-15T10:35:00Z";
      sender = {
        agentId = "agent-worker-1";
        agentName = "security-reviewer";
        agentType = "crewai-worker";
      };
      recipient = {
        agentId = "agent-manager";
        agentName = "code-review-manager";
      };
      messageType = "result";
      payload = {
        status = "complete";
        findings = [
          {
            severity = "high";
            type = "SQL Injection";
            location = "src/auth.py:42";
            description = "User input not sanitized before SQL query";
          }
        ];
        confidence = 0.95;
      };
    };

    error = {
      id = "msg-125";
      correlationId = "workflow-456";
      timestamp = "2025-01-15T10:36:00Z";
      sender = {
        agentId = "agent-worker-2";
        agentName = "performance-reviewer";
        agentType = "crewai-worker";
      };
      messageType = "error";
      payload = {
        errorType = "timeout";
        errorMessage = "LLM request timed out after 300s";
        errorCode = "LLM_TIMEOUT";
        recoverable = true;
      };
      metadata = {
        retryCount = 2;
      };
    };
  };
}
```

#### Message Passing Implementation

```nix
# functions.nix - Message handling
{
  # Create message
  createMessage = { sender, recipient ? null, messageType, payload, priority ? "normal", metadata ? {} }:
    let
      correlationId = inputs.cells.diagnostics.lib.getCurrentContext {}.correlationId;
    in {
      id = generateMessageId {};
      correlationId = correlationId;
      timestamp = getCurrentTimestamp {};
      inherit sender recipient messageType priority payload metadata;
      trace = {
        traceId = inputs.cells.diagnostics.lib.getCurrentTrace {}.traceId;
        spanId = inputs.cells.diagnostics.lib.generateSpanId {};
        parentSpanId = inputs.cells.diagnostics.lib.getCurrentSpan {}.spanId;
      };
    };

  # Send message between agents
  sendMessage = message: recipientAgent:
    let
      # Validate message schema
      validated = validateMessage message;

      # Log message
      _ = inputs.cells.diagnostics.lib.logWith {
        category = "orchestrator.message";
      } "info" "Sending message ${message.id} to ${recipientAgent.name}";

      # Add to message queue
      _ = enqueueMessage message recipientAgent;

      # Track metric
      _ = inputs.cells.diagnostics.lib.recordMetric {
        name = "orchestrator.messages_sent";
        type = "counter";
        value = 1;
        labels = ["sender=${message.sender.agentName}" "recipient=${recipientAgent.name}"];
      };

      # Distributed tracing
      _ = inputs.cells.diagnostics.lib.addSpanEvent (inputs.cells.diagnostics.lib.getCurrentSpan {}) {
        name = "message.sent";
        attributes = {
          "message.id" = message.id;
          "message.type" = message.messageType;
          "recipient" = recipientAgent.name;
        };
      };
    in message;

  # Receive message
  receiveMessage = agent:
    let
      # Dequeue message
      message = dequeueMessage agent;

      # Log receipt
      _ = inputs.cells.diagnostics.lib.logWith {
        category = "orchestrator.message";
      } "info" "Agent ${agent.name} received message ${message.id}";

      # Track metric
      _ = inputs.cells.diagnostics.lib.recordMetric {
        name = "orchestrator.messages_received";
        type = "counter";
        value = 1;
        labels = ["agent=${agent.name}"];
      };

      # Validate message hasn't expired
      isValid = checkMessageValidity message;
    in
      if isValid
      then message
      else throw "Message ${message.id} expired (TTL exceeded)";

  # Broadcast message to all agents
  broadcastMessage = message: agents:
    builtins.map (agent: sendMessage (message // { recipient = agent; }) agent) agents;

  # Validate message schema
  validateMessage = message:
    let
      requiredFields = ["id" "correlationId" "timestamp" "sender" "messageType" "payload"];
      hasAllFields = builtins.all (f: builtins.hasAttr f message) requiredFields;

      validMessageTypes = ["task" "result" "query" "response" "error" "status" "terminate"];
      hasValidType = builtins.elem message.messageType validMessageTypes;
    in
      if !hasAllFields
      then throw "Message missing required fields"
      else if !hasValidType
      then throw "Invalid message type: ${message.messageType}"
      else message;

  # Check message validity (TTL, expiration)
  checkMessageValidity = message:
    let
      now = getCurrentTimestamp {};
      messageTime = message.timestamp;
      ttl = message.metadata.ttl or 3600;  # Default 1 hour

      age = calculateTimeDiff now messageTime;
    in age < ttl;

  # Message queue operations
  enqueueMessage = message: agent:
    let
      queueFile = "${builtins.getEnv "HOME"}/.cache/comr/orchestrator/queues/${agent.name}.json";
      currentQueue = if builtins.pathExists queueFile
                     then builtins.fromJSON (builtins.readFile queueFile)
                     else [];
      newQueue = currentQueue ++ [message];
    in pkgs.writeText queueFile (builtins.toJSON newQueue);

  dequeueMessage = agent:
    let
      queueFile = "${builtins.getEnv "HOME"}/.cache/comr/orchestrator/queues/${agent.name}.json";
      queue = builtins.fromJSON (builtins.readFile queueFile);
      message = builtins.head queue;
      remainingQueue = builtins.tail queue;
      _ = pkgs.writeText queueFile (builtins.toJSON remainingQueue);
    in message;

  generateMessageId = {}:
    "msg-${generateUuid {}}";
}
```

#### State Synchronization

```nix
# functions.nix - State management for multi-agent
{
  # Shared state for LangGraph pattern
  initSharedState = initialState:
    let
      stateFile = "${builtins.getEnv "HOME"}/.cache/comr/orchestrator/state-${initialState.correlationId}.json";
      _ = pkgs.writeText stateFile (builtins.toJSON initialState);
    in stateFile;

  # Read shared state
  readSharedState = correlationId:
    let
      stateFile = "${builtins.getEnv "HOME"}/.cache/comr/orchestrator/state-${correlationId}.json";
    in
      if builtins.pathExists stateFile
      then builtins.fromJSON (builtins.readFile stateFile)
      else throw "State ${correlationId} not found";

  # Update shared state (with locking)
  updateSharedState = correlationId: updates:
    let
      lockFile = "${builtins.getEnv "HOME"}/.cache/comr/orchestrator/state-${correlationId}.lock";

      # Acquire lock
      _ = acquireLock lockFile;

      # Read current state
      currentState = readSharedState correlationId;

      # Merge updates
      newState = pkgs.lib.recursiveUpdate currentState updates;

      # Write new state
      stateFile = "${builtins.getEnv "HOME"}/.cache/comr/orchestrator/state-${correlationId}.json";
      _ = pkgs.writeText stateFile (builtins.toJSON newState);

      # Release lock
      _ = releaseLock lockFile;
    in newState;

  # File-based locking for state updates
  acquireLock = lockFile:
    pkgs.runCommand "acquire-lock" {} ''
      # Wait for lock with timeout
      TIMEOUT=30
      ELAPSED=0
      while [[ -f ${lockFile} ]] && [[ $ELAPSED -lt $TIMEOUT ]]; do
        sleep 0.1
        ELAPSED=$((ELAPSED + 1))
      done

      if [[ $ELAPSED -ge $TIMEOUT ]]; then
        echo "Lock acquisition timeout" >&2
        exit 1
      fi

      # Create lock file
      touch ${lockFile}
    '';

  releaseLock = lockFile:
    pkgs.runCommand "release-lock" {} ''rm -f ${lockFile}'';

  # State versioning (for conflict detection)
  versionedStateUpdate = correlationId: updates: expectedVersion:
    let
      currentState = readSharedState correlationId;
      currentVersion = currentState.version or 0;
    in
      if currentVersion != expectedVersion
      then throw "State version conflict: expected ${builtins.toString expectedVersion}, got ${builtins.toString currentVersion}"
      else updateSharedState correlationId (updates // { version = currentVersion + 1; });
}
```

#### Error Handling and Retries

```nix
# functions.nix - Error handling
{
  # Retry policy
  retryPolicy = {
    maxRetries = 3;
    backoffStrategy = "exponential";  # "exponential" | "linear" | "constant"
    initialDelay = 1000;  # milliseconds
    maxDelay = 30000;
    jitter = true;
  };

  # Execute with retry
  executeWithRetry = operation: retryCount ? 0:
    let
      result = builtins.tryEval operation;
    in
      if result.success
      then result.value
      else if retryCount >= cell.functions.retryPolicy.maxRetries
      then throw "Max retries (${builtins.toString retryCount}) exceeded"
      else
        let
          delay = calculateBackoff retryCount;
          _ = sleep delay;

          # Log retry attempt
          _ = inputs.cells.diagnostics.lib.logWarning "Retrying operation (attempt ${builtins.toString (retryCount + 1)})";
        in executeWithRetry operation (retryCount + 1);

  # Calculate backoff delay
  calculateBackoff = retryCount:
    let
      baseDelay = cell.functions.retryPolicy.initialDelay;
      strategy = cell.functions.retryPolicy.backoffStrategy;

      delay =
        if strategy == "constant"
        then baseDelay
        else if strategy == "linear"
        then baseDelay * (retryCount + 1)
        else  # exponential
        baseDelay * (2 ^ retryCount);

      # Apply max delay cap
      cappedDelay = builtins.min delay cell.functions.retryPolicy.maxDelay;

      # Add jitter if enabled
      finalDelay = if cell.functions.retryPolicy.jitter
                   then cappedDelay + (randomInt 0 1000)
                   else cappedDelay;
    in finalDelay;

  # Handle agent failure
  handleAgentFailure = agent: error: workflow:
    let
      # Log error
      _ = inputs.cells.diagnostics.lib.logError "Agent ${agent.name} failed: ${error}";

      # Track metric
      _ = inputs.cells.diagnostics.lib.trackError "agent_failure" ["agent=${agent.name}"];

      # Determine recovery strategy
      strategy = determineRecoveryStrategy error;
    in
      if strategy == "retry"
      then retryAgent agent workflow
      else if strategy == "skip"
      then skipAgent agent workflow
      else if strategy == "fallback"
      then useFallbackAgent agent workflow
      else  # terminate
      terminateWorkflow workflow error;

  # Determine recovery strategy based on error type
  determineRecoveryStrategy = error:
    if builtins.match ".*timeout.*" error != null
    then "retry"
    else if builtins.match ".*rate.?limit.*" error != null
    then "retry"
    else if builtins.match ".*not.?available.*" error != null
    then "fallback"
    else "terminate";

  # Retry agent execution
  retryAgent = agent: workflow:
    executeWithRetry (executeAgent agent workflow);

  # Skip failed agent and continue workflow
  skipAgent = agent: workflow:
    let
      # Mark agent as skipped in workflow state
      newWorkflow = workflow // {
        skippedAgents = (workflow.skippedAgents or []) ++ [agent.name];
      };
    in continueWorkflow newWorkflow;

  # Use fallback agent
  useFallbackAgent = agent: workflow:
    let
      fallback = findFallbackAgent agent;
    in
      if fallback != null
      then executeAgent fallback workflow
      else terminateWorkflow workflow "No fallback agent available";

  # Terminate workflow due to unrecoverable error
  terminateWorkflow = workflow: reason:
    let
      # Log termination
      _ = inputs.cells.diagnostics.lib.logCritical "Workflow ${workflow.correlationId} terminated: ${reason}";

      # Send termination messages to all agents
      _ = builtins.map (agent:
        sendMessage (createMessage {
          sender = { agentId = "orchestrator"; agentName = "orchestrator"; agentType = "system"; };
          recipient = agent;
          messageType = "terminate";
          payload = { reason = reason; };
        }) agent
      ) workflow.agents;

      # Cleanup workflow resources
      _ = cleanupWorkflow workflow;
    in { status = "terminated"; reason = reason; };
}
```

#### Message Ordering and Consistency

```nix
# functions.nix - Ordering guarantees
{
  # Ensure message ordering per agent
  orderMessages = messages: agent:
    let
      # Sort by timestamp
      sorted = builtins.sort (a: b: a.timestamp < b.timestamp) messages;

      # Ensure sequential IDs
      sequenced = builtins.genList (i:
        let msg = builtins.elemAt sorted i;
        in msg // { sequenceNumber = i; }
      ) (builtins.length sorted);
    in sequenced;

  # Check for missing messages
  detectMissingMessages = messages:
    let
      sequences = builtins.map (m: m.sequenceNumber or null) messages;
      maxSeq = builtins.foldl' builtins.max 0 (builtins.filter (s: s != null) sequences);
      expectedSeqs = builtins.genList (i: i) (maxSeq + 1);

      missing = builtins.filter (expected:
        !(builtins.elem expected sequences)
      ) expectedSeqs;
    in missing;

  # Ensure exactly-once delivery
  deduplicateMessages = messages:
    let
      seen = {};
      deduplicated = builtins.foldl' (acc: msg:
        if builtins.hasAttr msg.id seen
        then acc  # Skip duplicate
        else {
          messages = acc.messages ++ [msg];
          seen = acc.seen // { ${msg.id} = true; };
        }
      ) { messages = []; seen = {}; } messages;
    in deduplicated.messages;

  # Ensure causal ordering (happens-before relationship)
  causalSort = messages:
    # Implement Lamport timestamps or vector clocks
    # For simplicity, sort by correlationId then timestamp
    builtins.sort (a: b:
      if a.correlationId == b.correlationId
      then a.timestamp < b.timestamp
      else a.correlationId < b.correlationId
    ) messages;
}
```

#### Security and Authentication

```nix
# functions.nix - Communication security
{
  # Authenticate agent before message sending
  authenticateAgent = agent:
    let
      agentId = agent.agentId;
      expectedHash = inputs.cells.config.lib.getAgentHash agentId;
      actualHash = hashAgent agent;
    in
      if expectedHash == actualHash
      then true
      else throw "Agent authentication failed: ${agentId}";

  # Authorize agent for operation
  authorizeAgent = agent: operation:
    let
      permissions = inputs.cells.config.lib.getAgentPermissions agent.agentId;
    in builtins.elem operation permissions;

  # Sign message
  signMessage = message: agent:
    let
      agentKey = inputs.cells.config.lib.getAgentKey agent.agentId;
      signature = createSignature message agentKey;
    in message // { signature = signature; };

  # Verify message signature
  verifyMessageSignature = message:
    let
      agentKey = inputs.cells.config.lib.getAgentKey message.sender.agentId;
      expectedSignature = createSignature (builtins.removeAttrs message ["signature"]) agentKey;
      actualSignature = message.signature or null;
    in actualSignature == expectedSignature;

  # Encrypt sensitive payloads
  encryptPayload = payload: recipientAgent:
    let
      recipientKey = inputs.cells.config.lib.getAgentPublicKey recipientAgent.agentId;
    in pkgs.runCommand "encrypt-payload" {
      buildInputs = [ pkgs.age ];
    } ''
      echo '${builtins.toJSON payload}' | ${pkgs.age}/bin/age -r ${recipientKey} > $out
    '';

  # Decrypt payload
  decryptPayload = encryptedPayload: recipientAgent:
    let
      recipientKey = inputs.cells.config.lib.getAgentPrivateKey recipientAgent.agentId;
    in pkgs.runCommand "decrypt-payload" {
      buildInputs = [ pkgs.age ];
    } ''
      ${pkgs.age}/bin/age -d -i ${recipientKey} ${encryptedPayload} > $out
    '';
}
```

#### Integration with Diagnostics

```nix
# Instrumented message passing with full observability
{
  instrumentedSendMessage = message: recipient:
    let
      # Start trace span
      span = inputs.cells.diagnostics.lib.startTrace "orchestrator.send_message";

      # Add span attributes
      _ = inputs.cells.diagnostics.lib.addSpanAttributes span {
        "message.id" = message.id;
        "message.type" = message.messageType;
        "sender" = message.sender.agentName;
        "recipient" = recipient.name;
        "correlation.id" = message.correlationId;
      };

      # Send message
      result = sendMessage message recipient;

      # Track metrics
      _ = inputs.cells.diagnostics.lib.recordMetric {
        name = "orchestrator.message_latency";
        type = "histogram";
        value = getCurrentTimestamp {} - message.timestamp;
        labels = ["sender=${message.sender.agentName}" "recipient=${recipient.name}"];
      };

      # End span
      _ = inputs.cells.diagnostics.lib.endTrace span;
    in result;

  # Trace entire workflow execution
  traceWorkflow = workflow:
    let
      workflowSpan = inputs.cells.diagnostics.lib.startTrace "orchestrator.workflow";

      # Add workflow metadata
      _ = inputs.cells.diagnostics.lib.addSpanAttributes workflowSpan {
        "workflow.id" = workflow.correlationId;
        "workflow.pattern" = workflow.pattern;
        "workflow.agents" = builtins.concatStringsSep "," (builtins.map (a: a.name) workflow.agents);
      };

      # Execute workflow with child spans
      result = executeWorkflow workflow;

      # End workflow span
      _ = inputs.cells.diagnostics.lib.endTrace workflowSpan;
    in result;
}
```

### Phase 8: Nushell Orchestration Runtime (Week 6, Days 5-7)

**Rationale:** While Nix provides excellent build-time guarantees and structure definition, runtime orchestration benefits from a more flexible, data-oriented language. Nushell provides native structured data support, clean pipeline syntax, and better runtime error handling.

**Reference:** See [docs/references/agentic-ai-best-practices.md](../../docs/references/agentic-ai-best-practices.md) for production-tested orchestration patterns.

#### Why Nushell for Orchestration?

**Advantages over Pure Nix:**
- **Runtime Flexibility**: Nix evaluates at build-time; Nushell executes at runtime
- **Dynamic Routing**: Can change workflow based on agent results
- **Native JSON/Tables**: Perfect for MCP protocol and message passing
- **Better Error Handling**: try/catch vs Nix's build failures
- **Interactive Debugging**: Can inspect state during execution
- **Cleaner Syntax**: Pipelines are more readable than nested Nix

**Advantages over Bash:**
- **Type Safety**: Structured data instead of string parsing
- **Error Propagation**: Proper try/catch mechanisms
- **Data Transformations**: Built-in filtering, aggregation, joins
- **Readability**: Named fields instead of positional args

**Advantages over Python:**
- **Simpler Deployment**: No virtualenvs, no dependencies
- **Native Shell Integration**: Process management, pipes
- **Less Boilerplate**: No classes/dataclasses needed
- **Better for Data Flows**: Pipeline syntax matches orchestration logic

#### Architecture: Nix + Nushell Hybrid

```
┌─────────────────────────────────────────┐
│ Nix Layer (Build Time)                  │
│ - Define agent capabilities             │
│ - Package dependencies                  │
│ - Create workflow templates             │
│ - Ensure reproducibility                │
└──────────────┬──────────────────────────┘
               │ Generates
               ▼
┌─────────────────────────────────────────┐
│ Nushell Layer (Runtime)                 │
│ - Execute orchestration workflows       │
│ - Manage message passing                │
│ - Handle state and checkpoints          │
│ - Implement retry/error logic           │
│ - Route messages dynamically            │
│ - Aggregate and transform results       │
└─────────────────────────────────────────┘
```

#### Orchestration Patterns in Nushell

Based on [UserJot's Agentic AI Best Practices](../../docs/references/agentic-ai-best-practices.md):

**1. Sequential Pipeline (LangGraph Pattern)**
```nu
# Security audit workflow
def security-audit [target: string] {
  mut state = { target: $target, findings: [] }

  # Step 1: Scan dependencies
  $state = ($state | scan-dependencies)

  # Step 2: Check vulnerabilities
  $state = ($state | check-vulnerabilities)

  # Step 3: Analyze code
  $state = ($state | code-analysis)

  # Step 4: Generate report
  $state | generate-report
}

# Each step is a stateless subagent
def scan-dependencies [state: record] {
  let deps = (call-mcp-server "git" {command: "list-dependencies"})
  $state | upsert dependencies $deps
}
```

**2. MapReduce Pattern (Parallel Analysis)**
```nu
# Analyze codebase with parallel agents
def analyze-codebase [root: string] {
  let components = ["backend" "frontend" "tests" "docs"]

  # Map: Analyze each component in parallel
  let analyses = $components
    | par-each { |component|
        {
          component: $component
          result: (call-agent "claude" $"Analyze ($component)")
        }
      }

  # Reduce: Merge results
  $analyses | aggregate-results
}
```

**3. Consensus Pattern (Multi-Model Validation)**
```nu
# Get consensus from multiple models
def architecture-decision [question: string] {
  # Run same task on multiple agents in parallel
  let responses = [
    { agent: "claude", model: "claude-3.5-sonnet" }
    { agent: "gemini", model: "gemini-2.0-flash" }
    { agent: "qwen", model: "qwen-2.5-72b" }
  ] | par-each { |config|
      {
        agent: $config.agent
        response: (call-llm $config.model $question)
      }
    }

  # Vote/consensus
  $responses | consensus-vote
}

def consensus-vote [responses: list] {
  # Score responses by similarity and quality
  let scored = $responses | each { |resp|
    {
      agent: $resp.agent
      response: $resp.response
      similarity: (calculate-similarity $resp.response $responses)
      quality: (assess-quality $resp.response)
    }
  }

  # Return highest-scored response
  $scored | sort-by quality | last | get response
}
```

**4. Hierarchical Delegation (CrewAI Pattern)**
```nu
# Manager-worker orchestration
def crewai-workflow [task: string] {
  # Manager creates plan
  let plan = (call-agent "manager-claude" $"Create plan for: ($task)")
    | from json

  # Delegate to workers
  mut results = []
  for step in $plan.steps {
    let worker = (select-worker $step.type)
    let result = (call-agent $worker $step.task)
    $results = ($results | append {step: $step.id, result: $result})
  }

  # Manager aggregates
  call-agent "manager-claude" $"Aggregate: ($ results | to json)"
}
```

#### Implementation Files

**runnables.nix - Nushell Orchestration Runners:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
  nu = pkgs.nushell;

  # Get Nushell writers from lib cell
  writeNu = inputs.cells.lib.functions.writeNushellScript;
  writeNuApp = inputs.cells.lib.functions.writeNushellApplication;
in {
  # Sequential pipeline orchestrator
  langgraph-nu = writeNuApp {
    name = "langgraph-nu";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./workflows/langgraph-security-audit.nu;
  };

  # MapReduce orchestrator
  mapreduce-analyze = writeNuApp {
    name = "mapreduce-analyze";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./workflows/mapreduce-codebase.nu;
  };

  # Consensus orchestrator
  consensus-decision = writeNuApp {
    name = "consensus-decision";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./workflows/consensus-architecture.nu;
  };

  # CrewAI orchestrator
  crewai-nu = writeNuApp {
    name = "crewai-nu";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./workflows/crewai-code-review.nu;
  };
}
```

#### Error Handling with Partial Results

Following UserJot's "always return partial results" principle:

```nu
# Robust pipeline with graceful degradation
def robust-security-audit [target: string] {
  mut state = {
    target: $target
    started: (date now)
    steps: []
    errors: []
  }

  # Try each step, continue on failure
  for step in ["scan-deps" "check-vulns" "analyze-code" "generate-report"] {
    try {
      let output = (run-step $step $state)
      $state = ($state
        | upsert steps ($state.steps | append {
            name: $step
            status: "success"
            output: $output
            completed: (date now)
          }))
    } catch { |err|
      print $"⚠️  Step ($step) failed: ($err.msg)"
      $state = ($state
        | upsert steps ($state.steps | append {
            name: $step
            status: "failed"
            error: $err.msg
            completed: (date now)
          })
        | upsert errors ($state.errors | append {step: $step, error: $err.msg}))
      # Continue with partial results
    }
  }

  # Always return state, even with failures
  $state
}
```

#### State Management and Checkpoints

```nu
# Checkpointing for long-running workflows
def checkpoint-workflow [state: record] {
  let checkpoint_dir = $"($env.HOME)/.cache/comr/orchestrator/checkpoints"
  mkdir $checkpoint_dir

  let checkpoint_file = $"($checkpoint_dir)/($state.correlationId).json"
  $state | to json | save -f $checkpoint_file

  print $"✓ Checkpoint saved: ($checkpoint_file)"
}

# Resume from checkpoint
def resume-workflow [correlation_id: string] {
  let checkpoint_file = $"($env.HOME)/.cache/comr/orchestrator/checkpoints/($correlation_id).json"

  if ($checkpoint_file | path exists) {
    open $checkpoint_file | from json
  } else {
    error make {msg: $"Checkpoint not found: ($correlation_id)"}
  }
}

# Workflow with automatic checkpointing
def long-running-workflow [task: string] {
  mut state = {
    correlationId: (random uuid)
    task: $task
    phase: "init"
  }

  # Phase 1: Research
  $state = ($state | upsert phase "research")
  $state = ($state | research-phase)
  checkpoint-workflow $state

  # Phase 2: Analysis
  $state = ($state | upsert phase "analysis")
  $state = ($state | analysis-phase)
  checkpoint-workflow $state

  # Phase 3: Synthesis
  $state = ($state | upsert phase "synthesis")
  $state = ($state | synthesis-phase)
  checkpoint-workflow $state

  $state
}
```

#### Message Passing in Nushell

```nu
# Create standardized message
def create-message [
  sender: string
  recipient: string
  type: string
  payload: record
] {
  {
    id: (random uuid)
    correlationId: $env.CORRELATION_ID
    timestamp: (date now | date to-record)
    sender: $sender
    recipient: $recipient
    messageType: $type
    payload: $payload
    trace: {
      traceId: $env.TRACE_ID
      spanId: (random uuid)
    }
  }
}

# Send message to agent
def send-message [message: record, agent: string] {
  # Validate message
  if (validate-message $message) {
    # Add to agent queue
    let queue_file = $"($env.HOME)/.cache/comr/orchestrator/queues/($agent).jsonl"
    $message | to json | save --append $queue_file

    # Log
    log-message "sent" $message

    $message
  } else {
    error make {msg: "Invalid message schema"}
  }
}

# Receive message for agent
def receive-message [agent: string] {
  let queue_file = $"($env.HOME)/.cache/comr/orchestrator/queues/($agent).jsonl"

  if ($queue_file | path exists) {
    # Read first message
    let messages = open $queue_file | lines | each { from json }
    let message = $messages | first

    # Remove from queue
    $messages | skip 1 | to json | save -f $queue_file

    # Log
    log-message "received" $message

    $message
  } else {
    null
  }
}

# Validate message schema
def validate-message [message: record] {
  let required = ["id" "correlationId" "timestamp" "sender" "messageType" "payload"]
  let has_all = $required | all { |field| $field in $message }

  let valid_types = ["task" "result" "query" "response" "error" "status" "terminate"]
  let valid_type = $message.messageType in $valid_types

  $has_all and $valid_type
}
```

#### Integration with MCP Servers

```nu
# Call MCP server (stateless subagent)
def call-mcp-server [
  server: string
  command: record
] {
  # Get server config from registry
  let config = (get-server-config $server)

  # Build MCP request
  let request = {
    jsonrpc: "2.0"
    id: (random uuid)
    method: $command.method
    params: $command.params
  }

  # Execute via npx/uvx/nix
  let result = match $config.command {
    "npx" => { ^npx -y $config.args.0 | complete }
    "uvx" => { ^uvx $config.args.0 | complete }
    "nix" => { ^nix run $config.args.0 -- | complete }
  }

  # Parse result
  if $result.exit_code == 0 {
    $result.stdout | from json
  } else {
    error make {msg: $"MCP server failed: ($result.stderr)"}
  }
}
```

#### LLM Integration

```nu
# Call LLM with model selection
def call-llm [model: string, prompt: string] {
  # Use llm cell's cost-optimal routing
  let response = (
    open ~/.cache/comr/llm/models.json
      | get $model
      | $in.endpoint
      | http post --content-type application/json {
          model: $model
          messages: [{role: "user", content: $prompt}]
        }
  )

  $response | get choices.0.message.content
}

# Call agent (combines model + persona)
def call-agent [agent: string, task: string] {
  # Get agent config
  let config = (open ~/.config/comr/agents.json | get $agent)

  # Build prompt with agent persona
  let prompt = $"
    You are: ($config.description)

    Task: ($task)

    Respond with your contribution to solving this task.
  "

  # Call LLM
  call-llm $config.model $prompt
}
```

#### Monitoring and Observability

```nu
# Log workflow execution
def log-workflow-start [workflow: record] {
  {
    timestamp: (date now | date to-record)
    level: "info"
    category: "orchestrator.workflow"
    message: "Starting workflow"
    context: {
      correlationId: $workflow.correlationId
      pattern: $workflow.pattern
      agents: ($workflow.agents | str join ",")
    }
  } | to json | save --append ~/.config/comr/logs/orchestrator.log
}

# Track metrics
def track-metric [name: string, value: number, labels: record] {
  {
    timestamp: (date now | date to-record)
    metric: $name
    value: $value
    labels: $labels
  } | to json | save --append ~/.cache/comr/metrics/orchestrator.jsonl
}

# Performance instrumentation
def timed-operation [name: string, operation: closure] {
  let start = (date now)

  let result = try {
    do $operation
  } catch { |err|
    {error: $err}
  }

  let duration = ((date now) - $start | into duration | into int)

  track-metric "orchestrator.operation_duration" $duration {operation: $name}

  if "error" in $result {
    error make $result.error
  } else {
    $result
  }
}
```

#### Example Workflow Files

See Phase 8 example workflows in:
- `cells/orchestrators/workflows/langgraph-security-audit.nu`
- `cells/orchestrators/workflows/mapreduce-codebase.nu`
- `cells/orchestrators/workflows/consensus-architecture.nu`
- `cells/orchestrators/workflows/crewai-code-review.nu`

These files will be created in the next task.

#### Hybrid Nix-Nushell Pattern

```nix
# Nix defines structure and guarantees
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};

  # Define workflow configuration in Nix
  securityAuditConfig = {
    agents = [
      { name = "scanner"; model = "claude-3.5-sonnet"; }
      { name = "validator"; model = "gemini-2.0-flash"; }
      { name = "reporter"; model = "claude-3.5-sonnet"; }
    ];
    steps = ["scan" "validate" "report"];
    timeout = 600;
    retries = 3;
  };

  # Nushell executes workflow at runtime
  securityAuditWorkflow = writeNuApp {
    name = "security-audit";
    text = ''
      # Load config from Nix
      let config = ${builtins.toJSON securityAuditConfig} | from json

      # Execute workflow with Nushell's runtime capabilities
      def main [target: string] {
        execute-workflow $config $target
      }
    '';
  };
in {
  inherit securityAuditWorkflow;
}
```

#### Benefits Summary

**Development Benefits:**
- Faster iteration (no rebuild needed)
- Interactive debugging (REPL)
- Easier testing (pure functions)
- Better error messages

**Runtime Benefits:**
- Dynamic routing based on results
- Graceful degradation
- Partial results on failure
- Real-time state inspection

**Operational Benefits:**
- Checkpointing for long workflows
- Resume after failure
- Progress tracking
- Cost monitoring

#### Migration Path

**Phase 8.1:** Nushell writers and helpers (Week 6, Day 5)
- Create cells/lib/writers.nix with Nushell functions
- Test basic Nushell script execution

**Phase 8.2:** Port one orchestration pattern (Week 6, Day 6)
- Start with LangGraph sequential pattern
- Create langgraph-security-audit.nu
- Test against Nix-only version

**Phase 8.3:** Add observability (Week 6, Day 7)
- Integrate with diagnostics cell
- Add logging, metrics, tracing
- Create monitoring dashboards

**Phase 8.4:** Port remaining patterns (Week 7)
- MapReduce pattern
- Consensus pattern
- CrewAI hierarchical pattern

#### Success Criteria

- [ ] Nushell writers functional in cells/lib/
- [ ] All 4 orchestration patterns implemented in Nushell
- [ ] Error handling with partial results works
- [ ] Checkpointing and resume functional
- [ ] Message passing between agents works
- [ ] MCP server integration functional
- [ ] Observability fully integrated
- [ ] Performance comparable to or better than pure Nix
- [ ] Example workflows execute successfully
- [ ] Documentation complete with comparisons

#### References

- **[Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents)** - Anthropic's guide on agent workflows, human-in-the-loop patterns, and evaluation strategies
- [Agentic AI Best Practices](../../docs/references/agentic-ai-best-practices.md) - UserJot article
- [Nushell Documentation](https://www.nushell.sh/book/) - Language reference
- LangGraph, CrewAI, AutoGen patterns adapted for Nushell

## Dependencies

### Inputs Required
- `nixpkgs`: For utilities
- `inputs.cells.llm`: For agent execution
- `inputs.cells.agents.*`: For agent definitions

### External Dependencies
- None (pure Nix orchestration logic)

### Cells Consumed
- `llm` - For executing agent prompts
- `agents/*` - For agent definitions

### Cells Produced For
- `workspaces` - Orchestrated workspace environments
- `examples` - Example orchestrations

## Testing Strategy

### Unit Tests
```bash
# Test graph traversal logic
nix eval .#orchestrators.functions.findEntryNode

# Test edge evaluation
nix eval .#orchestrators.functions.findNextNodes
```

### Integration Tests
```bash
# Test LangGraph pattern
nix run .#orchestrators.runnables.langgraph-security-audit -- "audit this code"

# Test CrewAI pattern
nix run .#orchestrators.runnables.crewai-code-review -- "review PR #123"

# Test AutoGen pattern
nix run .#orchestrators.runnables.autogen-discussion -- "discuss microservices vs monolith"
```

## Examples

### Example 1: Simple Sequential Graph
```nix
{inputs, cell}: {
  myOrchestration = task: inputs.cells.orchestrators.lib.buildGraph {
    nodes = {
      analyzer = { name = "analyzer"; model = "claude-3.5-sonnet"; };
      reviewer = { name = "reviewer"; model = "gemini-2.0-flash"; };
    };
    edges = [{ from = "analyzer"; to = "reviewer"; }];
    state = { task = task; };
  };
}
```

### Example 2: Conditional Graph
```nix
buildGraph {
  nodes = {
    scanner = {...};
    validator = {...};
    fixer = {...};
    reporter = {...};
  };
  edges = [
    { from = "scanner"; to = "validator"; }
    { from = "validator"; to = "fixer"; condition = "has_issues"; }
    { from = "validator"; to = "reporter"; condition = "no_issues"; }
    { from = "fixer"; to = "reporter"; }
  ];
}
```

## Migration Notes

### From Current comr
- Current: Single agent execution
- New: Multi-agent orchestration with patterns
- Benefit: Complex tasks handled by specialized agent teams

## Future Enhancements

1. **Parallel Execution**: Execute independent nodes in parallel
2. **Dynamic Agent Selection**: Choose agents based on task analysis
3. **Learning from History**: Optimize orchestration based on past executions
4. **Human-in-the-Loop**: Interactive supervision and feedback
5. **Cost Optimization**: Route to cheaper agents when appropriate
6. **Visualization**: Generate orchestration flow diagrams

## Questions to Resolve

1. How to handle agent failures in orchestration?
2. Should we support async/streaming orchestration?
3. How to persist orchestration state for resumption?
4. Should we support agent spawning (creating agents dynamically)?
5. How to handle timeouts and rate limits?

## Success Criteria

- [ ] LangGraph pattern works with 3+ agents
- [ ] CrewAI pattern executes sequential and hierarchical processes
- [ ] AutoGen pattern maintains conversation for 10+ rounds
- [ ] State is correctly passed between agents
- [ ] Conditional edges work correctly
- [ ] All runnables execute successfully
- [ ] Documentation is complete
- [ ] Message passing protocol implemented (create, send, receive, validate)
- [ ] Message schema validation works
- [ ] State synchronization with locking functional
- [ ] Error handling and retries work correctly
- [ ] Message ordering guarantees enforced
- [ ] Agent authentication and authorization functional
- [ ] Message encryption/decryption for sensitive data works
- [ ] Distributed tracing integrated for all messages
