{inputs, cell}: let
  lib = inputs.nixpkgs.lib;
in {
  # Configuration file locations
  paths = {
    config = "$HOME/.config/comr";
    cache = "$HOME/.cache/comr";
    logs = "$HOME/.config/comr/logs";
    metrics = "$HOME/.cache/comr/metrics";
    checkpoints = "$HOME/.cache/comr/orchestrator/checkpoints";
    queues = "$HOME/.cache/comr/orchestrator/queues";
  };

  # Common constants
  constants = {
    version = "1.0.0";
    maxRetries = 3;
    defaultTimeout = 300;  # 5 minutes in seconds
    defaultTTL = 3600;     # 1 hour in seconds
    maxLogFileSize = 10485760;  # 10MB
  };

  # Script validation defaults
  validation = {
    nushell = {
      enabled = true;
      checkCommand = "nu-check";
    };
    bash = {
      enabled = true;
      checkCommand = "shellcheck";
      severity = "warning";
      excludedRules = ["SC1090" "SC1091"];  # Can't follow non-constant source
      runtimeChecks = true;
    };
  };

  # Helper module versions
  helpers = {
    nushell = {
      version = "1.0.0";
      functions = [
        "log"
        "track-metric"
        "ensure-dir"
        "safe-read"
        "safe-read-json"
        "retry"
        "timed"
        "cached"
        "require-env"
        "safe-command"
      ];
    };
    bash = {
      version = "1.0.0";
      functions = [
        "log"
        "ensure_dir"
        "safe_command"
        "retry"
        "setup_cleanup"
        "require_env"
        "confirm"
        "prompt_password"
        "make_temp"
        "has_command"
        "timed"
      ];
    };
  };

  # Log levels
  logLevels = ["debug" "info" "warning" "error" "critical"];

  # Metric types
  metricTypes = ["counter" "gauge" "histogram" "summary"];

  # Common environment variables
  envVars = {
    debug = "DEBUG";
    logLevel = "LOG_LEVEL";
    configDir = "COMR_CONFIG_DIR";
    cacheDir = "COMR_CACHE_DIR";
  };
}
