# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "marimo",
# ]
# ///

import marimo

__generated_with = "0.15.2"
app = marimo.App(width="full")


@app.cell
def _():
    import marimo as mo
    import json
    import re
    from pathlib import Path
    from collections import defaultdict

    mo.md("""
    # COMR Flake Explorer 🚀

    Interactive exploration of the **comr** (Claude-Open MCP Router) flake structure.
    This notebook parses and visualizes all workspaces, servers, and configurations.
    """)
    return Path, defaultdict, mo, re


@app.cell
def _(Path):
    # Load flake.nix
    flake_path = Path(__file__).parent / "flake.nix"
    flake_content = flake_path.read_text()
    return flake_content, flake_path


@app.cell
def _(flake_content, mo):
    mo.md(
        f"""
    ## Flake Overview

    **File:** `flake.nix`
    **Size:** {len(flake_content)} characters
    **Lines:** {len(flake_content.splitlines())} lines
    """
    )
    return


@app.cell
def _(flake_content, re):
    # Parse workspace definitions
    workspace_pattern = r'(\w+(?:-\w+)*)\s*=\s*\{\s*type\s*=\s*"app"'
    workspaces = re.findall(workspace_pattern, flake_content)

    # Parse server definitions from each workspace
    def extract_workspace_servers(workspace_name, content):
        """Extract servers for a specific workspace"""
        # Find the workspace block
        workspace_block_pattern = rf'{workspace_name}\s*=\s*\{{[^}}]*?mkWorkspace(?:WithAgent)?\s*"[^"]*"\s*\{{(.*?)\}}'
        match = re.search(workspace_block_pattern, content, re.DOTALL)

        if not match:
            return []

        block = match.group(1)
        server_pattern = r'(\w+(?:-\w+)*)\s*=\s*\{'
        return re.findall(server_pattern, block)

    workspace_servers = {}
    for _ws in workspaces:
        _ws_servers = extract_workspace_servers(_ws, flake_content)
        workspace_servers[_ws] = _ws_servers

    # Determine workspace types
    workspace_types = {}
    for _ws in workspaces:
        if 'mkWorkspaceWithAgent' in flake_content[flake_content.find(_ws):flake_content.find(_ws) + 1000]:
            workspace_types[_ws] = "Agent Workspace"
        else:
            workspace_types[_ws] = "Regular Workspace"
    return workspace_servers, workspace_types, workspaces


@app.cell
def _(mo, workspaces):
    mo.md(
        f"""
    ## Workspaces Summary

    **Total Workspaces:** {len(workspaces)}
    """
    )
    return


@app.cell
def _(mo, workspaces):
    # Create workspace selector
    workspace_selector = mo.ui.dropdown(
        options={ws: ws for ws in workspaces},
        value=workspaces[0] if workspaces else None,
        label="Select Workspace"
    )

    workspace_selector
    return (workspace_selector,)


@app.cell
def _(
    flake_content,
    mo,
    re,
    workspace_selector,
    workspace_servers,
    workspace_types,
):
    selected_ws = workspace_selector.value

    if selected_ws:
        ws_type = workspace_types.get(selected_ws, "Unknown")
        servers = workspace_servers.get(selected_ws, [])

        # Extract description
        desc_pattern = rf'{selected_ws}[^;]*?"([^"]*(?:workspace|with)[^"]*)"'
        desc_match = re.search(desc_pattern, flake_content)
        description = desc_match.group(1) if desc_match else "No description"

        # Extract agent info if agent workspace
        agent_info = ""
        if ws_type == "Agent Workspace":
            agent_pattern = rf'name\s*=\s*"([^"]+)".*?description\s*=\s*"([^"]+)".*?prompt\s*=\s*"([^"]+)"'
            agent_match = re.search(agent_pattern, flake_content[flake_content.find(selected_ws):], re.DOTALL)
            if agent_match:
                agent_name, agent_desc, agent_prompt = agent_match.groups()
                agent_prompt_preview = agent_prompt[:200] + "..." if len(agent_prompt) > 200 else agent_prompt
                agent_info = f"""
    ### Agent Configuration

    **Name:** `{agent_name}`
    **Description:** {agent_desc}
    **Prompt Preview:**
    > {agent_prompt_preview}
    """

        mo.md(f"""
    ## {selected_ws}

    **Type:** {ws_type}
    **Description:** {description}

    **MCP Servers ({len(servers)}):**
    {chr(10).join(f"- `{s}`" for s in servers)}

    {agent_info}

    **Usage:**
    ```bash
    nix run .#{selected_ws} "your task here"
    ```
        """)
    else:
        mo.md("*Select a workspace to view details*")
    return


