# llm-cli-agents

LLM plugin for CLI-based agent interfaces, enabling unified access to Claude Code, Gemini CLI, and Qwen CLI through the llm.datasette.io ecosystem.

## Overview

This plugin extends [llm](https://llm.datasette.io) to support CLI-based language model agents, providing a consistent interface for:

- **claude-code-cli**: Claude Code CLI agent with MCP servers, hooks, and plugins
- **gemini-cli**: Gemini CLI agent with extensions and multimodal support
- **qwen-cli**: Qwen CLI agent optimized for coding tasks

## Why CLI Agents?

While API-based models provide direct programmatic access, CLI agents offer:

1. **Integrated Tooling**: MCP servers, slash commands, hooks, and plugins
2. **Stateful Sessions**: Conversation history and workspace context
3. **Enhanced Features**: File operations, git integration, browser automation
4. **Local Control**: Running models through local CLI tools vs cloud APIs

## Installation

```bash
# Via pip (if published)
pip install llm-cli-agents

# Or locally in Nix (recommended)
nix build .#llm.packages.llm-full
```

## Usage

### Basic CLI Invocation

```bash
# Claude Code CLI
llm -m claude-code-cli "explain this codebase"

# Gemini CLI
llm -m gemini-cli "what are the latest AI trends?"

# Qwen CLI
llm -m qwen-cli "refactor this Python code"
```

### From Python

```python
import llm

# Use Claude Code CLI
model = llm.get_model("claude-code-cli")
response = model.prompt("analyze this repository")
print(response.text())

# Use Gemini CLI
model = llm.get_model("gemini-cli")
response = model.prompt("search recent papers on transformers")
print(response.text())
```

### From Nix

```nix
# Using LLM cell's three-layer API
llm.askClaudeCLI "task"
llm.askGeminiCLI "task"
llm.askQwenCLI "task"

# Smart backend selection
llm.askSmart "task" { preferCLI = true; }
```

## Models

### claude-code-cli

**Command**: `claude -p --output-format json --model claude-3.5-sonnet`

**Environment**: `ANTHROPIC_API_KEY`

**Features**:
- MCP server integration
- Workspace context management
- Git integration
- File operations with permissions
- Slash commands and hooks

**Example**:
```bash
export ANTHROPIC_API_KEY="sk-..."
llm -m claude-code-cli "review the security of this authentication system"
```

### gemini-cli

**Command**: `gemini chat`

**Environment**: `GEMINI_API_KEY`

**Features**:
- 70+ extensions (Stripe, GitHub, PostgreSQL, etc.)
- Multimodal support (images, documents, code)
- Plugin system for custom commands
- CI/CD integration

**Example**:
```bash
export GEMINI_API_KEY="..."
llm -m gemini-cli "search Hacker News for latest AI discussions"
```

### qwen-cli

**Command**: `qwen`

**Environment**: `DASHSCOPE_API_KEY`

**Features**:
- Optimized for coding tasks
- Free tier (2000 requests/day)
- Architecture analysis
- Code generation and refactoring

**Example**:
```bash
export DASHSCOPE_API_KEY="..."
llm -m qwen-cli "generate a REST API for user management"
```

## API Equivalents

Each CLI model has an API equivalent for fallback:

| CLI Model | API Equivalent | When to Use |
|-----------|----------------|-------------|
| claude-code-cli | claude-3.5-sonnet | Need MCP servers, hooks, workspace context |
| gemini-cli | gemini-2.0-flash | Need extensions, multimodal, web search |
| qwen-cli | qwen-2.5-coder | Need free tier, coding optimization |

The LLM cell's smart routing can automatically select between CLI and API based on requirements.

## Requirements

### CLI Tools

Each model requires its corresponding CLI tool installed:

```bash
# Claude Code (varies by OS)
# See: https://docs.claude.com/claude-code

# Gemini CLI
npm install -g gemini-cli

# Qwen CLI
npm install -g @qwen-code/qwen-code
```

### API Keys

Set appropriate environment variables:

```bash
export ANTHROPIC_API_KEY="sk-..."
export GEMINI_API_KEY="..."
export DASHSCOPE_API_KEY="..."
```

## Error Handling

The plugin provides clear error messages:

```python
# Missing API key
llm.ModelError: ANTHROPIC_API_KEY not set. Please set this environment variable to use claude-code-cli

# CLI not found
llm.ModelError: claude command not found. Please install claude-code-cli and ensure it's in your PATH.

# Timeout
llm.ModelError: claude-code-cli timed out after 5 minutes
```

## Integration with claude-code-nix-std

This plugin is part of the claude-code-nix-std modular architecture:

```
cells/llm/
├── data.nix              # Model registry (API + CLI models)
├── functions.nix         # Backend selection logic
├── lib.nix               # Three-layer API
├── packages.nix          # Package llm with plugins
├── llm-cli-agents/       # This plugin (CLI models)
│   ├── llm_cli_agents/
│   │   ├── __init__.py
│   │   └── plugin.py
│   ├── setup.py
│   └── README.md
```

## Development

### Testing Locally

```bash
cd cells/llm/llm-cli-agents
pip install -e .
llm plugins  # Should show llm-cli-agents

# Test each model
llm -m claude-code-cli "test"
llm -m gemini-cli "test"
llm -m qwen-cli "test"
```

### Adding New CLI Models

1. Add model definition to `cells/llm/data.nix`
2. Create model class in `llm_cli_agents/plugin.py`
3. Register in `register_models()` hook
4. Test with `llm -m your-model "test"`

## License

Apache 2.0

## Links

- [llm.datasette.io](https://llm.datasette.io) - Core llm tool
- [Claude Code](https://docs.claude.com/claude-code) - Claude Code CLI
- [Gemini CLI](https://geminicli.work) - Gemini CLI documentation
- [Qwen CLI](https://github.com/QwenLM/qwen-code) - Qwen Code repository
