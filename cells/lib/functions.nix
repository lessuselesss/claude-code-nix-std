{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
  nu = pkgs.nushell;
  shellcheck = pkgs.shellcheck;
in rec {
  #############################################################################
  # Nushell Writers
  #############################################################################

  # Layer 1: Simple Nushell script writer
  writeNu = name: text: writeNushellScript {
    inherit name text;
    validate = true;
  };

  # Layer 1: Simple Nushell application writer
  writeNuApp = name: text: writeNushellApplication {
    inherit name text;
    runtimeInputs = [];
  };

  # Layer 2: Nushell script writer with validation
  writeNushellScript = {
    name,
    text,
    validate ? true,
    checkPhase ? null
  }: pkgs.writeTextFile {
    inherit name;
    executable = true;
    destination = "/bin/${name}";

    text = ''
      #!${nu}/bin/nu
      ${text}
    '';

    checkPhase = if checkPhase != null
      then checkPhase
      else if validate
      then ''
        # Validate Nushell syntax
        ${nu}/bin/nu --commands 'nu-check $out/bin/${name}'
      ''
      else "";
  };

  # Layer 2: Nushell application writer with runtime dependencies
  writeNushellApplication = {
    name,
    text,
    runtimeInputs ? [],
    validate ? true,
    checkPhase ? null
  }: pkgs.writeTextFile {
    inherit name;
    executable = true;
    destination = "/bin/${name}";

    text = ''
      #!${nu}/bin/nu

      # Add runtime inputs to PATH
      ${builtins.concatStringsSep "\n" (builtins.map (input:
        "let-env PATH = ($env.PATH | prepend '${input}/bin')"
      ) runtimeInputs)}

      ${text}
    '';

    checkPhase = if checkPhase != null
      then checkPhase
      else if validate
      then ''
        # Validate Nushell syntax
        ${nu}/bin/nu --commands 'nu-check $out/bin/${name}'

        # Check that runtime inputs are referenced (warning only)
        ${builtins.concatStringsSep "\n" (builtins.map (input:
          let inputName = input.pname or input.name;
          in ''
            if ! grep -q '${inputName}' $out/bin/${name}; then
              echo 'Warning: runtime input ${inputName} not used in script'
            fi
          ''
        ) runtimeInputs)}
      ''
      else "";
  };

  #############################################################################
  # Bash Writers
  #############################################################################

  # Layer 1: Simple bash script writer
  writeBash = name: text: writeBashScript {
    inherit name text;
    validate = true;
  };

  # Layer 1: Simple bash application writer
  writeBashApp = name: text: writeBashApplication {
    inherit name text;
    runtimeInputs = [];
  };

  # Layer 2: Bash script writer with shellcheck validation
  writeBashScript = {
    name,
    text,
    validate ? true,
    checkPhase ? null,
    runtimeChecks ? true  # Check for set -euo pipefail
  }: pkgs.writeTextFile {
    inherit name;
    executable = true;
    destination = "/bin/${name}";

    text = ''
      #!/usr/bin/env bash
      ${text}
    '';

    checkPhase = if checkPhase != null
      then checkPhase
      else if validate
      then ''
        # Validate bash syntax with bash -n
        ${pkgs.bash}/bin/bash -n $out/bin/${name}

        # Validate with shellcheck
        ${shellcheck}/bin/shellcheck \
          --shell=bash \
          --severity=warning \
          --exclude=SC1090,SC1091 \
          $out/bin/${name}

        # Runtime checks
        ${if runtimeChecks then ''
          # Check for set -euo pipefail (or similar)
          if ! grep -qE 'set -[a-z]*e[a-z]*u' $out/bin/${name}; then
            echo "WARNING: Script does not use 'set -eu' or 'set -euo pipefail'"
            echo "This is recommended for safer bash scripts"
          fi

          # Check for trap cleanup
          if grep -q 'mktemp\|TEMP=' $out/bin/${name}; then
            if ! grep -q 'trap.*EXIT\|trap.*cleanup' $out/bin/${name}; then
              echo "WARNING: Script uses temp files but no trap cleanup found"
              echo "Consider: trap 'rm -f \$TEMP' EXIT"
            fi
          fi
        '' else ""}
      ''
      else "";
  };

  # Layer 2: Bash application writer with runtime dependencies
  writeBashApplication = {
    name,
    text,
    runtimeInputs ? [],
    validate ? true,
    checkPhase ? null,
    runtimeChecks ? true
  }: pkgs.writeTextFile {
    inherit name;
    executable = true;
    destination = "/bin/${name}";

    text = ''
      #!/usr/bin/env bash

      # Add runtime inputs to PATH
      export PATH="${pkgs.lib.makeBinPath runtimeInputs}:$PATH"

      ${text}
    '';

    checkPhase = if checkPhase != null
      then checkPhase
      else if validate
      then ''
        # Validate bash syntax
        ${pkgs.bash}/bin/bash -n $out/bin/${name}

        # Validate with shellcheck
        ${shellcheck}/bin/shellcheck \
          --shell=bash \
          --severity=warning \
          --exclude=SC1090,SC1091 \
          $out/bin/${name}

        # Check that runtime inputs are referenced
        ${builtins.concatStringsSep "\n" (builtins.map (input:
          let inputName = input.pname or input.name;
          in ''
            if ! grep -q '${inputName}' $out/bin/${name}; then
              echo 'Warning: runtime input ${inputName} not used in script'
            fi
          ''
        ) runtimeInputs)}

        # Runtime checks
        ${if runtimeChecks then ''
          if ! grep -qE 'set -[a-z]*e[a-z]*u' $out/bin/${name}; then
            echo "WARNING: Script does not use 'set -eu'"
          fi
        '' else ""}
      ''
      else "";
  };

  #############################################################################
  # Helper Modules
  #############################################################################

  # Generate common Nushell helper module
  mkNushellHelpers = pkgs.writeText "helpers.nu" ''
    # Common helper functions for all Nushell scripts

    # Logging
    export def log [level: string, message: string] {
      let timestamp = (date now | date to-record)
      let log_entry = {
        timestamp: $timestamp
        level: $level
        message: $message
      }

      let log_dir = "~/.config/comr/logs"
      mkdir $log_dir
      $log_entry | to json | save --append ($log_dir + "/app.log")

      match $level {
        "error" => { print -e $"❌ ($message)" }
        "warning" => { print -e $"⚠️  ($message)" }
        "info" => { print $"ℹ️  ($message)" }
        "debug" => { if ($env.DEBUG? | default false) { print $"🔍 ($message)" } }
        _ => { print $message }
      }
    }

    # Metrics tracking
    export def track-metric [name: string, value: number, labels: record = {}] {
      let metric = {
        timestamp: (date now | date to-record)
        metric: $name
        value: $value
        labels: $labels
      }

      let metrics_dir = "~/.cache/comr/metrics"
      mkdir $metrics_dir
      $metric | to json | save --append ($metrics_dir + "/app.jsonl")
    }

    # Safe directory creation
    export def ensure-dir [path: string] {
      if not ($path | path exists) {
        mkdir $path
      }
    }

    # Safe file read
    export def safe-read [path: string, default = null] {
      if ($path | path exists) {
        try {
          open $path
        } catch { |err|
          log "warning" $"Failed to read ($path): ($err.msg)"
          $default
        }
      } else {
        $default
      }
    }

    # Safe JSON read
    export def safe-read-json [path: string, default = {}] {
      if ($path | path exists) {
        try {
          open $path | from json
        } catch { |err|
          log "warning" $"Failed to parse JSON from ($path): ($err.msg)"
          $default
        }
      } else {
        $default
      }
    }

    # Retry with exponential backoff
    export def retry [
      operation: closure
      max_retries: int = 3
      initial_delay: int = 1000
    ] {
      mut attempt = 0
      mut last_error = null

      while $attempt < $max_retries {
        try {
          return (do $operation)
        } catch { |err|
          $last_error = $err
          $attempt = $attempt + 1

          if $attempt < $max_retries {
            let delay = $initial_delay * (2 ** $attempt)
            log "warning" $"Retry attempt ($attempt)/($max_retries) after ($delay)ms"
            sleep ($delay | into duration --unit ms)
          }
        }
      }

      log "error" $"Max retries exceeded: ($last_error.msg)"
      error make $last_error
    }

    # Timed operation
    export def timed [name: string, operation: closure] {
      let start = (date now)

      let result = try {
        do $operation
      } catch { |err|
        {error: $err}
      }

      let duration = ((date now) - $start | into duration | into int)

      track-metric $"operation.duration" $duration {operation: $name}

      if "error" in $result {
        log "error" $"Operation ($name) failed after ($duration)ms"
        error make $result.error
      } else {
        log "debug" $"Operation ($name) completed in ($duration)ms"
        $result
      }
    }

    # Cache with TTL
    export def cached [
      key: string
      ttl: int
      operation: closure
    ] {
      let cache_dir = "~/.cache/comr/cache"
      ensure-dir $cache_dir

      let cache_file = $"($cache_dir)/($key).json"

      if ($cache_file | path exists) {
        let cached = (safe-read-json $cache_file)
        let age = ((date now) - ($cached.timestamp | into datetime) | into int)

        if $age < $ttl {
          log "debug" $"Cache hit for ($key)"
          return $cached.value
        }
      }

      log "debug" $"Cache miss for ($key), executing operation"
      let value = (do $operation)

      {
        timestamp: (date now | date to-record)
        key: $key
        value: $value
      } | to json | save -f $cache_file

      $value
    }

    # Validate required env vars
    export def require-env [...vars: string] {
      for var in $vars {
        if ($env | get -i $var) == null {
          log "error" $"Required environment variable not set: ($var)"
          error make {msg: $"Missing environment variable: ($var)"}
        }
      }
    }

    # Safe command execution
    export def safe-command [command: string, ...args: string] {
      try {
        let result = (^$command ...$args | complete)

        if $result.exit_code == 0 {
          $result.stdout
        } else {
          log "error" $"Command failed: ($command) ($args)"
          log "error" $"Exit code: ($result.exit_code)"
          log "error" $"Stderr: ($result.stderr)"
          error make {
            msg: $"Command failed with exit code ($result.exit_code)"
            exit_code: $result.exit_code
            stderr: $result.stderr
          }
        }
      } catch { |err|
        log "error" $"Failed to execute command: ($command)"
        error make $err
      }
    }
  '';

  # Include Nushell helpers in scripts
  includeHelpers = ''
    use ${mkNushellHelpers} *
  '';

  # Bash helpers module (sourced in bash scripts)
  mkBashHelpers = pkgs.writeText "bash-helpers.sh" ''
    # Common helper functions for bash scripts

    # Logging
    log() {
      local level="$1"
      shift
      local message="$*"
      local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

      case "$level" in
        error)   echo "❌ $message" >&2 ;;
        warning) echo "⚠️  $message" >&2 ;;
        info)    echo "ℹ️  $message" ;;
        debug)   [[ -n "$DEBUG" ]] && echo "🔍 $message" ;;
        *)       echo "$message" ;;
      esac

      # Log to file
      local log_file="$HOME/.config/comr/logs/app.log"
      mkdir -p "$(dirname "$log_file")"
      echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\"}" >> "$log_file"
    }

    # Safe directory creation
    ensure_dir() {
      local dir="$1"
      if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
      fi
    }

    # Safe command execution
    safe_command() {
      local cmd=("$@")
      local output
      local exit_code

      if output=$("''${cmd[@]}" 2>&1); then
        echo "$output"
        return 0
      else
        exit_code=$?
        log error "Command failed: ''${cmd[*]}"
        log error "Exit code: $exit_code"
        log error "Output: $output"
        return $exit_code
      fi
    }

    # Retry with exponential backoff
    retry() {
      local max_retries="$1"
      shift
      local cmd=("$@")

      local attempt=0
      local delay=1

      while (( attempt < max_retries )); do
        if "''${cmd[@]}"; then
          return 0
        fi

        ((attempt++))
        if (( attempt < max_retries )); then
          log warning "Retry attempt $attempt/$max_retries after ''${delay}s"
          sleep "$delay"
          delay=$((delay * 2))
        fi
      done

      log error "Max retries exceeded"
      return 1
    }

    # Cleanup handler
    setup_cleanup() {
      local cleanup_fn="$1"
      # shellcheck disable=SC2064
      trap "$cleanup_fn" EXIT INT TERM
    }

    # Validate required environment variables
    require_env() {
      local missing=()
      for var in "$@"; do
        if [[ -z "''${!var:-}" ]]; then
          missing+=("$var")
        fi
      done

      if (( ''${#missing[@]} > 0 )); then
        log error "Missing required environment variables: ''${missing[*]}"
        return 1
      fi
    }

    # Prompt for confirmation
    confirm() {
      local prompt="$1"
      local reply

      read -r -p "$prompt [y/N] " reply
      case "$reply" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
      esac
    }

    # Secure password prompt
    prompt_password() {
      local prompt="$1"
      local password

      read -r -s -p "$prompt: " password
      echo >&2  # New line after hidden input
      echo "$password"
    }

    # Safe temp file creation
    make_temp() {
      local template="''${1:-comr.XXXXXX}"
      local temp
      temp=$(mktemp "/tmp/$template")

      # Auto-cleanup
      # shellcheck disable=SC2064
      trap "rm -f '$temp'" EXIT

      echo "$temp"
    }

    # Check if command exists
    has_command() {
      command -v "$1" >/dev/null 2>&1
    }

    # Timed operation
    timed() {
      local name="$1"
      shift
      local cmd=("$@")

      local start
      start=$(date +%s)

      if "''${cmd[@]}"; then
        local end
        end=$(date +%s)
        local duration=$((end - start))
        log debug "Operation $name completed in ''${duration}s"
        return 0
      else
        local exit_code=$?
        local end
        end=$(date +%s)
        local duration=$((end - start))
        log error "Operation $name failed after ''${duration}s"
        return $exit_code
      fi
    }
  '';

  # Include bash helpers
  includeBashHelpers = ''
    source ${mkBashHelpers}
  '';

  #############################################################################
  # Shared Utilities
  #############################################################################

  # JSON helpers
  toJSON = data: builtins.toJSON data;
  fromJSON = json: builtins.fromJSON json;

  # Path helpers
  mkCacheDir = name: "$HOME/.cache/comr/${name}";
  mkConfigDir = name: "$HOME/.config/comr/${name}";
  mkLogDir = name: "$HOME/.config/comr/logs";

  # Timestamp helpers
  timestamp = {
    iso8601 = "date -u +%Y-%m-%dT%H:%M:%SZ";
    unix = "date +%s";
    filename = "date +%Y%m%d-%H%M%S";
  };

  # Hash helpers
  hashString = str: builtins.hashString "sha256" str;
  hashFile = file: builtins.hashFile "sha256" file;

  # UUID generation helper (bash-based)
  generateUuid = pkgs.writeShellScript "generate-uuid" ''
    ${pkgs.util-linux}/bin/uuidgen | tr '[:upper:]' '[:lower:]'
  '';
}
