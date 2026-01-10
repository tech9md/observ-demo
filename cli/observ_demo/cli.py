"""
Main CLI entry point for observ-demo.

This module defines the Click command-line interface with all
available commands for managing GCP observability demos.
"""

import sys
from pathlib import Path
from typing import Optional

import click
from rich.console import Console
from rich.panel import Panel

# Version import
from observ_demo import __version__

# Console for rich output
console = Console()


@click.group()
@click.version_option(version=__version__, prog_name="observ-demo")
@click.pass_context
def cli(ctx: click.Context) -> None:
    """
    GCP Observability Demo Automation Platform.

    Deploy and manage observability demos on Google Cloud Platform with
    OpenTelemetry and Google Microservices Demo applications.

    For detailed help on any command, run: observ-demo COMMAND --help
    """
    # Ensure context object exists
    ctx.ensure_object(dict)


@cli.command()
@click.option(
    "--project-id",
    help="Google Cloud Project ID (will prompt if not provided)"
)
@click.option(
    "--billing-account",
    help="GCP Billing Account ID (format: 012345-6789AB-CDEF01)"
)
@click.option(
    "--region",
    default="us-central1",
    help="Primary GCP region (default: us-central1)"
)
@click.option(
    "--skip-terraform",
    is_flag=True,
    default=False,
    help="Skip Terraform initialization"
)
@click.option(
    "--force",
    is_flag=True,
    default=False,
    help="Force re-initialization"
)
@click.pass_context
def init(
    ctx: click.Context,
    project_id: Optional[str],
    billing_account: Optional[str],
    region: str,
    skip_terraform: bool,
    force: bool
) -> None:
    """
    Initialize GCP project with required APIs and permissions.

    This command will:
    \b
    1. Validate prerequisites (gcloud, terraform, kubectl)
    2. Verify GCP authentication
    3. Validate project and billing account
    4. Initialize Terraform
    5. Create initial configuration

    Example:
        observ-demo init
        observ-demo init --project-id my-project --billing-account 012345-6789AB-CDEF01
        observ-demo init --force
    """
    from observ_demo.commands.init import init_command

    sys.exit(init_command(
        project_id=project_id,
        billing_account=billing_account,
        region=region,
        skip_terraform=skip_terraform,
        force=force
    ))


@cli.command()
@click.option(
    "--config",
    type=click.Path(exists=False, path_type=Path),
    default=Path(".config.yaml"),
    help="Path to configuration file"
)
@click.pass_context
def configure(ctx: click.Context, config: Path) -> None:
    """
    Interactive configuration wizard.

    Guides you through creating or updating the deployment configuration
    with prompts for all required settings.

    Example:
        observ-demo configure
        observ-demo configure --config my-config.yaml
    """
    console.print(Panel.fit(
        "[bold cyan]Configuration Wizard[/bold cyan]",
        subtitle="Answer the prompts to create your configuration"
    ))

    # TODO: Import and call the configure command implementation
    # from observ_demo.commands.configure import run_configuration_wizard
    # run_configuration_wizard(config)

    console.print(f"\n[yellow]⚠ Command implementation pending[/yellow]")
    console.print(f"Configuration will be saved to: {config}")


@cli.command()
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    default=Path(".config.yaml"),
    help="Path to configuration file"
)
@click.pass_context
def validate(ctx: click.Context, config: Path) -> None:
    """
    Validate prerequisites and configuration.

    Checks:
    \b
    - Required tools (gcloud, kubectl, terraform)
    - GCP authentication
    - Billing account access
    - Required API availability
    - Configuration file validity

    Example:
        observ-demo validate
        observ-demo validate --config my-config.yaml
    """
    console.print(Panel.fit(
        "[bold cyan]Validating Prerequisites[/bold cyan]",
        subtitle="Checking all requirements"
    ))

    # TODO: Import and call the validate command implementation
    # from observ_demo.commands.validate import validate_prerequisites
    # validate_prerequisites(config)

    console.print("\n[yellow]⚠ Command implementation pending[/yellow]")


