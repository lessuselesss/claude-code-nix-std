# Lib Cell - Shared Utilities and Nushell Writers

## Purpose

Provide shared utility functions and Nushell script writers for the entire framework. This is infrastructure-level code that other cells depend on.

## Key Features

- **Nushell Writers**: Functions to create Nushell scripts with proper validation
- **Shared Utilities**: Common functions used across multiple cells
- **Type Helpers**: Nix type definitions for validation
- **Script Validation**: Syntax checking for Nushell scripts
- **Path Management**: Helper functions for consistent path handling

## Three-Layer API

**Layer 1: Simple Writers**
```nix
lib.writeNu "script-name" "nu code here"
lib.writeNuApp "app-name" "nu code here"
```

**Layer 2: Configured Writers**
```nix
lib.writeNushellScript {
  name = "script-name";
  text = "nu code";
  validate = true;
}

lib.writeNushellApplication {
  name = "app-name";
  runtimeInputs = [pkgs.jq pkgs.curl];
  text = "nu code";
  checkPhase = "custom validation";
}
```

**Layer 3: Advanced Writers**
```nix
lib.mkNushellPackage {
  name = "package-name";
  src = ./src;
  modules = ["lib.nu" "helpers.nu"];
  entrypoint = "main.nu";
  runtimeDeps = [...];
  buildPhase = "...";
  installPhase = "...";
}
```

## Files Structure

```
cells/lib/
├── CLAUDE.md (this file)
├── functions.nix    # Nushell writers and utilities
└── data.nix         # Shared constants and configurations
```

## Implementation Plan

### Phase 1: Basic Nushell Writers (Week 1, Days 1-2)

**functions.nix - Core Writers:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
  nu = pkgs.nushell;
