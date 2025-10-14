# Lib Cell - Foundation Writers and Utilities

## Status: ✅ Implemented

Foundation cell providing validated script writers and shared utilities for all other cells.

## Files

- **functions.nix** - Nushell and bash writers with validation
- **data.nix** - Shared constants and paths
- **tests/default.nix** - Test suite with 8 test scripts
- **CLAUDE.md** - Detailed planning and architecture

## Exports

### Nushell Writers

```nix
# Simple writers (Layer 1)
writeNu "script-name" "nu code"
writeNuApp "app-name" "nu code"

# Advanced writers (Layer 2)
writeNushellScript { name, text, validate ? true }
writeNushellApplication { name, text, runtimeInputs ? [], validate ? true }
```

### Bash Writers

```nix
# Simple writers (Layer 1)
writeBash "script-name" "bash code"
writeBashApp "app-name" "bash code"

# Advanced writers (Layer 2)
writeBashScript { name, text, validate ? true, runtimeChecks ? true }
writeBashApplication { name, text, runtimeInputs ? [], validate ? true }
```

### Helper Modules

```nix
# Nushell helpers
includeHelpers  # Source the Nushell helper module
mkNushellHelpers  # The helper module itself

# Bash helpers
includeBashHelpers  # Source the bash helper module
mkBashHelpers  # The helper module itself
```

## Features

### Validation

**Nushell:**
- ✅ `nu-check` syntax validation
- ✅ Runtime input usage warnings
- ✅ Automatic shebang addition

**Bash:**
- ✅ `shellcheck` validation (severity: warning)
- ✅ `set -euo pipefail` checks
- ✅ Temp file trap cleanup warnings
- ✅ Automatic shebang addition

### Helper Functions

**Nushell (10 functions):**
- `log` - Structured logging with levels
- `track-metric` - Metrics tracking
- `ensure-dir` - Safe directory creation
- `safe-read` - Safe file reading with defaults
- `safe-read-json` - Safe JSON parsing
- `retry` - Exponential backoff retry
- `timed` - Timed operation execution
- `cached` - TTL-based caching
- `require-env` - Environment variable validation
- `safe-command` - Safe external command execution

**Bash (11 functions):**
- `log` - Structured logging
- `ensure_dir` - Safe directory creation
- `safe_command` - Safe command execution
- `retry` - Exponential backoff retry
- `setup_cleanup` - Cleanup trap handler
- `require_env` - Environment variable validation
- `confirm` - Interactive confirmation
- `prompt_password` - Secure password prompt
- `make_temp` - Safe temp file creation with auto-cleanup
- `has_command` - Command existence check
- `timed` - Timed operation execution

## Usage Example

```nix
{inputs, cell}: let
  writeNuApp = inputs.cells.lib.functions.writeNushellApplication;
  helpers = inputs.cells.lib.functions.includeHelpers;
  writeBashApp = inputs.cells.lib.functions.writeBashApplication;
  bashHelpers = inputs.cells.lib.functions.includeBashHelpers;
in {
  # Nushell tool with helpers
  my-nu-tool = writeNuApp {
    name = "my-tool";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      ${helpers}

      def main [target: string] {
        log "info" "Processing target: $target"

        let result = retry {
          safe-command "jq" ".data" $target
        } 3 1000

        print $result
      }
    '';
  };

  # Bash tool with helpers
  my-bash-tool = writeBashApp {
    name = "my-bash-tool";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      ${bashHelpers}
      set -euo pipefail

      main() {
        log info "Fetching data..."

        local temp
        temp=$(make_temp)

        if retry 3 curl -o "$temp" https://api.example.com/data; then
          log info "Data fetched successfully"
          cat "$temp"
        fi
      }

      main "$@"
    '';
  };
}
```

## Testing

Run tests:
```bash
# Once dependencies are downloaded:
nix run .#lib.tests.test-nu-simple
nix run .#lib.tests.test-nu-with-helpers
nix run .#lib.tests.test-bash-simple
nix run .#lib.tests.test-bash-with-helpers
nix run .#lib.tests.run-all-tests
```

## Dependencies

- `nixpkgs` - For nushell, shellcheck, bash
- No cell dependencies (this is foundation)

## Next Steps

This lib cell is now ready to be consumed by:
- [ ] config cell
- [ ] diagnostics cell
- [ ] mcp cell
- [ ] agents/* cells
- [ ] orchestrators cell
- [ ] All other cells

## Implementation Notes

- All scripts validated at build time
- Helper modules are inlined for zero runtime dependencies
- ShellCheck excludes SC1090/SC1091 (can't follow sourced files)
- Nushell helpers use structured data throughout
- Bash helpers follow modern bash best practices