@cli.command()
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    default=Path(".config.yaml"),
    help="Path to configuration file"
)
@click.option(
    "--auto-approve",
    is_flag=True,
    default=False,
    help="Skip Terraform plan approval"
)
@click.option(
    "--notify-email",
    multiple=True,
    help="Email addresses for notifications (can be specified multiple times)"
)
@click.option(
    "--notify-slack",
    help="Slack webhook URL for notifications"
)
@click.option(
    "--otel/--no-otel",
    default=True,
    help="Deploy OpenTelemetry demo"
)
@click.option(
    "--microservices/--no-microservices",
    default=True,
    help="Deploy Google Microservices demo"
)
@click.option(
    "--monitoring/--no-monitoring",
    default=True,
    help="Deploy monitoring stack"
)
@click.pass_context
def deploy(
    ctx: click.Context,
    config: Path,
    auto_approve: bool,
    notify_email: tuple,
    notify_slack: Optional[str],
    otel: bool,
    microservices: bool,
    monitoring: bool
) -> None:
    """
    Deploy complete observability demo stack.

    Deployment phases:
    \b
    1. Terraform plan and apply (infrastructure)
    2. Configure kubectl access
    3. Deploy Kubernetes manifests
    4. Validate deployments
    5. Configure IAP access
    6. Send notifications

    Example:
        observ-demo deploy
        observ-demo deploy --auto-approve --notify-email admin@example.com
    """
    console.print(Panel.fit(
        "[bold cyan]Deploying Observability Demo[/bold cyan]",
        subtitle="Estimated time: 45-75 minutes"
    ))

    console.print("\n[bold]Deployment Configuration:[/bold]")
    console.print(f"  OpenTelemetry: {'✓' if otel else '✗'}")
    console.print(f"  Microservices: {'✓' if microservices else '✗'}")
    console.print(f"  Monitoring: {'✓' if monitoring else '✗'}")
    console.print(f"  Auto-approve: {'✓' if auto_approve else '✗'}")

    if notify_email:
        console.print(f"\n[bold]Email Notifications:[/bold]")
        for email in notify_email:
            console.print(f"  • {email}")

    if notify_slack:
        console.print(f"\n[bold]Slack Notifications:[/bold] Enabled")

    from observ_demo.commands.deploy import deploy_command

    sys.exit(deploy_command(
        config_path=config,
        auto_approve=auto_approve,
        notify_email=notify_email,
        notify_slack=notify_slack,
        deploy_otel=otel,
        deploy_microservices=microservices,
        deploy_monitoring=monitoring
    ))


@cli.command()
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    default=Path(".config.yaml"),
    help="Path to configuration file"
)
@click.option(
    "--watch",
    is_flag=True,
    default=False,
    help="Continuously watch deployment status"
)
@click.pass_context
def status(ctx: click.Context, config: Path, watch: bool) -> None:
    """
    Check deployment status and health.

    Displays:
    \b
    - GKE cluster health
    - Pod status
    - Service endpoints
    - Ingress configuration
    - Cost estimate

    Example:
        observ-demo status
        observ-demo status --watch
    """
    from observ_demo.commands.status import status_command

    sys.exit(status_command(watch=watch))


@cli.command()
@click.option(
    "--estimate",
    is_flag=True,
    default=False,
    help="Estimate costs before deployment"
)
@click.option(
    "--current",
    is_flag=True,
    default=False,
    help="Show current month costs"
)
@click.option(
    "--forecast",
    is_flag=True,
    default=False,
    help="Show cost forecast"
)
@click.option(
    "--budget",
    type=float,
    help="Set monthly budget (USD)"
)
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    default=Path(".config.yaml"),
    help="Path to configuration file"
)
@click.pass_context
def cost(
    ctx: click.Context,
    estimate: bool,
    current: bool,
    forecast: bool,
    budget: Optional[float],
    config: Path
) -> None:
    """
    Cost estimation and monitoring.

    Features:
    \b
    - Pre-deployment cost estimation
    - Current spending analysis
    - Monthly forecast
    - Budget configuration
    - Cost optimization recommendations

    Example:
        observ-demo cost --estimate
        observ-demo cost --current
        observ-demo cost --budget 100
    """
    console.print(Panel.fit(
        "[bold cyan]Cost Management[/bold cyan]",
        subtitle="Tracking and optimizing costs"
    ))

    # TODO: Import and call the cost command implementation
    # from observ_demo.commands.cost import manage_costs
    # manage_costs(estimate, current, forecast, budget, config)

    console.print("\n[yellow]⚠ Command implementation pending[/yellow]")


