{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in rec {
  # Base llm package from Simon Willison
  # Available in nixpkgs, so we use it directly
  llm-base = pkgs.llm;

  # Essential plugins for model providers
  # All available in nixpkgs python3Packages
  llm-plugins = {
    # Anthropic Claude plugin (llm-anthropic is the current package)
    # Note: llm-claude-3 was deprecated and replaced with llm-anthropic
    claude = pkgs.python3Packages.llm-anthropic;

    # Google Gemini plugin
    gemini = pkgs.python3Packages.llm-gemini;

    # Ollama plugin for local models
    ollama = pkgs.python3Packages.llm-ollama;
  };

  # CLI agents plugin (for CLI-based models)
  llm-cli-agents = pkgs.python3Packages.buildPythonPackage rec {
    pname = "llm-cli-agents";
    version = "0.1.0";

    src = ./llm-cli-agents;

    propagatedBuildInputs = with pkgs.python3Packages; [
      llm-base
    ];

    # Don't run tests during build (requires CLI tools installed)
    doCheck = false;

    meta = with pkgs.lib; {
      description = "LLM plugin for CLI-based agent interfaces (claude-code, gemini-cli, qwen-cli)";
      homepage = "https://github.com/lessuselesss/claude-code-nix-std";
      license = licenses.asl20;
    };
  };

  # llm with essential API plugins pre-installed
  llm-with-plugins = pkgs.python3.withPackages (ps: [
    llm-base
    llm-plugins.claude
    llm-plugins.gemini
    llm-plugins.ollama
  ]);

  # Main llm package (convenience wrapper)
  llm = pkgs.writeShellScriptBin "llm" ''
    #!${pkgs.bash}/bin/bash
    export PATH="${llm-with-plugins}/bin:$PATH"
    export PYTHONPATH="${llm-with-plugins}/${pkgs.python3.sitePackages}:$PYTHONPATH"

    # Set default llm data directory
    export LLM_USER_PATH="''${LLM_USER_PATH:-$HOME/.local/share/llm}"

    exec ${llm-with-plugins}/bin/llm "$@"
  '';

  # Full llm with ALL plugins (API + CLI agents)
  llm-full = pkgs.python3.withPackages (ps: [
    llm-base
    llm-plugins.claude
    llm-plugins.gemini
    llm-plugins.ollama
    llm-cli-agents  # CLI-based models
  ]);

  # llm-full wrapper script
  llm-with-cli-agents = pkgs.writeShellScriptBin "llm" ''
    #!${pkgs.bash}/bin/bash
    export PATH="${llm-full}/bin:$PATH"
    export PYTHONPATH="${llm-full}/${pkgs.python3.sitePackages}:$PYTHONPATH"

    # Set default llm data directory
    export LLM_USER_PATH="''${LLM_USER_PATH:-$HOME/.local/share/llm}"

    # Add CLI tools to PATH if available from agents cells
    # These will be added when agents cells are implemented
    # export PATH="${inputs.cells.agents.claude-code.packages.claude}/bin:$PATH"
    # export PATH="${inputs.cells.agents.gemini-cli.packages.gemini}/bin:$PATH"

    exec ${llm-full}/bin/llm "$@"
  '';
}
