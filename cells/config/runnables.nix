{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};

  # Import writers from lib cell (when available)
  # For now, use direct pkgs writers
  writeNuApp = name: text: pkgs.writeTextFile {
    inherit name;
    executable = true;
    destination = "/bin/${name}";
    text = ''
      #!${pkgs.nushell}/bin/nu
      ${text}
    '';
  };

  writeBashApp = name: text: pkgs.writeTextFile {
    inherit name;
    executable = true;
    destination = "/bin/${name}";
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      ${text}
    '';
  };
in {
  # Bash: Initialize config file
  init = writeBashApp "comr-config-init" ''
    CONFIG_DIR="''${HOME}/.config/comr"
    CONFIG_FILE="''${CONFIG_DIR}/config.json"

    echo "🔧 Initializing comr configuration..."

    # Create config directory
    mkdir -p "''${CONFIG_DIR}"

    # Write default config
    cat > "''${CONFIG_FILE}" <<'EOF'
${builtins.toJSON cell.data.defaults}
EOF

    echo "✅ Configuration initialized at ''${CONFIG_FILE}"
    echo ""
    echo "Next steps:"
    echo "1. Set API keys: export ANTHROPIC_API_KEY=sk-..."
    echo "2. Or use keyring: comr config set-key anthropic keyring"
    echo "3. Configure preferences: comr config show"
  '';

  # Bash: Interactive API key setup
  set-key = writeBashApp "comr-config-set-key" ''
    if [[ $# -lt 1 ]]; then
      echo "Usage: $0 <provider> [storage-method]"
      echo "Providers: anthropic, google, openai, openrouter, dashscope, huggingface, github, slack"
      echo "Storage methods: environment, keyring, age-encrypted"
      exit 1
    fi

    PROVIDER="$1"
    STORAGE="''${2:-environment}"

    echo "🔑 Setting API key for ''${PROVIDER} using ''${STORAGE} storage..."

    case "''${STORAGE}" in
      environment)
        local env_var
        case "''${PROVIDER}" in
          anthropic) env_var="ANTHROPIC_API_KEY" ;;
          google) env_var="GEMINI_API_KEY" ;;
          openai) env_var="OPENAI_API_KEY" ;;
          openrouter) env_var="OPENROUTER_API_KEY" ;;
          dashscope) env_var="DASHSCOPE_API_KEY" ;;
          huggingface) env_var="HF_TOKEN" ;;
          github) env_var="GITHUB_TOKEN" ;;
          slack) env_var="SLACK_TOKEN" ;;
          *) echo "Unknown provider: ''${PROVIDER}"; exit 1 ;;
        esac

        echo "Add to your shell profile:"
        echo "  export ''${env_var}=your-key-here"
        ;;

      keyring)
        if ! command -v secret-tool &> /dev/null; then
          echo "Error: secret-tool not found. Install libsecret-tools"
          exit 1
        fi

        echo -n "Enter API key for ''${PROVIDER}: "
        read -s API_KEY
        echo

        if [[ -z "''${API_KEY}" ]]; then
          echo "Error: API key cannot be empty"
          exit 1
        fi

        echo -n "''${API_KEY}" | secret-tool store \
          --label="comr ''${PROVIDER} API Key" \
          service comr \
          provider "''${PROVIDER}"

        echo "✅ API key stored in system keyring"
        ;;

      age-encrypted)
        if ! command -v age &> /dev/null; then
          echo "Error: age not found. Install age encryption tool"
          exit 1
        fi

        echo -n "Enter API key for ''${PROVIDER}: "
        read -s API_KEY
        echo

        if [[ -z "''${API_KEY}" ]]; then
          echo "Error: API key cannot be empty"
          exit 1
        fi

        SECRETS_FILE="''${HOME}/.config/comr/secrets.age"
        AGE_KEY_FILE="''${HOME}/.config/comr/age-key.txt"

        # Generate age key if not exists
        if [[ ! -f "''${AGE_KEY_FILE}" ]]; then
          ${pkgs.age}/bin/age-keygen -o "''${AGE_KEY_FILE}"
          chmod 600 "''${AGE_KEY_FILE}"
          echo "⚠️  Age key generated. BACKUP THIS FILE: ''${AGE_KEY_FILE}"
        fi

        # Read existing secrets or create new
        SECRETS="{}"
        if [[ -f "''${SECRETS_FILE}" ]]; then
          SECRETS=$(${pkgs.age}/bin/age -d -i "''${AGE_KEY_FILE}" "''${SECRETS_FILE}")
        fi

        # Update secrets
        UPDATED=$(echo "''${SECRETS}" | ${pkgs.jq}/bin/jq ".apiKeys.\"''${PROVIDER}\" = \"''${API_KEY}\"")

        # Encrypt and save
        TEMP=$(mktemp)
        trap "rm -f ''${TEMP}" EXIT

        echo "''${UPDATED}" | ${pkgs.age}/bin/age -e -i "''${AGE_KEY_FILE}" -o "''${TEMP}"
        mv "''${TEMP}" "''${SECRETS_FILE}"
        chmod 600 "''${SECRETS_FILE}"

        echo "✅ API key encrypted and stored"
        ;;

      *)
        echo "Unknown storage method: ''${STORAGE}"
        echo "Valid methods: environment, keyring, age-encrypted"
        exit 1
        ;;
    esac
  '';

  # Nushell: Display configuration
  show = writeNuApp "comr-config-show" ''
    def main [] {
      let config_file = $"($env.HOME)/.config/comr/config.json"

      if not ($config_file | path exists) {
        print "Configuration not found. Run: comr config init"
        exit 1
      }

      let config = (open $config_file | from json)

      # Display configuration
      print "📋 Configuration Overview"
      print "========================="
      print ""

      # Active profile
      print $"Active Profile: ($config.activeProfile)"
      print ""

      # Profile details
      let profile = ($config.profiles | get ($config.activeProfile))

      print "User Preferences:"
      print $"  Default Model: ($profile.preferences.defaultModel)"
      print $"  Default Reasoning Model: ($profile.preferences.defaultReasoningModel)"
      print $"  Default Code Model: ($profile.preferences.defaultCodeModel)"
      print $"  Temperature: ($profile.preferences.temperature)"
      print $"  Max Tokens: ($profile.preferences.maxTokens)"
      print $"  Stream Responses: ($profile.preferences.streamResponses)"
      print ""

      # Cost limits
      print "Cost Limits:"
      print $"  Max Cost Per Request: \$($profile.limits.maxCostPerRequest)"
      print $"  Max Cost Per Day: \$($profile.limits.maxCostPerDay)"
      print $"  Max Cost Per Month: \$($profile.limits.maxCostPerMonth)"
      print $"  Max Tokens Per Request: ($profile.limits.maxTokensPerRequest)"
      print $"  Warn Threshold: ($profile.limits.warnThresholdPercent)%"
      print $"  Hard Stop: ($profile.limits.hardStop)"
      print ""

      # Rate limits
      print "Rate Limits:"
      if $profile.rateLimits.requestsPerMinute != null {
        print $"  Requests Per Minute: ($profile.rateLimits.requestsPerMinute)"
      }
      if $profile.rateLimits.requestsPerHour != null {
        print $"  Requests Per Hour: ($profile.rateLimits.requestsPerHour)"
      }
      if $profile.rateLimits.tokensPerMinute != null {
        print $"  Tokens Per Minute: ($profile.rateLimits.tokensPerMinute)"
      }
      print $"  Concurrent Requests: ($profile.rateLimits.concurrentRequests)"
      print $"  Backoff Strategy: ($profile.rateLimits.backoffStrategy)"
      print ""

      # Storage
      print "Storage:"
      print $"  API Keys: ($config.storage.apiKeys)"
      print $"  Config Dir: ($config.storage.configDir)"
      print ""

      # Telemetry
      print "Telemetry:"
      print $"  Enabled: ($config.telemetry.enabled)"
    }
  '';

  # Nushell: List API keys status
  list-keys = writeNuApp "comr-config-list-keys" ''
    def main [] {
      print "🔑 API Keys Status"
      print "================="
      print ""

      let providers = [
        {name: "anthropic", var: "ANTHROPIC_API_KEY", format: "sk-ant-*"}
        {name: "google", var: "GEMINI_API_KEY", format: "*"}
        {name: "openai", var: "OPENAI_API_KEY", format: "sk-*"}
        {name: "openrouter", var: "OPENROUTER_API_KEY", format: "sk-or-*"}
        {name: "dashscope", var: "DASHSCOPE_API_KEY", format: "sk-*"}
        {name: "github", var: "GITHUB_TOKEN", format: "gh[ps]_*"}
        {name: "slack", var: "SLACK_TOKEN", format: "xoxb-*"}
        {name: "huggingface", var: "HF_TOKEN", format: "hf_*"}
      ]

      $providers | each {|prov|
        let value = ($env | get -i $prov.var)
        let is_set = ($value != null)

        {
          provider: $prov.name
          status: (if $is_set { "✅ Set" } else { "❌ Not Set" })
          format_expected: $prov.format
        }
      } | table
    }
  '';

  # Nushell: Compare profiles
  compare-profiles = writeNuApp "comr-config-compare-profiles" ''
    def main [profile1: string, profile2: string] {
      let config_file = $"($env.HOME)/.config/comr/config.json"

      if not ($config_file | path exists) {
        print "Configuration not found"
        exit 1
      }

      let config = (open $config_file | from json)

      print $"🔄 Comparing Profiles: ($profile1) vs ($profile2)"
      print "=" * 50
      print ""

      let p1 = ($config.profiles | get $profile1)
      let p2 = ($config.profiles | get $profile2)

      # Compare preferences
      print "User Preferences:"
      [
        {
          setting: "Default Model"
          ($profile1): $p1.preferences.defaultModel
          ($profile2): $p2.preferences.defaultModel
        }
        {
          setting: "Temperature"
          ($profile1): $p1.preferences.temperature
          ($profile2): $p2.preferences.temperature
        }
        {
          setting: "Max Tokens"
          ($profile1): $p1.preferences.maxTokens
          ($profile2): $p2.preferences.maxTokens
        }
      ] | table
      print ""

      # Compare limits
      print "Cost Limits:"
      [
        {
          setting: "Max Cost Per Request"
          ($profile1): $p1.limits.maxCostPerRequest
          ($profile2): $p2.limits.maxCostPerRequest
        }
        {
          setting: "Max Cost Per Day"
          ($profile1): $p1.limits.maxCostPerDay
          ($profile2): $p2.limits.maxCostPerDay
        }
        {
          setting: "Hard Stop"
          ($profile1): $p1.limits.hardStop
          ($profile2): $p2.limits.hardStop
        }
      ] | table
      print ""

      # Compare rate limits
      print "Rate Limits:"
      [
        {
          setting: "Requests Per Minute"
          ($profile1): $p1.rateLimits.requestsPerMinute
          ($profile2): $p2.rateLimits.requestsPerMinute
        }
        {
          setting: "Concurrent Requests"
          ($profile1): $p1.rateLimits.concurrentRequests
          ($profile2): $p2.rateLimits.concurrentRequests
        }
      ] | table
    }
  '';

  # Bash: Get config value
  get = writeBashApp "comr-config-get" ''
    CONFIG_FILE="''${HOME}/.config/comr/config.json"

    if [[ $# -lt 1 ]]; then
      echo "Usage: $0 <key>"
      exit 1
    fi

    KEY="$1"

    ${pkgs.jq}/bin/jq -r ".''${KEY}" "''${CONFIG_FILE}"
  '';

  # Bash: Set config value
  set = writeBashApp "comr-config-set" ''
    CONFIG_FILE="''${HOME}/.config/comr/config.json"

    if [[ $# -lt 2 ]]; then
      echo "Usage: $0 <key> <value>"
      exit 1
    fi

    KEY="$1"
    VALUE="$2"

    # Update config
    TEMP=$(mktemp)
    trap "rm -f ''${TEMP}" EXIT

    ${pkgs.jq}/bin/jq ".''${KEY} = \"''${VALUE}\"" "''${CONFIG_FILE}" > "''${TEMP}"
    mv "''${TEMP}" "''${CONFIG_FILE}"

    echo "✅ Set ''${KEY} = ''${VALUE}"
  '';

  # Bash: Switch active profile
  switch-profile = writeBashApp "comr-config-switch-profile" ''
    if [[ $# -lt 1 ]]; then
      echo "Usage: $0 <profile>"
      echo "Profiles: dev, staging, prod"
      exit 1
    fi

    PROFILE="$1"

    echo "🔄 Switching to profile: ''${PROFILE}"

    ${pkgs.bash}/bin/bash $(dirname $0)/comr-config-set activeProfile "''${PROFILE}"

    echo "✅ Active profile: ''${PROFILE}"
  '';

  # Bash: Validate configuration
  validate = writeBashApp "comr-config-validate" ''
    CONFIG_FILE="''${HOME}/.config/comr/config.json"

    echo "🔍 Validating configuration..."

    # Check config file exists
    if [[ ! -f "''${CONFIG_FILE}" ]]; then
      echo "❌ Config file not found: ''${CONFIG_FILE}"
      exit 1
    fi

    # Validate JSON syntax
    if ! ${pkgs.jq}/bin/jq empty "''${CONFIG_FILE}" 2>/dev/null; then
      echo "❌ Invalid JSON syntax"
      exit 1
    fi

    # Check required fields
    REQUIRED_FIELDS="version activeProfile profiles storage"
    for FIELD in ''${REQUIRED_FIELDS}; do
      if ! ${pkgs.jq}/bin/jq -e ".''${FIELD}" "''${CONFIG_FILE}" >/dev/null 2>&1; then
        echo "❌ Missing required field: ''${FIELD}"
        exit 1
      fi
    done

    echo "✅ Configuration is valid"
  '';
}
