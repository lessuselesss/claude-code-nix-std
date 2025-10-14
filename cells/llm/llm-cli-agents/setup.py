"""Setup configuration for llm-cli-agents plugin"""

from setuptools import setup, find_packages

setup(
    name="llm-cli-agents",
    version="0.1.0",
    description="LLM plugin for CLI-based agent interfaces (claude-code, gemini-cli, qwen-cli)",
    long_description=open("README.md").read() if __name__ == "__main__" else "",
    long_description_content_type="text/markdown",
    author="claude-code-nix-std",
    url="https://github.com/lessuselesss/claude-code-nix-std",
    packages=find_packages(),
    install_requires=[
        "llm>=0.27",
    ],
    entry_points={
        "llm": [
            "cli_agents = llm_cli_agents.plugin",
        ]
    },
    python_requires=">=3.8",
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: Apache Software License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
)
