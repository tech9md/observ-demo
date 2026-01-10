"""
Init Command - GCP Project Initialization

This module implements the 'init' command which:
- Validates prerequisites (gcloud, terraform, kubectl)
- Verifies GCP authentication
- Validates project and billing account
- Enables required GCP APIs
- Initializes Terraform
- Creates initial configuration
"""

import os
import subprocess
import sys
from pathlib import Path
from typing import Optional, Tuple

import click
from rich.console import Console
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.prompt import Confirm, Prompt
from rich.table import Table

console = Console()


class PrerequisiteChecker:
    """Validates required tools and configurations."""

    REQUIRED_TOOLS = {
        "gcloud": {"min_version": "450.0.0", "install_url": "https://cloud.google.com/sdk/docs/install"},
        "terraform": {"min_version": "1.6.0", "install_url": "https://developer.hashicorp.com/terraform/downloads"},
        "kubectl": {"min_version": "1.28.0", "install_url": "https://kubernetes.io/docs/tasks/tools/"},
    }

    @staticmethod
    def run_command(cmd: list, capture_output: bool = True) -> Tuple[int, str, str]:
        """Run a shell command and return exit code, stdout, stderr."""
        try:
            result = subprocess.run(
                cmd,
                capture_output=capture_output,
                text=True,
                timeout=30,
            )
            return result.returncode, result.stdout.strip(), result.stderr.strip()
        except subprocess.TimeoutExpired:
            return 1, "", "Command timed out"
        except FileNotFoundError:
            return 1, "", f"Command not found: {cmd[0]}"
        except Exception as e:
            return 1, "", str(e)

    @staticmethod
    def check_tool_installed(tool: str) -> bool:
        """Check if a tool is installed."""
        code, _, _ = PrerequisiteChecker.run_command([tool, "--version"])
        return code == 0

    @staticmethod
    def get_tool_version(tool: str) -> Optional[str]:
        """Get the version of an installed tool."""
        if tool == "gcloud":
            code, stdout, _ = PrerequisiteChecker.run_command(["gcloud", "version"])
            if code == 0:
                # Extract version from "Google Cloud SDK 450.0.0"
                for line in stdout.split("\n"):
                    if "Google Cloud SDK" in line:
                        parts = line.split()
                        if len(parts) >= 4:
                            return parts[3]
        elif tool == "terraform":
            code, stdout, _ = PrerequisiteChecker.run_command(["terraform", "version"])
            if code == 0:
                # Extract version from "Terraform v1.6.0"
                first_line = stdout.split("\n")[0]
                if "v" in first_line:
                    return first_line.split("v")[1].split()[0]
        elif tool == "kubectl":
            code, stdout, _ = PrerequisiteChecker.run_command(["kubectl", "version", "--client", "--short"])
            if code == 0:
                # Extract version from "Client Version: v1.28.0"
                if "v" in stdout:
                    return stdout.split("v")[1].split()[0]
        return None

    @staticmethod
    def compare_versions(current: str, minimum: str) -> bool:
        """Compare version strings (simple semantic versioning)."""
        try:
            current_parts = [int(x) for x in current.split(".")[:3]]
            minimum_parts = [int(x) for x in minimum.split(".")[:3]]
            return current_parts >= minimum_parts
        except (ValueError, IndexError):
            return False

    def check_prerequisites(self) -> bool:
        """Check all prerequisites and display results."""
        console.print(Panel.fit("[bold cyan]Checking Prerequisites[/bold cyan]"))

        table = Table(show_header=True, header_style="bold magenta")
        table.add_column("Tool", style="cyan", width=12)
        table.add_column("Required", style="yellow", width=12)
        table.add_column("Installed", style="green", width=12)
        table.add_column("Status", width=15)

        all_ok = True

        for tool, info in self.REQUIRED_TOOLS.items():
            min_version = info["min_version"]

            if not self.check_tool_installed(tool):
                table.add_row(tool, min_version, "Not Found", "[red]✗ Missing[/red]")
                console.print(f"\n[yellow]Install {tool}:[/yellow] {info['install_url']}")
                all_ok = False
            else:
                current_version = self.get_tool_version(tool)
                if current_version and self.compare_versions(current_version, min_version):
                    table.add_row(tool, min_version, current_version, "[green]✓ OK[/green]")
                else:
                    status = f"[yellow]⚠ Update needed[/yellow]"
                    table.add_row(tool, min_version, current_version or "Unknown", status)
                    console.print(f"\n[yellow]Update {tool}:[/yellow] {info['install_url']}")

        console.print(table)
        return all_ok


