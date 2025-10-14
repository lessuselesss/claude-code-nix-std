{
  description = "Universal Multi-Agent CLI Orchestration Framework - A modular framework for CLI agent ecosystems using divnix std";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # divnix std for cell organization
    std = {
      url = "github:divnix/std";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, std, ... } @ inputs:
    std.growOn {
      inherit inputs;

      # All cells are discovered from ./cells directory
      cellsFrom = ./cells;

      # Define cell block types for our framework
      cellBlocks = with std.blockTypes; [
        # Runnable applications (apps)
        # Examples: workspace runners, orchestration runners, agent runners
        (runnables "runnables" {
          ci.build = true;
          ci.run = true;
        })

        # Packages (binaries, CLI tools)
        # Examples: llm CLI, claude CLI, gemini CLI, qwen CLI
        (installables "packages" {
          ci.build = true;
        })

        # Library functions (public API)
        # Examples: llm.ask, orchestrators.langgraph, mcp.getServer
        (functions "lib" {
          ci.build = false;
        })

        # Internal functions (implementation details)
        # Examples: server transformations, intent analysis, graph traversal
        (functions "functions" {
          ci.build = false;
        })

        # Data definitions (registries, configurations)
        # Examples: model registry, MCP server registry, agent definitions
        (data "data" {
          ci.build = false;
        })
      ];

      # Organize cells into systems
      nixpkgsConfig = {
        allowUnfree = true;
      };
    }

    # Harvest outputs for standard flake structure (backward compatibility)
    {
      # Harvest apps from runnables
      apps = std.harvest self [
        # Foundation cells
        ["lib" "tests"]  # Test runners for lib cell
        ["llm" "runnables"]
        ["config" "runnables"]
        ["diagnostics" "runnables"]

        # Agent cells
        ["agents" "claude-code" "runnables"]
        ["agents" "gemini-cli" "runnables"]
        ["agents" "qwen" "runnables"]

        # Orchestration cells
        ["orchestrators" "runnables"]

        # Infrastructure cells
        ["mcp" "runnables"]
        ["routing" "runnables"]
        ["prompts" "runnables"]

        # High-level cells
        ["workspaces" "runnables"]
        ["marketplaces" "runnables"]

        # Example cells
        ["examples" "runnables"]
      ];

      # Harvest packages
      packages = std.harvest self [
        # Foundation packages
        ["llm" "packages"]
        ["diagnostics" "packages"]

        # Agent packages
        ["agents" "claude-code" "packages"]
        ["agents" "gemini-cli" "packages"]
        ["agents" "qwen" "packages"]
      ];

      # Harvest library functions for programmatic access
      lib = std.harvest self [
        # Foundation
        ["lib" "functions"]  # Nushell and bash writers
        ["lib" "data"]       # Shared constants and paths
        ["llm" "lib"]
        ["config" "lib"]
        ["diagnostics" "lib"]

        # Agents
        ["agents" "claude-code" "lib"]
        ["agents" "gemini-cli" "lib"]
        ["agents" "qwen" "lib"]

        # Orchestration
        ["orchestrators" "lib"]

        # Infrastructure
        ["mcp" "lib"]
        ["routing" "lib"]
        ["prompts" "lib"]

        # High-level
        ["workspaces" "lib"]
        ["marketplaces" "lib"]
      ];
    };
}