@cli.command(name="generate-traffic")
@click.option(
    "--pattern",
    type=click.Choice(["low", "medium", "high", "spike"], case_sensitive=False),
    default="low",
    help="Traffic pattern to generate"
)
@click.option(
    "--duration",
    type=int,
    help="Override duration in seconds"
)
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    default=Path(".config.yaml"),
    help="Path to configuration file"
)
@click.pass_context
def generate_traffic(
    ctx: click.Context,
    pattern: str,
    duration: Optional[int],
    config: Path
) -> None:
    """
    Generate realistic traffic for demo applications.

    Traffic patterns:
    \b
    - low: 5 users, light browsing (1 hour)
    - medium: 20 users, moderate activity (30 min)
    - high: 50 users, heavy traffic (10 min)
    - spike: 100 users, sudden burst (5 min)

    Example:
        observ-demo generate-traffic --pattern low
        observ-demo generate-traffic --pattern high --duration 600
    """
    from observ_demo.commands.traffic import generate_traffic_command

    sys.exit(generate_traffic_command(
        pattern=pattern,
        duration=duration
    ))


@cli.command()
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    default=Path(".config.yaml"),
    help="Path to configuration file"
)
@click.pass_context
def access(ctx: click.Context, config: Path) -> None:
    """
    Get access URLs and credentials.

    Displays:
    \b
    - OpenTelemetry Demo URL
    - Microservices Demo URL
    - Cloud Trace Console URL
    - Cloud Monitoring Console URL
    - IAP access instructions

    Example:
        observ-demo access
    """
    console.print(Panel.fit(
        "[bold cyan]Access Information[/bold cyan]",
        subtitle="URLs and credentials"
    ))

    # TODO: Import and call the access command implementation
    # from observ_demo.commands.access import show_access_info
    # show_access_info(config)

    console.print("\n[yellow]⚠ Command implementation pending[/yellow]")


@cli.command()
@click.option(
    "--service",
    help="Filter logs by service name"
)
@click.option(
    "--follow",
    "-f",
    is_flag=True,
    default=False,
    help="Follow log output"
)
@click.option(
    "--tail",
    type=int,
    default=100,
    help="Number of lines to show from the end"
)
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    default=Path(".config.yaml"),
    help="Path to configuration file"
)
@click.pass_context
def logs(
    ctx: click.Context,
    service: Optional[str],
    follow: bool,
    tail: int,
    config: Path
) -> None:
    """
    View deployment logs.

    Example:
        observ-demo logs
        observ-demo logs --service otel-collector --follow
        observ-demo logs --tail 50
    """
    console.print(Panel.fit(
        "[bold cyan]Deployment Logs[/bold cyan]",
        subtitle=f"Service: {service or 'all'}"
    ))

    # TODO: Import and call the logs command implementation
    # from observ_demo.commands.logs import show_logs
    # show_logs(service, follow, tail, config)

    console.print("\n[yellow]⚠ Command implementation pending[/yellow]")


@cli.command()
@click.option(
    "--config",
    type=click.Path(exists=True, path_type=Path),
    default=Path(".config.yaml"),
    help="Path to configuration file"
)
@click.option(
    "--auto-approve",
    is_flag=True,
    default=False,
    help="Skip confirmation prompt"
)
@click.option(
    "--keep-state",
    is_flag=True,
    default=False,
    help="Keep Terraform state bucket"
)
@click.pass_context
def teardown(
    ctx: click.Context,
    config: Path,
    auto_approve: bool,
    keep_state: bool
) -> None:
    """
    Destroy all deployed resources.

    This will:
    \b
    1. Delete all Kubernetes resources
    2. Destroy GKE cluster
    3. Remove VPC and networking
    4. Clean up IAM bindings
    5. Optionally remove Terraform state bucket

    ⚠️  WARNING: This action cannot be undone!

    Example:
        observ-demo teardown
        observ-demo teardown --auto-approve --keep-state
    """
    from observ_demo.commands.teardown import teardown_command

    sys.exit(teardown_command(
        auto_approve=auto_approve,
        keep_state=keep_state
    ))


def main() -> None:
    """Main entry point for the CLI."""
    try:
        cli(obj={})
    except KeyboardInterrupt:
        console.print("\n\n[yellow]Operation cancelled by user.[/yellow]")
        sys.exit(130)
    except Exception as e:
        console.print(f"\n[bold red]Error:[/bold red] {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
