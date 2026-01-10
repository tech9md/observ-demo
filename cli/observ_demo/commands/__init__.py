"""
Commands package for observ-demo CLI.

This package contains all command implementations:
- init: Project initialization and prerequisites validation
- deploy: Infrastructure and application deployment
- status: Deployment health and status checks
- teardown: Resource cleanup and destruction
- cost: Cost estimation and monitoring
- traffic: Traffic generation for demos
"""

__all__ = [
    "init",
    "deploy",
    "status",
    "teardown",
    "cost",
    "traffic",
]
