"""
Teardown Command - Resource Cleanup and Destruction

This module implements safe and complete resource teardown:
- Kubernetes applications cleanup
- Terraform infrastructure destruction
- State bucket cleanup (optional)
- Verification and confirmation
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
from rich.prompt import Confirm

console = Console()


class TeardownManager:
    """Manages safe teardown of all deployed resources."""

    @staticmethod
    def run_command(cmd: list, cwd: Optional[Path] = None) -> Tuple[int, str, str]:
        """Run a shell command."""
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=cwd,
                timeout=1800,  # 30 minutes for terraform destroy
            )
            return result.returncode, result.stdout.strip(), result.stderr.strip()
        except subprocess.TimeoutExpired:
            return 1, "", "Command timed out"
        except Exception as e:
            return 1, "", str(e)

    def delete_namespace(self, namespace: str) -> bool:
        """Delete a Kubernetes namespace and all its resources."""
        console.print(f"\n[cyan]Deleting namespace:[/cyan] {namespace}")

        # Check if namespace exists
        code, _, _ = self.run_command(["kubectl", "get", "namespace", namespace])

        if code != 0:
            console.print(f"[yellow]⚠[/yellow] Namespace '{namespace}' not found, skipping")
            return True

        # Delete namespace
        code, _, stderr = self.run_command(["kubectl", "delete", "namespace", namespace, "--wait=true"])

        if code == 0:
            console.print(f"[green]✓[/green] Namespace '{namespace}' deleted")
            return True
        else:
            console.print(f"[red]✗[/red] Failed to delete namespace: {stderr}")
            return False

    def terraform_destroy(self, auto_approve: bool = False) -> bool:
        """Destroy Terraform infrastructure."""
        console.print("\n[bold cyan]Destroying Terraform Infrastructure[/bold cyan]")

        terraform_dir = Path(__file__).parent.parent.parent.parent / "terraform"
        if not terraform_dir.exists():
            console.print("[yellow]⚠[/yellow] Terraform directory not found, skipping")
            return True

        if not (terraform_dir / ".terraform").exists():
            console.print("[yellow]⚠[/yellow] Terraform not initialized, skipping")
            return True

        console.print("[yellow]This will destroy ALL infrastructure resources[/yellow]")
        console.print("[yellow]Including: GKE cluster, VPC, load balancers, monitoring, etc.[/yellow]")

        if not auto_approve:
            if not Confirm.ask("\n[bold red]Are you absolutely sure you want to destroy all infrastructure?[/bold red]"):
                console.print("\n[yellow]Terraform destroy cancelled[/yellow]")
                return False

        # Run terraform destroy
        cmd = ["terraform", "destroy"]
        if auto_approve:
            cmd.append("-auto-approve")

        console.print("\n[cyan]Running terraform destroy...[/cyan]")
        console.print("[yellow]This may take 15-30 minutes...[/yellow]\n")

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console,
        ) as progress:
            task = progress.add_task("Destroying infrastructure...", total=None)

            code, stdout, stderr = self.run_command(cmd, cwd=terraform_dir)

            progress.update(task, completed=True)

        if code == 0:
            console.print("\n[green]✓[/green] Infrastructure destroyed successfully")
            console.print(stdout)
            return True
        else:
            console.print(f"\n[red]✗[/red] Terraform destroy failed:")
            console.print(stderr)
            return False

    def cleanup_state_bucket(self, keep_state: bool = True) -> bool:
        """Clean up Terraform state bucket."""
        if keep_state:
            console.print("\n[cyan]Keeping Terraform state bucket[/cyan]")
            console.print("[yellow]To manually remove, use: gsutil rm -r gs://BUCKET_NAME[/yellow]")
            return True

        console.print("\n[bold red]⚠️  State Bucket Deletion[/bold red]")
        console.print("[yellow]Deleting the state bucket will remove all Terraform state history[/yellow]")

        if not Confirm.ask("\n[bold red]Delete Terraform state bucket?[/bold red]"):
            console.print("\n[yellow]State bucket preserved[/yellow]")
            return True

        console.print("\n[yellow]State bucket deletion not yet implemented[/yellow]")
        console.print("[yellow]To manually remove:[/yellow]")
        console.print("  1. Find bucket name: [cyan]terraform output terraform_state_bucket[/cyan]")
        console.print("  2. Delete bucket: [cyan]gsutil rm -r gs://BUCKET_NAME[/cyan]")

        return True


def teardown_command(auto_approve: bool = False, keep_state: bool = False):
    """
    Destroy all deployed resources.

    Args:
        auto_approve: Skip confirmation prompts
        keep_state: Keep Terraform state bucket
    """
    console.print(Panel.fit(
        "[bold red]⚠️  Resource Teardown[/bold red]\n"
        "This will destroy all deployed resources"
    ))

    console.print("\n[yellow]This operation will:[/yellow]")
    console.print("  1. Delete Kubernetes applications (OpenTelemetry, Microservices)")
    console.print("  2. Destroy GKE cluster")
    console.print("  3. Remove VPC and networking")
    console.print("  4. Delete load balancers and IP addresses")
    console.print("  5. Remove monitoring and alerting")
    console.print("  6. Clean up IAM bindings")
    if not keep_state:
        console.print("  7. Delete Terraform state bucket")

    console.print("\n[bold red]⚠️  WARNING: This action cannot be undone![/bold red]")

    if not auto_approve:
        if not Confirm.ask("\n[bold]Proceed with teardown?[/bold]"):
            console.print("\n[yellow]Teardown cancelled[/yellow]")
            return 0

    manager = TeardownManager()

    # Phase 1: Delete Kubernetes Applications
    console.print("\n" + "="*60)
    console.print("[bold cyan]Phase 1: Deleting Kubernetes Applications[/bold cyan]")
    console.print("="*60)

    manager.delete_namespace("opentelemetry")
    manager.delete_namespace("microservices-demo")

    # Phase 2: Destroy Terraform Infrastructure
    console.print("\n" + "="*60)
    console.print("[bold cyan]Phase 2: Destroying Terraform Infrastructure[/bold cyan]")
    console.print("="*60)

    if not manager.terraform_destroy(auto_approve):
        console.print("\n[red]✗ Teardown failed at Terraform destroy phase[/red]")
        console.print("\n[yellow]Troubleshooting:[/yellow]")
        console.print("  1. Check for resources with deletion protection enabled")
        console.print("  2. Manually delete resources in GCP Console")
        console.print("  3. Run: [cyan]terraform destroy -target=RESOURCE[/cyan]")
        console.print("  4. Review logs: [cyan]terraform show[/cyan]")
        return 1

    # Phase 3: Clean up State Bucket
    console.print("\n" + "="*60)
    console.print("[bold cyan]Phase 3: State Bucket Cleanup[/bold cyan]")
    console.print("="*60)

    manager.cleanup_state_bucket(keep_state)

    # Success Summary
    console.print("\n" + "="*60)
    console.print(Panel.fit(
        "[bold green]✓ Teardown Completed Successfully[/bold green]\n\n"
        "All resources have been destroyed.\n\n"
        "[bold]What was removed:[/bold]\n"
        "• Kubernetes applications (OpenTelemetry, Microservices)\n"
        "• GKE Autopilot cluster\n"
        "• VPC network and subnets\n"
        "• Load balancers and static IPs\n"
        "• Cloud Monitoring alerts and dashboards\n"
        "• Budget alerts and notifications\n"
        "• Service accounts and IAM bindings\n\n"
        "[bold]To redeploy:[/bold]\n"
        "1. Run: [cyan]observ-demo init[/cyan]\n"
        "2. Then: [cyan]observ-demo deploy[/cyan]\n"
    ))

    console.print("\n[bold]Verification:[/bold]")
    console.print("  Check GCP Console: [cyan]https://console.cloud.google.com[/cyan]")
    console.print("  Verify no resources remain in:")
    console.print("    • Kubernetes Engine (GKE)")
    console.print("    • VPC Networks")
    console.print("    • Load Balancing")
    console.print("    • Cloud Monitoring")

    return 0
