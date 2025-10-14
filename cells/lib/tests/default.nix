{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};

  # Import the lib cell functions
  writeNu = cell.functions.writeNu;
  writeNuApp = cell.functions.writeNuApp;
  writeNushellApplication = cell.functions.writeNushellApplication;
  writeBash = cell.functions.writeBash;
  writeBashApp = cell.functions.writeBashApp;
  writeBashApplication = cell.functions.writeBashApplication;
  includeHelpers = cell.functions.includeHelpers;
  includeBashHelpers = cell.functions.includeBashHelpers;
in {
  # Test 1: Simple Nushell script
  test-nu-simple = writeNu "test-nu-simple" ''
    print "Hello from Nushell!"
    print $"Current directory: (pwd)"
  '';

  # Test 2: Nushell script with helpers
  test-nu-with-helpers = writeNuApp "test-nu-with-helpers" ''
    ${includeHelpers}

    def main [] {
      log "info" "Testing Nushell helpers"

      # Test safe directory creation
      ensure-dir "~/.cache/comr/test"

      # Test logging levels
      log "debug" "This is a debug message"
      log "warning" "This is a warning"
      log "error" "This is an error message"

      print "✓ Nushell helpers test completed"
    }
  '';

  # Test 3: Nushell application with runtime inputs
  test-nu-with-deps = writeNushellApplication {
    name = "test-nu-with-deps";
    runtimeInputs = [ pkgs.jq pkgs.curl ];
    text = ''
      ${includeHelpers}

      def main [] {
        log "info" "Testing Nushell with runtime dependencies"

        # Test that jq is available
        let jq_version = (safe-command "jq" "--version")
        print $"jq version: ($jq_version)"

        # Test that curl is available
        let curl_version = (safe-command "curl" "--version" | lines | first)
        print $"curl version: ($curl_version)"

        print "✓ Runtime dependencies test completed"
      }
    '';
  };

  # Test 4: Simple bash script
  test-bash-simple = writeBash "test-bash-simple" ''
    set -euo pipefail

    echo "Hello from Bash!"
    echo "Current directory: $(pwd)"
  '';

  # Test 5: Bash script with helpers
  test-bash-with-helpers = writeBashApp "test-bash-with-helpers" ''
    ${includeBashHelpers}
    set -euo pipefail

    main() {
      log info "Testing bash helpers"

      # Test safe directory creation
      ensure_dir "$HOME/.cache/comr/test"

      # Test logging levels
      log debug "This is a debug message"
      log warning "This is a warning"
      log error "This is an error message"

      echo "✓ Bash helpers test completed"
    }

    main "$@"
  '';

  # Test 6: Bash application with runtime inputs
  test-bash-with-deps = writeBashApplication {
    name = "test-bash-with-deps";
    runtimeInputs = [ pkgs.jq pkgs.curl ];
    text = ''
      ${includeBashHelpers}
      set -euo pipefail

      main() {
        log info "Testing bash with runtime dependencies"

        # Test that jq is available
        local jq_version
        jq_version=$(jq --version)
        echo "jq version: $jq_version"

        # Test that curl is available
        local curl_version
        curl_version=$(curl --version | head -n1)
        echo "curl version: $curl_version"

        echo "✓ Runtime dependencies test completed"
      }

      main "$@"
    '';
  };

  # Test 7: Nushell script testing retry functionality
  test-nu-retry = writeNuApp "test-nu-retry" ''
    ${includeHelpers}

    def main [] {
      log "info" "Testing retry functionality"

      # Simulate a failing operation that succeeds on 3rd try
      mut attempt_count = 0

      let result = retry {
        $attempt_count = $attempt_count + 1
        if $attempt_count < 3 {
          error make {msg: "Simulated failure"}
        } else {
          "Success!"
        }
      } 5 500

      print $"Final result: ($result)"
      print "✓ Retry test completed"
    }
  '';

  # Test 8: Bash script testing retry functionality
  test-bash-retry = writeBashApp "test-bash-retry" ''
    ${includeBashHelpers}
    set -euo pipefail

    # Simulated failing command
    failing_command() {
      local attempt_file="/tmp/bash-retry-test-$$"
      local attempts

      if [[ ! -f "$attempt_file" ]]; then
        echo "0" > "$attempt_file"
      fi

      attempts=$(cat "$attempt_file")
      attempts=$((attempts + 1))
      echo "$attempts" > "$attempt_file"

      if [[ $attempts -lt 3 ]]; then
        log warning "Attempt $attempts failed (simulated)"
        rm -f "$attempt_file"
        return 1
      else
        log info "Attempt $attempts succeeded"
        rm -f "$attempt_file"
        return 0
      fi
    }

    main() {
      log info "Testing retry functionality"

      if retry 5 failing_command; then
        echo "✓ Retry test completed successfully"
      else
        log error "Retry test failed"
        exit 1
      fi
    }

    main "$@"
  '';

  # Test runner script (Nushell)
  run-all-tests = writeNuApp "run-all-tests" ''
    def main [] {
      print "Running lib cell tests..."
      print ""

      let tests = [
        "test-nu-simple"
        "test-nu-with-helpers"
        "test-nu-with-deps"
        "test-bash-simple"
        "test-bash-with-helpers"
        "test-bash-with-deps"
        "test-nu-retry"
        "test-bash-retry"
      ]

      mut passed = 0
      mut failed = 0

      for test in $tests {
        print $"Running ($test)..."

        try {
          ^$test
          print $"✓ ($test) passed"
          print ""
          $passed = $passed + 1
        } catch { |err|
          print $"✗ ($test) failed: ($err.msg)"
          print ""
          $failed = $failed + 1
        }
      }

      print "===================="
      print $"Tests passed: ($passed)"
      print $"Tests failed: ($failed)"

      if $failed > 0 {
        exit 1
      }
    }
  '';
}