in rec {
  # Layer 1: Simple script writer
  writeNu = name: text: writeNushellScript {
    inherit name text;
    validate = true;
  };

  # Layer 1: Simple application writer
  writeNuApp = name: text: writeNushellApplication {
    inherit name text;
    runtimeInputs = [];
  };

  # Layer 2: Script writer with validation
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

  # Layer 2: Application writer with runtime dependencies
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

        # Check that runtime inputs are referenced
        ${builtins.concatStringsSep "\n" (builtins.map (input:
          "grep -q '${input.pname or input.name}' $out/bin/${name} || echo 'Warning: ${input.pname or input.name} not used'"
        ) runtimeInputs)}
      ''
      else "";
  };

  # Layer 3: Full package builder
  mkNushellPackage = {
    name,
    src,
    modules ? [],
    entrypoint ? "main.nu",
    runtimeDeps ? [],
    buildPhase ? "",
    installPhase ? "",
    checkPhase ? ""
  }: pkgs.stdenv.mkDerivation {
    inherit name src;

    nativeBuildInputs = [ nu ] ++ runtimeDeps;

    buildPhase = if buildPhase != ""
      then buildPhase
      else ''
        # Copy modules to lib
        mkdir -p $out/lib/${name}
        ${builtins.concatStringsSep "\n" (builtins.map (mod:
          "cp ${src}/${mod} $out/lib/${name}/"
        ) modules)}

        # Validate all Nu files
        for file in ${src}/*.nu; do
          ${nu}/bin/nu --commands "nu-check $file"
        done
      '';

    installPhase = if installPhase != ""
      then installPhase
      else ''
        mkdir -p $out/bin

        # Create wrapper script
        cat > $out/bin/${name} <<'EOF'
        #!${nu}/bin/nu

        # Set module path
        let-env NU_LIB_DIRS = [$env.NU_LIB_DIRS, "${placeholder "out"}/lib/${name}"]

        # Source entrypoint
        source ${placeholder "out"}/lib/${name}/${entrypoint}

        # Run main
        main $rest
        EOF

        chmod +x $out/bin/${name}
      '';

    checkPhase = if checkPhase != ""
      then checkPhase
      else ''
        # Validate installed script
        ${nu}/bin/nu --commands 'nu-check $out/bin/${name}'

        # Run tests if they exist
        if [ -f ${src}/tests.nu ]; then
          ${nu}/bin/nu ${src}/tests.nu
        fi
      '';

    meta = {
      description = "Nushell package: ${name}";
      platforms = pkgs.lib.platforms.all;
    };
  };
}
```

### Phase 2: Shared Utilities (Week 1, Days 3-4)

**functions.nix - Utilities:**
```nix
{inputs, cell}: rec {
  # JSON helpers
  toJSON = data: builtins.toJSON data;
  fromJSON = json: builtins.fromJSON json;

  # Path helpers
  mkCacheDir = name: "$HOME/.cache/comr/${name}";
  mkConfigDir = name: "$HOME/.config/comr/${name}";
  mkLogDir = name: "$HOME/.config/comr/logs";

  # Safe path creation
  ensureDir = path: ''
    mkdir -p ${path}
  '';

  # Timestamp helpers
  timestamp = {
    iso8601 = "date -u +%Y-%m-%dT%H:%M:%SZ";
    unix = "date +%s";
    filename = "date +%Y%m%d-%H%M%S";
  };

  # UUID generation
  generateUuid = ''
    ${pkgs.util-linux}/bin/uuidgen | tr '[:upper:]' '[:lower:]'
  '';

  # Hash helpers
  hashString = str: builtins.hashString "sha256" str;
  hashFile = file: builtins.hashFile "sha256" file;

  # Validation helpers
  validateJSON = json:
    let
      parsed = builtins.tryEval (builtins.fromJSON json);
    in parsed.success;

  validatePath = path:
    builtins.pathExists path;

  # Error helpers
  throwError = msg: throw "ERROR: ${msg}";
  warnUser = msg: builtins.trace "WARNING: ${msg}";

  # List helpers
  unique = list:
    builtins.foldl' (acc: item:
      if builtins.elem item acc
      then acc
      else acc ++ [item]
    ) [] list;

  flatten = list:
    builtins.concatLists list;

  # Attribute set helpers
  mergeAttrs = sets:
    builtins.foldl' (acc: set:
      acc // set
    ) {} sets;

  filterAttrs = pred: set:
    builtins.listToAttrs (
      builtins.filter (pair: pred pair.name pair.value)
        (builtins.attrsToList set)
    );
}
```

### Phase 3: Nushell Module System (Week 1, Days 5-7)

**Shared Nushell modules for common operations:**

**functions.nix - Module Generator:**
```nix
{inputs, cell}: rec {
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

      $log_entry | to json | save --append ~/.config/comr/logs/app.log

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

      $metric | to json | save --append ~/.cache/comr/metrics/app.jsonl
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

    # Progress bar
    export def with-progress [items: list, operation: closure] {
      let total = ($items | length)
      mut completed = 0

      $items | each { |item|
        let result = (do $operation $item)
        $completed = $completed + 1

        let percent = (($completed / $total) * 100 | math round)
        print -n $"\r[($completed)/($total)] ($percent)% complete"

        $result
      }

      print ""  # New line after progress
    }

    # Parallel execution with progress
    export def par-with-progress [items: list, operation: closure] {
      let total = ($items | length)

      print $"Starting ($total) parallel operations..."

      let results = $items | par-each { |item|
        do $operation $item
      }

      print $"✓ All ($total) operations complete"

      $results
    }

    # Rate limiting
    export def rate-limit [
      operation: closure
      requests_per_second: int
    ] {
      let delay_ms = (1000 / $requests_per_second)

      do $operation
      sleep ($delay_ms | into duration --unit ms)
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

  # Include helpers in Nushell scripts
  includeHelpers = ''
    use ${mkNushellHelpers} *
  '';
}
```

### Phase 4: Type Validation (Week 2, Days 1-2)

**data.nix - Type Definitions:**
```nix
{inputs, cell}: let
  lib = inputs.nixpkgs.lib;
in {
  # Nushell script type
  nushellScriptType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Script name";
      };

      text = lib.mkOption {
        type = lib.types.str;
        description = "Nushell code";
      };

      validate = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Validate syntax";
      };
    };
  };

  # Nushell application type
  nushellApplicationType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Application name";
      };

      text = lib.mkOption {
        type = lib.types.str;
        description = "Nushell code";
      };

      runtimeInputs = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        description = "Runtime dependencies";
      };

      validate = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Validate syntax";
      };
    };
  };

  # Path type with validation
  validPathType = lib.types.addCheck lib.types.str (path:
    builtins.pathExists path
  );

  # JSON string type
  jsonStringType = lib.types.addCheck lib.types.str (json:
    let parsed = builtins.tryEval (builtins.fromJSON json);
    in parsed.success
  );
}
```

### Phase 5: Testing Infrastructure (Week 2, Days 3-4)

**functions.nix - Test Helpers:**
```nix
{inputs, cell}: rec {
  # Test a Nushell script
  testNushellScript = script: tests: pkgs.runCommand "test-${script.name}" {
    buildInputs = [ pkgs.nushell ];
  } ''
    # Run tests
    ${pkgs.nushell}/bin/nu -c '
      ${tests}

      if (test-results | where status == "failed" | length) > 0 {
        exit 1
      }
    '

    touch $out
  '';

  # Assert helpers for Nushell tests
  mkNushellAssertions = pkgs.writeText "assertions.nu" ''
    # Assertion helpers for Nushell tests

    export def assert-equal [actual: any, expected: any, message: string = ""] {
      if $actual != $expected {
        print $"❌ Assertion failed: ($message)"
        print $"  Expected: ($expected)"
        print $"  Actual: ($actual)"
        error make {msg: "Assertion failed"}
      } else {
        print $"✅ ($message)"
      }
    }

    export def assert-true [value: bool, message: string = ""] {
      if not $value {
        print $"❌ Assertion failed: ($message)"
        print $"  Expected: true"
        print $"  Actual: false"
        error make {msg: "Assertion failed"}
      } else {
        print $"✅ ($message)"
      }
    }

    export def assert-contains [list: list, item: any, message: string = ""] {
      if not ($item in $list) {
        print $"❌ Assertion failed: ($message)"
        print $"  List does not contain: ($item)"
        error make {msg: "Assertion failed"}
      } else {
        print $"✅ ($message)"
      }
    }

    export def assert-file-exists [path: string, message: string = ""] {
      if not ($path | path exists) {
        print $"❌ Assertion failed: ($message)"
        print $"  File does not exist: ($path)"
        error make {msg: "Assertion failed"}
      } else {
        print $"✅ ($message)"
      }
    }
  '';
}
```

## Integration with Other Cells

### Cells That Will Use This

**All cells will use the Nushell writers:**
- `config` - For configuration management scripts
- `diagnostics` - For log parsing and metrics collection
- `mcp` - For registry management
- `orchestrators` - For workflow execution (already using)
- `workspaces` - For session management
- `examples` - For user templates

**Usage Example:**
```nix
# cells/config/runnables.nix
{inputs, cell}: let
  writeNu = inputs.cells.lib.functions.writeNushellScript;
  writeNuApp = inputs.cells.lib.functions.writeNushellApplication;
  helpers = inputs.cells.lib.functions.includeHelpers;
in {
  show = writeNuApp {
    name = "comr-config-show";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      ${helpers}

      # Use helper functions
      let config = (safe-read-json "~/.config/comr/config.json" {})

      log "info" "Displaying configuration"
      $config | table
    '';
  };
}
```

## Testing Strategy

### Unit Tests
```nix
# Test basic script creation
testBasicScript = testNushellScript
  (writeNu "test-script" "print 'hello'")
  ''
    let result = (nu test-script)
    assert-equal $result "hello" "Basic script works"
  '';

# Test script with helpers
testWithHelpers = testNushellScript
  (writeNuApp {
    name = "test-app";
    text = ''
      ${includeHelpers}
      log "info" "test message"
    '';
  })
  ''
    let result = (nu test-app)
    assert-contains $result "test message" "Helpers work"
  '';
```

### Integration Tests
```bash
# Test that other cells can use writers
nix build .#config.runnables.show
nix run .#config.runnables.show

# Test validation catches errors
nix build .#lib.functions.writeNu -- "bad-script" "invalid nu code"  # Should fail
```

## Dependencies

### Inputs Required
- `nixpkgs` - For nushell package and stdenv
- No other cells required (this is foundation)

### Cells Produced For
- All other cells (infrastructure)

## Success Criteria

### Nushell Writers
- [ ] `writeNu` and `writeNuApp` functions work
- [ ] Syntax validation catches invalid Nushell code with `nu-check`
- [ ] Runtime dependencies are correctly added to PATH
- [ ] Nushell helper module is loadable in all scripts
- [ ] All Nushell helper functions work correctly

### Bash Writers
- [ ] `writeBash` and `writeBashApp` functions work
- [ ] ShellCheck validation catches common bash bugs
- [ ] `set -euo pipefail` warnings are displayed
- [ ] Temp file trap cleanup warnings are displayed
- [ ] Bash helper module is sourceable in all scripts
- [ ] All bash helper functions work correctly

### Shared Infrastructure
- [ ] Type validation prevents invalid inputs
- [ ] Test infrastructure functional for both Nushell and Bash
- [ ] Other cells can successfully use both Nushell and Bash writers
- [ ] Documentation complete with examples
- [ ] Decision matrix (Bash vs Nushell) is clear and actionable

## Examples

### Example 1: Simple Script
```nix
simpleScript = lib.writeNu "hello" ''
  print "Hello from Nushell!"
'';
```

### Example 2: Script with Dependencies
```nix
jsonProcessor = lib.writeNuApp {
  name = "json-processor";
  runtimeInputs = [ pkgs.jq ];
  text = ''
    let data = {"name": "test", "value": 42}
    $data | to json | ^jq '.name'
  '';
};
```

### Example 3: Script with Helpers
```nix
loggedScript = lib.writeNuApp {
  name = "logged-script";
  text = ''
    ${lib.includeHelpers}

    log "info" "Starting operation"

    let result = (timed "my-operation" {
      sleep 1sec
      "operation complete"
    })

    log "info" $"Result: ($result)"
  '';
};
```

## Migration Notes

### From Bash
- Replace `pkgs.writeShellScriptBin` with `lib.writeNuApp`
- Convert bash logic to Nushell syntax
- Use structured data instead of string parsing

### Benefits Over Bash
- Type safety with structured data
- Better error handling
- Cleaner syntax for data operations
- Native JSON support

## Future Enhancements

1. **LSP Integration**: Use Nushell LSP for advanced validation
2. **Hot Reloading**: Reload scripts without rebuild
3. **REPL Integration**: Interactive development
4. **Profiling**: Built-in performance profiling
5. **Coverage**: Test coverage reporting
6. **Package Manager**: Nushell package distribution

### Phase 6: Bash Script Writers with ShellCheck (Week 2, Days 5-7)

**Rationale: Why Keep Bash?**

While Nushell excels at data operations, bash remains essential for:
- **System Operations**: Process management, signal handling, daemon control
- **File Operations**: mkdir, cp, mv, rm (simpler than Nushell equivalents)
- **Interactive Prompts**: read -s for password input, select menus
- **External Tool Orchestration**: Complex piping with non-JSON tools
- **Nix Integration**: Easier to call nix eval and parse output

**Key Decision: Validate ALL Bash Scripts**

Just as we validate Nushell scripts with `nu-check`, we MUST validate bash scripts with `shellcheck` to catch:
- Quoting issues (SC2086, SC2046)
- Variable expansion bugs (SC2154)
- Set -e violations (SC2181)
- Unsafe temp file handling (SC2064)
- Array vs string confusion (SC2068)

**functions.nix - Bash Writers:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
  shellcheck = pkgs.shellcheck;
in rec {
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
}
```

**Decision Matrix: Bash vs Nushell**

Use **Bash** when:
- ✅ Process management (kill, trap, wait)
- ✅ Signal handling (trap INT TERM EXIT)
- ✅ Interactive prompts (read -s, select)
- ✅ File operations (mkdir -p, cp -r, mv, rm -f)
- ✅ Daemon management (background processes with &)
- ✅ Simple conditionals (if [[ -f file ]]; then)
- ✅ Integration with external tools expecting string output

Use **Nushell** when:
- ✅ JSON parsing and transformation
- ✅ Complex filtering (multi-field, nested)
- ✅ Aggregation (group-by, sum, avg)
- ✅ Table formatting and display
- ✅ Data pipelines (multiple transformations)
- ✅ Statistics (percentiles, distributions)
- ✅ Structured error handling (try/catch)

**Example: Interactive Key Setup (Bash)**
```bash
#!/usr/bin/env bash
set -euo pipefail

source ${mkBashHelpers}

main() {
  local provider="$1"
  local method="${2:-environment}"

  case "$method" in
    environment)
      setup_environment_key "$provider"
      ;;
    keyring)
      setup_keyring_key "$provider"
      ;;
    age-encrypted)
      setup_age_encrypted_key "$provider"
      ;;
    *)
      log error "Unknown method: $method"
      exit 1
      ;;
  esac
}

setup_environment_key() {
  local provider="$1"
  local key

  key=$(prompt_password "Enter $provider API key")

  if [[ -z "$key" ]]; then
    log error "Key cannot be empty"
    exit 1
  fi

  # Save to profile
  local profile="$HOME/.config/comr/profiles/default.env"
  ensure_dir "$(dirname "$profile")"

  echo "export ${provider^^}_API_KEY='$key'" >> "$profile"
  log info "API key saved to $profile"
  log info "Source this file or add to your shell profile"
}

setup_keyring_key() {
  local provider="$1"

  if ! has_command secret-tool; then
    log error "secret-tool not found. Install libsecret-tools"
    exit 1
  fi

  local key
  key=$(prompt_password "Enter $provider API key")

  echo -n "$key" | secret-tool store \
    --label="comr $provider API key" \
    application comr \
    provider "$provider"

  log info "API key stored in system keyring"
}

setup_age_encrypted_key() {
  local provider="$1"

  if ! has_command age; then
    log error "age not found. Install age encryption tool"
    exit 1
  fi

  local key
  key=$(prompt_password "Enter $provider API key")

  local key_file="$HOME/.config/comr/keys/${provider}.age"
  ensure_dir "$(dirname "$key_file")"

  # Encrypt with user's age key
  local age_pubkey="$HOME/.config/age/key.pub"
  if [[ ! -f "$age_pubkey" ]]; then
    log error "Age public key not found at $age_pubkey"
    log error "Run: age-keygen -o ~/.config/age/key.txt"
    exit 1
  fi

  echo -n "$key" | age -r "$(cat "$age_pubkey")" -o "$key_file"
  chmod 600 "$key_file"

  log info "API key encrypted and saved to $key_file"
}

main "$@"
```

**Example: Daemon Management (Bash)**
```bash
#!/usr/bin/env bash
set -euo pipefail

source ${mkBashHelpers}

start_prometheus() {
  local config="$HOME/.config/comr/prometheus.yml"
  local data_dir="$HOME/.local/share/comr/prometheus"
  local pid_file="$HOME/.local/share/comr/prometheus.pid"

  ensure_dir "$data_dir"

  if [[ -f "$pid_file" ]]; then
    local pid
    pid=$(cat "$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
      log info "Prometheus already running (PID $pid)"
      return 0
    fi
  fi

  log info "Starting Prometheus..."

  ${pkgs.prometheus}/bin/prometheus \
    --config.file="$config" \
    --storage.tsdb.path="$data_dir" \
    --web.listen-address=":9090" \
    > "$HOME/.config/comr/logs/prometheus.log" 2>&1 &

  local pid=$!
  echo "$pid" > "$pid_file"

  log info "Prometheus started (PID $pid)"
  log info "Access at http://localhost:9090"
}

stop_prometheus() {
  local pid_file="$HOME/.local/share/comr/prometheus.pid"

  if [[ ! -f "$pid_file" ]]; then
    log warning "Prometheus not running (no PID file)"
    return 0
  fi

  local pid
  pid=$(cat "$pid_file")

  if kill -0 "$pid" 2>/dev/null; then
    log info "Stopping Prometheus (PID $pid)..."
    kill -TERM "$pid"

    # Wait for graceful shutdown
    local timeout=10
    while kill -0 "$pid" 2>/dev/null && (( timeout > 0 )); do
      sleep 1
      ((timeout--))
    done

    if kill -0 "$pid" 2>/dev/null; then
      log warning "Prometheus did not stop gracefully, forcing..."
      kill -KILL "$pid"
    fi

    rm -f "$pid_file"
    log info "Prometheus stopped"
  else
    log warning "Prometheus not running (stale PID file)"
    rm -f "$pid_file"
  fi
}

main() {
  case "${1:-}" in
    start) start_prometheus ;;
    stop) stop_prometheus ;;
    restart)
      stop_prometheus
      sleep 1
      start_prometheus
      ;;
    *)
      log error "Usage: $0 {start|stop|restart}"
      exit 1
      ;;
  esac
}

main "$@"
```

**ShellCheck Configuration**

Common exclusions we use:
- `SC1090`: Can't follow non-constant source (we source helpers)
- `SC1091`: Not following sourced file (helpers are in Nix store)

**Validation in Action:**

```nix
# This PASSES validation:
goodScript = writeBash "good" ''
  set -euo pipefail

  TEMP=$(mktemp)
  trap 'rm -f "$TEMP"' EXIT

  echo "safe script" > "$TEMP"
'';

# This FAILS validation (missing quotes):
badScript = writeBash "bad" ''
  set -euo pipefail

  FILES=$(ls *.txt)
  for file in $FILES; do  # SC2068: Double quote to prevent globbing
    echo $file            # SC2086: Double quote to prevent globbing
  done
'';
# ShellCheck will catch both issues!
```

**Benefits of Validated Bash:**
- **Safety**: Catches common bugs before runtime
- **Best Practices**: Enforces quoting, pipefail, trap cleanup
- **Consistency**: All bash scripts follow same standards
- **Education**: ShellCheck messages teach better bash

**Integration with Nushell:**

Both script types can coexist:
```nix
# Bash for system operations
start-server = writeBashApp {
  name = "start-server";
  runtimeInputs = [ pkgs.systemd ];
  text = ''
    ${includeBashHelpers}
    set -euo pipefail

    log info "Starting server..."
    systemctl --user start comr-server
  '';
};

# Nushell for data operations
analyze-logs = writeNuApp {
  name = "analyze-logs";
  text = ''
    ${includeHelpers}

    let logs = (open ~/.config/comr/logs/server.log | from json)

    $logs
      | where level == "error"
      | group-by {|log| $log.timestamp | into datetime | format date "%Y-%m-%d"}
      | transpose date count
      | sort-by count --reverse
  '';
};
```

## Questions to Resolve

1. Should we vendor Nushell or always use system version?
2. How to handle Nushell version compatibility?
3. Should helpers be a separate package or always inlined?
4. How to distribute shared modules?
5. **Should we use shellcheck severity level 'error' instead of 'warning'?** (blocks build on all issues)
6. **Should we auto-add 'set -euo pipefail' if missing?** (could break intentional scripts)

## References

- [Nushell Documentation](https://www.nushell.sh/book/)
- [Nushell Cookbook](https://www.nushell.sh/cookbook/)
- [nu-check Documentation](https://www.nushell.sh/commands/docs/nu-check.html)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [ShellCheck GitHub](https://github.com/koalaman/shellcheck)
- [Bash Best Practices](https://mywiki.wooledge.org/BashGuide/Practices)