@app.cell
def _(mo, workspace_servers, workspace_types):
    # Create workspace comparison table
    workspace_data = []
    for _ws, _servers in workspace_servers.items():
        workspace_data.append({
            "Workspace": _ws,
            "Type": workspace_types.get(_ws, "Unknown"),
            "Servers": len(_servers),
            "Server List": ", ".join(_servers)
        })

    # Sort by server count
    workspace_data_sorted = sorted(workspace_data, key=lambda x: x["Servers"], reverse=True)

    mo.md("## All Workspaces")
    return (workspace_data_sorted,)


@app.cell
def _(mo, workspace_data_sorted):
    mo.ui.table(workspace_data_sorted)
    return


@app.cell
def _(defaultdict, mo, workspace_servers):
    # Analyze server usage across workspaces
    server_usage = defaultdict(list)
    for _ws, _servers in workspace_servers.items():
        for _server in _servers:
            server_usage[_server].append(_ws)

    server_stats = [
        {
            "Server": _server,
            "Used in Workspaces": len(_ws_list),
            "Workspaces": ", ".join(_ws_list)
        }
        for _server, _ws_list in sorted(server_usage.items(), key=lambda x: len(x[1]), reverse=True)
    ]

    mo.md(f"""
    ## Server Usage Analysis

    **Total Unique Servers:** {len(server_usage)}
    """)
    return (server_stats,)


@app.cell
def _(mo, server_stats):
    mo.ui.table(server_stats)
    return


@app.cell
def _(mo, workspace_types):
    # Count workspace types
    regular_count = sum(1 for t in workspace_types.values() if t == "Regular Workspace")
    agent_count = sum(1 for t in workspace_types.values() if t == "Agent Workspace")

    mo.md(f"""
    ## Workspace Type Distribution

    - **Regular Workspaces:** {regular_count}
    - **Agent Workspaces:** {agent_count}

    Agent workspaces include specialized AI personas that enhance the workspace with expert knowledge.
    """)
    return


@app.cell
def _(flake_content, mo, re):
    # Extract helper function info
    helper_functions = re.findall(r'(mkWorkspace(?:WithAgent)?)\s*=', flake_content)

    mo.md(f"""
    ## Flake Architecture

    **Helper Functions:**
    {chr(10).join(f"- `{func}`" for func in helper_functions)}

    These functions generate workspace apps with appropriate MCP server configurations.
    """)
    return


@app.cell
def _(mo):
    mo.md(
        """
    ## Quick Reference

    ### Running Workspaces

    ```bash
    # Semantic routing (auto-select servers)
    nix run . "your task"

    # Specific workspace
    nix run .#python-dev "analyze script"
    nix run .#security-audit "scan vulnerabilities"
    nix run .#zen-agents "use consensus for decision"

    # List all workspaces
    nix flake show
    ```

    ### Workspace Categories

    - **Development:** python-dev, web-dev, api-dev
    - **DevOps:** devops, docker, kubernetes
    - **Quality:** security-audit, code-review, perf-optimize
    - **Research:** web-research, huggingface
    - **AI/ML:** zen-agents (multi-model orchestration)
    """
    )
    return


@app.cell
def _(flake_path, mo):
    mo.md(
        f"""
    ---

    **Flake Location:** `{flake_path}`
    **Notebook:** Self-contained with PEP 723 dependencies
    **Run:** `uv run explore-flake.py`
    """
    )
    return


if __name__ == "__main__":
    app.run()