class GCPAuthChecker:
    """Validates GCP authentication and permissions."""

    @staticmethod
    def check_gcloud_auth() -> bool:
        """Check if user is authenticated with gcloud."""
        code, stdout, _ = PrerequisiteChecker.run_command(
            ["gcloud", "auth", "list", "--filter=status:ACTIVE", "--format=value(account)"]
        )
        if code == 0 and stdout:
            console.print(f"[green]✓[/green] Authenticated as: [cyan]{stdout.split()[0]}[/cyan]")
            return True
        return False

    @staticmethod
    def check_application_default_credentials() -> bool:
        """Check if application default credentials are configured."""
        code, stdout, _ = PrerequisiteChecker.run_command(
            ["gcloud", "auth", "application-default", "print-access-token"]
        )
        return code == 0

    @staticmethod
    def prompt_authentication() -> bool:
        """Prompt user to authenticate with gcloud."""
        console.print("\n[yellow]GCP authentication required[/yellow]")

        if Confirm.ask("Run 'gcloud auth login' now?"):
            code, _, stderr = PrerequisiteChecker.run_command(
                ["gcloud", "auth", "login"], capture_output=False
            )
            if code != 0:
                console.print(f"[red]Authentication failed:[/red] {stderr}")
                return False

        if Confirm.ask("Run 'gcloud auth application-default login' now?"):
            code, _, stderr = PrerequisiteChecker.run_command(
                ["gcloud", "auth", "application-default", "login"], capture_output=False
            )
            if code != 0:
                console.print(f"[red]Application default authentication failed:[/red] {stderr}")
                return False

        return True


class GCPProjectValidator:
    """Validates GCP project and billing configuration."""

    @staticmethod
    def list_projects() -> list:
        """List all accessible GCP projects."""
        code, stdout, _ = PrerequisiteChecker.run_command(
            ["gcloud", "projects", "list", "--format=value(projectId)"]
        )
        if code == 0 and stdout:
            return stdout.split("\n")
        return []

    @staticmethod
    def project_exists(project_id: str) -> bool:
        """Check if a project exists and is accessible."""
        code, _, _ = PrerequisiteChecker.run_command(
            ["gcloud", "projects", "describe", project_id]
        )
        return code == 0

    @staticmethod
    def get_billing_account(project_id: str) -> Optional[str]:
        """Get the billing account for a project."""
        code, stdout, _ = PrerequisiteChecker.run_command(
            ["gcloud", "billing", "projects", "describe", project_id, "--format=value(billingAccountName)"]
        )
        if code == 0 and stdout:
            # Extract billing account ID from full name
            # Format: billingAccounts/012345-6789AB-CDEF01
            if "billingAccounts/" in stdout:
                return stdout.split("billingAccounts/")[1].strip()
        return None

    @staticmethod
    def list_billing_accounts() -> list:
        """List all accessible billing accounts."""
        code, stdout, _ = PrerequisiteChecker.run_command(
            ["gcloud", "billing", "accounts", "list", "--format=value(name)"]
        )
        if code == 0 and stdout:
            # Extract billing account IDs from full names
            accounts = []
            for line in stdout.split("\n"):
                if "billingAccounts/" in line:
                    accounts.append(line.split("billingAccounts/")[1].strip())
            return accounts
        return []

    @staticmethod
    def set_project(project_id: str) -> bool:
        """Set the current gcloud project."""
        code, _, stderr = PrerequisiteChecker.run_command(
            ["gcloud", "config", "set", "project", project_id]
        )
        if code == 0:
            console.print(f"[green]✓[/green] Set project to: [cyan]{project_id}[/cyan]")
            return True
        console.print(f"[red]Failed to set project:[/red] {stderr}")
        return False


