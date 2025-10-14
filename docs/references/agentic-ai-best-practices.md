# Best Practices for Building Agentic AI Systems: What Actually Works in Production

**Source:** https://userjot.com/blog/best-practices-building-agentic-ai-systems
**Date Retrieved:** 2025-10-13
**Relevance:** Architecture patterns for multi-agent orchestration, error handling, and production deployment

---

## Key Principles of Agentic AI Systems

### Two-Tier Agent Model

The most effective agent architecture consists of two levels:

1. **Primary Agents**:
   - Handle conversation and context
   - Act like project managers
   - Orchestrate overall task flow

2. **Subagents**:
   - Perform specific, isolated tasks
   - No memory or shared state
   - Execute pure function-like operations

### Core Architecture Example

```
User → Primary Agent (maintains context)
         ├─→ Research Agent (finds relevant feedback)
         ├─→ Analysis Agent (processes sentiment)
         └─→ Summary Agent (creates reports)
```

## Critical Design Patterns

### Stateless Subagents

Key benefits of stateless design:
- Parallel execution
- Predictable behavior
- Easy testing
- Simple caching

### Task Decomposition Strategies

1. **Vertical Decomposition**: Sequential tasks with dependencies
2. **Horizontal Decomposition**: Parallel independent tasks

### Communication Protocols

Every task requires:
- Clear objective
- Bounded context
- Output specification
- Execution constraints

## Orchestration Patterns

1. **Sequential Pipeline**: Output of one agent feeds next agent
2. **MapReduce**: Split work across agents, combine results
3. **Consensus**: Multiple agents solve same problem, compare answers
4. **Hierarchical Delegation**: Limited use, prone to complexity

## Performance and Error Handling

### Optimization Techniques
- Intelligent model selection
- Parallel execution
- Aggressive caching
- Batch processing

### Error Handling Approach
- Graceful degradation
- Intelligent retry strategies
- Always return partial results
- Explicit failure communication

## Key Takeaways

1. Keep agents stateless by default
2. Establish clear task boundaries
3. Design for quick failure detection
4. Ensure observable execution
5. Create composable, focused agents

## Implementation Recommendations

- Start simple with minimal agents
- Build monitoring from day one
- Test subagents in isolation
- Cache aggressively
- Match agent complexity to task requirements

## Monitoring Metrics

- Task completion rates
- Agent latency by type
- Error rates and categories
- Cache hit ratios
- Cost per task

---

## Application to claude-code-nix-std

### Mapping to Our Architecture

**Primary Agents (cells/agents/):**
- `claude-code` - Primary conversational agent with context
- `gemini-cli` - Alternative primary agent with extensions
- `qwen` - Agent framework with RAG capabilities

**Subagents (Specialized Tools):**
- MCP servers act as stateless subagents
- Each provides specific capabilities (git, database, filesystem)
- No shared state, pure function-like operations

**Orchestrators (cells/orchestrators/):**
- LangGraph: Sequential pipeline pattern
- CrewAI: Role-based delegation
- AutoGen: Consensus/discussion pattern

### Design Validations

✅ **Stateless Subagents**: MCP servers are inherently stateless
✅ **Clear Task Boundaries**: Each MCP server has defined capabilities
✅ **Observable Execution**: Diagnostics cell provides monitoring
✅ **Parallel Execution**: Multiple MCP servers can run concurrently
✅ **Caching**: LLM cell implements response caching

### Improvements Informed by Article

1. **Error Handling**: Ensure all orchestrators return partial results on failure
2. **Monitoring**: Add agent-specific latency metrics to diagnostics
3. **Task Decomposition**: Document vertical vs horizontal patterns in orchestrators
4. **Communication Protocol**: Standardize message schema (already in Phase 7)
5. **Cost Tracking**: Already implemented in diagnostics cell

### Implementation Patterns to Adopt

**Sequential Pipeline (LangGraph):**
```nix
# cells/orchestrators/langgraph-patterns.nix
securityAudit = buildGraph {
  nodes = [
    "scan-dependencies"    # Subagent 1
    "check-vulnerabilities" # Subagent 2
    "generate-report"      # Subagent 3
  ];
  edges = sequential;  # Output feeds next
};
```

**MapReduce (Parallel Analysis):**
```nix
codebaseAnalysis = buildGraph {
  nodes = [
    "analyze-backend"   # Parallel
    "analyze-frontend"  # Parallel
    "analyze-tests"     # Parallel
    "merge-results"     # Reduce step
  ];
  edges = mapReduce;
};
```

**Consensus (Multi-Model Validation):**
```nix
architectureDecision = buildGraph {
  nodes = [
    "claude-analysis"   # Same task
    "gemini-analysis"   # Same task
    "qwen-analysis"     # Same task
    "vote-best"         # Consensus
  ];
  edges = consensus;
};
```

### References in CLAUDE.md Files

This reference is particularly relevant to:
- **cells/orchestrators/CLAUDE.md**: Orchestration patterns
- **cells/agents/*/CLAUDE.md**: Agent design principles
- **cells/diagnostics/CLAUDE.md**: Monitoring metrics
- **cells/workspaces/CLAUDE.md**: Task decomposition

---

## Related Resources

- [LangGraph Documentation](https://langchain.com/langgraph) - State machine orchestration
- [CrewAI Documentation](https://docs.crewai.com) - Role-based teams
- [AutoGen Documentation](https://microsoft.github.io/autogen/) - Conversational agents
- [MCP Protocol Spec](https://modelcontextprotocol.io) - Communication standard
