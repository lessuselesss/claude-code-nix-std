# Reference Library

This directory contains external articles, specifications, and research that inform the design and implementation of claude-code-nix-std.

## Index

### Architecture & Design Patterns

#### [Agentic AI Best Practices](./agentic-ai-best-practices.md)
**Source:** UserJot Blog
**Relevance:** Multi-agent orchestration patterns, error handling, production deployment
**Key Topics:**
- Two-tier agent model (primary + subagents)
- Stateless subagent design
- Task decomposition strategies (vertical/horizontal)
- Orchestration patterns (sequential, MapReduce, consensus)
- Performance optimization and error handling

**Applications to Our Project:**
- Validates our MCP-as-subagent architecture
- Informs orchestrator patterns (LangGraph, CrewAI, AutoGen)
- Guides diagnostics/monitoring implementation
- Shapes error handling strategy

---

## How to Add New References

### 1. Fetch and Save Article

```bash
# Use WebFetch to get article content
# Save to docs/references/<descriptive-name>.md

# Include at the top:
# - Source URL
# - Date retrieved
# - Relevance to project
# - Key topics
```

### 2. Add Metadata Section

Each reference should include:
- **Source**: Original URL or citation
- **Date Retrieved**: When content was captured
- **Relevance**: Why this matters to the project
- **Key Topics**: Main concepts covered
- **Applications**: How it applies to our architecture

### 3. Update This Index

Add entry under appropriate category with:
- Link to file
- Brief description
- Key topics list
- Application notes

### 4. Cross-Reference in CLAUDE.md Files

Add references to relevant cell documentation:

```markdown
## References

- [Agentic AI Best Practices](../../docs/references/agentic-ai-best-practices.md) - Orchestration patterns
```

---

## Categories

### Architecture & Design Patterns
High-level system design, architectural patterns, best practices

### Protocols & Specifications
MCP protocol, API specs, communication standards

### Research & Papers
Academic papers, research findings, whitepapers

### Implementation Guides
Practical implementation examples, code patterns, tutorials

### Tools & Frameworks
Documentation for tools we integrate (LangGraph, DSPy, etc.)

---

## Suggested References to Add

### High Priority

- [ ] **MCP Protocol Specification**
  - Source: https://modelcontextprotocol.io
  - Relevance: Core protocol for agent-tool communication

- [ ] **DSPy: Programming Foundation Models**
  - Source: https://github.com/stanfordnlp/dspy
  - Relevance: Prompt optimization framework

- [ ] **LangGraph Documentation**
  - Source: https://langchain.com/langgraph
  - Relevance: State machine orchestration pattern

- [ ] **divnix std Documentation**
  - Source: https://std.divnix.com
  - Relevance: Core framework for our cell architecture

### Medium Priority

- [ ] **Nix Flakes RFC**
  - Source: https://github.com/NixOS/rfcs/blob/master/rfcs/0136-flakes.md
  - Relevance: Understanding flake architecture

- [ ] **Prompt Engineering Guide**
  - Source: https://www.promptingguide.ai
  - Relevance: Prompt optimization best practices

- [ ] **OpenTelemetry for AI Systems**
  - Source: https://opentelemetry.io
  - Relevance: Distributed tracing implementation

### Low Priority

- [ ] **Attention Is All You Need** (Transformers paper)
  - Relevance: Understanding LLM architecture

- [ ] **ReAct: Synergizing Reasoning and Acting**
  - Relevance: Agent reasoning patterns

---

## Maintenance

- Review references quarterly for updated content
- Archive outdated references with date stamps
- Update cross-references when moving files
- Keep index synchronized with actual files

---

## Related Directories

- `docs/architecture/` - Architecture Decision Records (ADRs)
- `cells/examples/` - Implementation examples and templates
- `cells/*/CLAUDE.md` - Cell-specific planning documents