class TerraformInitializer:
    """Handles Terraform initialization."""

    def __init__(self, terraform_dir: Path):
        self.terraform_dir = terraform_dir

    def init_terraform(self, reconfigure: bool = False) -> bool:
        """Initialize Terraform."""
        console.print("\n[bold cyan]Initializing Terraform[/bold cyan]")

        cmd = ["terraform", "init"]
        if reconfigure:
            cmd.append("-reconfigure")

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console,
        ) as progress:
            task = progress.add_task("Downloading providers and modules...", total=None)

            code, stdout, stderr = PrerequisiteChecker.run_command(
                cmd, capture_output=True
            )

            progress.update(task, completed=True)

        if code == 0:
            console.print("[green]✓[/green] Terraform initialized successfully")
            return True
        else:
            console.print(f"[red]✗ Terraform initialization failed:[/red]")
            console.print(stderr)
            return False

    def validate_terraform(self) -> bool:
        """Validate Terraform configuration."""
        console.print("\n[bold cyan]Validating Terraform Configuration[/bold cyan]")

        code, stdout, stderr = PrerequisiteChecker.run_command(
            ["terraform", "validate", "-json"]
        )

        if code == 0:
            console.print("[green]✓[/green] Terraform configuration is valid")
            return True
        else:
            console.print(f"[red]✗ Terraform validation failed:[/red]")
            console.print(stderr)
            return False


