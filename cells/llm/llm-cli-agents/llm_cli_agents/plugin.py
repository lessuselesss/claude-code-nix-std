"""
LLM CLI Agents Plugin

Provides CLI-based model interfaces for:
- claude-code-cli: Claude Code CLI agent
- gemini-cli: Gemini CLI agent
- qwen-cli: Qwen CLI agent

These models route to local CLI tools instead of API endpoints,
enabling integrated agent experiences with MCP servers, hooks, and plugins.
"""

import llm
import subprocess
import json
import os
import sys
from typing import Optional, List


@llm.hookimpl
def register_models(register):
    """Register CLI-based models with llm"""
    register(ClaudeCodeCLI())
    register(GeminiCLI())
    register(QwenCLI())


class CLIModel(llm.Model):
    """Base class for CLI-based language models"""

    # Subclasses must define these
    model_id: str
    api_key_env: Optional[str] = None
    cli_command: str
    cli_args: List[str] = []

    def execute(self, prompt, stream, response, conversation):
        """Execute CLI command and return response"""
        # Check for API key if required
        if self.api_key_env:
            api_key = os.getenv(self.api_key_env)
            if not api_key:
                raise llm.ModelError(
                    f"{self.api_key_env} not set. "
                    f"Please set this environment variable to use {self.model_id}"
                )

        # Build command
        cmd = self.build_command(prompt.prompt)

        # Execute CLI
        try:
            result = subprocess.run(
                cmd,
                input=prompt.prompt if self.needs_stdin() else None,
                capture_output=True,
                text=True,
                env=os.environ,
                timeout=300  # 5 minute timeout
            )

            # Check for errors
            if result.returncode != 0:
                error_msg = result.stderr or f"Command failed with exit code {result.returncode}"
                raise llm.ModelError(f"{self.model_id} error: {error_msg}")

            # Parse output
            output_text = self.parse_output(result.stdout, result.stderr)

            # Store raw response for debugging
            response.response_json = {
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }

            return [output_text]

        except subprocess.TimeoutExpired:
            raise llm.ModelError(f"{self.model_id} timed out after 5 minutes")
        except FileNotFoundError:
            raise llm.ModelError(
                f"{self.cli_command} command not found. "
                f"Please install {self.model_id} and ensure it's in your PATH."
            )
        except Exception as e:
            raise llm.ModelError(f"{self.model_id} execution error: {str(e)}")

    def build_command(self, prompt: str) -> List[str]:
        """Build CLI command - override in subclasses"""
        return [self.cli_command] + self.cli_args + [prompt]

    def needs_stdin(self) -> bool:
        """Whether this CLI expects input via stdin - override if needed"""
        return False

    def parse_output(self, stdout: str, stderr: str) -> str:
        """Parse CLI output - override in subclasses if special handling needed"""
        return stdout.strip()


class ClaudeCodeCLI(CLIModel):
    """Claude Code CLI agent interface"""

    model_id = "claude-code-cli"
    api_key_env = "ANTHROPIC_API_KEY"
    cli_command = "claude"
    cli_args = ["-p", "--output-format", "json", "--model", "claude-3.5-sonnet"]

    def build_command(self, prompt: str) -> List[str]:
        """Build claude CLI command"""
        # Claude takes prompt as argument, not stdin
        return [self.cli_command] + self.cli_args + [prompt]

    def parse_output(self, stdout: str, stderr: str) -> str:
        """Parse Claude Code JSON output"""
        try:
            # Claude --output-format json returns structured response
            data = json.loads(stdout)

            # Extract text from response
            if isinstance(data, dict):
                # Try various possible keys
                return (
                    data.get("text") or
                    data.get("content") or
                    data.get("response") or
                    str(data)
                )
            else:
                return str(data)

        except json.JSONDecodeError:
            # Fall back to raw stdout if not valid JSON
            return stdout.strip()


class GeminiCLI(CLIModel):
    """Gemini CLI agent interface"""

    model_id = "gemini-cli"
    api_key_env = "GEMINI_API_KEY"
    cli_command = "gemini"
    cli_args = ["chat"]

    def build_command(self, prompt: str) -> List[str]:
        """Build gemini CLI command"""
        # gemini chat "prompt"
        return [self.cli_command] + self.cli_args + [prompt]

    def parse_output(self, stdout: str, stderr: str) -> str:
        """Parse Gemini CLI output (plain text)"""
        # Gemini CLI returns plain text responses
        return stdout.strip()


class QwenCLI(CLIModel):
    """Qwen CLI agent interface"""

    model_id = "qwen-cli"
    api_key_env = "DASHSCOPE_API_KEY"
    cli_command = "qwen"
    cli_args = []

    def build_command(self, prompt: str) -> List[str]:
        """Build qwen CLI command"""
        # qwen "prompt"
        return [self.cli_command, prompt]

    def parse_output(self, stdout: str, stderr: str) -> str:
        """Parse Qwen CLI output (plain text)"""
        return stdout.strip()
