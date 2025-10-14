# Minimal test of lib cell writers
{ pkgs ? import <nixpkgs> {} }:

let
  # Import lib cell
  lib = import ./cells/lib/functions.nix {
    inputs = {
      nixpkgs.legacyPackages = { x86_64-linux = pkgs; };
      system = "x86_64-linux";
    };
    cell = {
      functions = {};
      data = {};
    };
  };

in {
  # Test 1: Simple Nushell script
  test-nu = lib.writeNu "test-nu" ''
    print "Hello from Nushell!"
  '';

  # Test 2: Simple bash script
  test-bash = lib.writeBash "test-bash" ''
    set -euo pipefail
    echo "Hello from Bash!"
  '';

  # Test 3: Nushell with helpers
  test-nu-helpers = lib.writeNuApp "test-nu-helpers" ''
    ${lib.includeHelpers}

    def main [] {
      log "info" "Testing helpers"
      print "Done!"
    }
  '';
}