def init_command(
    project_id: Optional[str] = None,
    billing_account: Optional[str] = None,
    region: str = "us-central1",
    skip_terraform: bool = False,
    force: bool = False,
):
    """
    Initialize GCP project for observability demo deployment.

    This command:
    1. Validates prerequisites (gcloud, terraform, kubectl)
    2. Verifies GCP authentication
    3. Validates project and billing account
    4. Initializes Terraform
    5. Creates initial configuration

    Args:
        project_id: GCP project ID (will prompt if not provided)
        billing_account: GCP billing account ID (will prompt if not provided)
        region: GCP region (default: us-central1)
        skip_terraform: Skip Terraform initialization
        force: Force re-initialization
    """
    console.print(Panel.fit(
        "[bold cyan]GCP Observability Demo - Initialization[/bold cyan]\n"
        "This wizard will guide you through setting up your GCP project"
    ))

    # Step 1: Check prerequisites
    console.print("\n[bold]Step 1: Checking Prerequisites[/bold]")
    checker = PrerequisiteChecker()
    if not checker.check_prerequisites():
        console.print("\n[red]✗ Prerequisites check failed[/red]")
        console.print("[yellow]Please install the required tools and try again[/yellow]")
        sys.exit(1)

    # Step 2: Check GCP authentication
    console.print("\n[bold]Step 2: Verifying GCP Authentication[/bold]")
    auth_checker = GCPAuthChecker()

    if not auth_checker.check_gcloud_auth():
        console.print("[yellow]⚠ Not authenticated with gcloud[/yellow]")
        if not auth_checker.prompt_authentication():
            console.print("\n[red]✗ Authentication failed[/red]")
            sys.exit(1)

    if not auth_checker.check_application_default_credentials():
        console.print("[yellow]⚠ Application default credentials not configured[/yellow]")
        if Confirm.ask("Configure application default credentials now?"):
            if not auth_checker.prompt_authentication():
                console.print("\n[red]✗ Authentication failed[/red]")
                sys.exit(1)

    console.print("[green]✓[/green] GCP authentication verified")

    # Step 3: Validate project
    console.print("\n[bold]Step 3: Validating GCP Project[/bold]")
    validator = GCPProjectValidator()

    if not project_id:
        # List available projects
        projects = validator.list_projects()
        if projects:
            console.print("\n[cyan]Available projects:[/cyan]")
            for i, proj in enumerate(projects[:10], 1):
                console.print(f"  {i}. {proj}")
            if len(projects) > 10:
                console.print(f"  ... and {len(projects) - 10} more")

        project_id = Prompt.ask("\nEnter GCP project ID")

    if not validator.project_exists(project_id):
        console.print(f"[red]✗ Project '{project_id}' not found or not accessible[/red]")

        if Confirm.ask("Would you like to create this project?"):
            console.print("[yellow]Note: Project creation requires organization-level permissions[/yellow]")
            console.print("[yellow]You may need to create the project manually in the GCP Console[/yellow]")
            console.print(f"[yellow]https://console.cloud.google.com/projectcreate[/yellow]")

        sys.exit(1)

    console.print(f"[green]✓[/green] Project '{project_id}' found")

    # Set as current project
    validator.set_project(project_id)

    # Step 4: Validate billing
    console.print("\n[bold]Step 4: Validating Billing Account[/bold]")

    current_billing = validator.get_billing_account(project_id)
    if current_billing:
        console.print(f"[green]✓[/green] Project is linked to billing account: [cyan]{current_billing}[/cyan]")
        if not billing_account:
            billing_account = current_billing
    else:
        console.print("[yellow]⚠ No billing account linked to project[/yellow]")

        billing_accounts = validator.list_billing_accounts()
        if billing_accounts:
            console.print("\n[cyan]Available billing accounts:[/cyan]")
            for i, account in enumerate(billing_accounts, 1):
                console.print(f"  {i}. {account}")

        if not billing_account:
            billing_account = Prompt.ask("\nEnter billing account ID (format: XXXXXX-XXXXXX-XXXXXX)")

    # Step 5: Initialize Terraform
    if not skip_terraform:
        console.print("\n[bold]Step 5: Initializing Terraform[/bold]")

        # Determine Terraform directory
        terraform_dir = Path(__file__).parent.parent.parent.parent / "terraform"
        if not terraform_dir.exists():
            console.print(f"[red]✗ Terraform directory not found: {terraform_dir}[/red]")
            sys.exit(1)

        # Change to Terraform directory
        os.chdir(terraform_dir)

        initializer = TerraformInitializer(terraform_dir)

        if not initializer.init_terraform(reconfigure=force):
            console.print("\n[red]✗ Terraform initialization failed[/red]")
            sys.exit(1)

        if not initializer.validate_terraform():
            console.print("\n[red]✗ Terraform validation failed[/red]")
            sys.exit(1)

    # Step 6: Create configuration file
    console.print("\n[bold]Step 6: Creating Configuration[/bold]")

    config_path = Path.home() / ".observ-demo" / "config.yaml"
    config_path.parent.mkdir(parents=True, exist_ok=True)

    config_content = f"""# Observability Demo Configuration
# Generated by: observ-demo init

gcp:
  project_id: "{project_id}"
  billing_account: "{billing_account}"
  region: "{region}"

cluster:
  name: "{project_id}-gke"
  regional: true
  enable_autopilot: true

monitoring:
  enable_alerts: true
  notification_email: ""  # Add your email for notifications

deployment:
  deploy_otel: true
  deploy_microservices: true

terraform:
  state_bucket: "{project_id}-terraform-state"
"""

    if not config_path.exists() or force or Confirm.ask(f"\nConfiguration file exists. Overwrite?"):
        config_path.write_text(config_content)
        console.print(f"[green]✓[/green] Configuration saved to: [cyan]{config_path}[/cyan]")
    else:
        console.print(f"[yellow]⚠[/yellow] Using existing configuration: [cyan]{config_path}[/cyan]")

    # Success summary
    console.print("\n" + "="*60)
    console.print(Panel.fit(
        "[bold green]✓ Initialization Complete[/bold green]\n\n"
        f"Project ID: [cyan]{project_id}[/cyan]\n"
        f"Billing Account: [cyan]{billing_account}[/cyan]\n"
        f"Region: [cyan]{region}[/cyan]\n"
        f"Config: [cyan]{config_path}[/cyan]\n\n"
        "[bold]Next Steps:[/bold]\n"
        "1. Review and edit configuration: [cyan]nano ~/.observ-demo/config.yaml[/cyan]\n"
        "2. Configure Terraform variables: [cyan]cp terraform/terraform.tfvars.example terraform/terraform.tfvars[/cyan]\n"
        "3. Deploy infrastructure: [cyan]observ-demo deploy[/cyan]\n"
    ))

    return 0
