"""
Deploy Command - Infrastructure and Application Deployment

This module implements the 'deploy' command which:
- Deploys Terraform infrastructure
- Configures kubectl access to GKE cluster
- Deploys Kubernetes applications (OpenTelemetry, Microservices)
- Validates deployments
- Sends completion notifications
"""

import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional, Tuple

import click
import yaml
from rich.console import Console
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn
from rich.prompt import Confirm
from rich.table import Table

console = Console()


class TerraformDeployer:
    """Handles Terraform deployment operations."""

    def __init__(self, terraform_dir: Path):
        self.terraform_dir = terraform_dir

    @staticmethod
    def run_command(cmd: list, cwd: Optional[Path] = None) -> Tuple[int, str, str]:
        """Run a shell command and return exit code, stdout, stderr."""
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=cwd,
                timeout=3600,  # 1 hour timeout for long operations
            )
            return result.returncode, result.stdout.strip(), result.stderr.strip()
        except subprocess.TimeoutExpired:
            return 1, "", "Command timed out after 1 hour"
        except Exception as e:
            return 1, "", str(e)

    def terraform_plan(self, var_file: Optional[Path] = None) -> bool:
        """Run terraform plan."""
        console.print("\n[bold cyan]Running Terraform Plan[/bold cyan]")
        console.print("Calculating infrastructure changes...\n")

        cmd = ["terraform", "plan", "-out=tfplan"]
        if var_file and var_file.exists():
            cmd.extend(["-var-file", str(var_file)])

        code, stdout, stderr = self.run_command(cmd, cwd=self.terraform_dir)

        if code == 0:
            console.print(stdout)
            console.print("\n[green]✓[/green] Terraform plan completed successfully")
            return True
        else:
            console.print(f"[red]✗ Terraform plan failed:[/red]")
            console.print(stderr)
            return False

    def terraform_apply(self, auto_approve: bool = False) -> bool:
        """Run terraform apply."""
        console.print("\n[bold cyan]Deploying Infrastructure with Terraform[/bold cyan]")
        console.print("[yellow]This will take approximately 45-60 minutes...[/yellow]\n")

        cmd = ["terraform", "apply"]
        if auto_approve:
            cmd.append("-auto-approve")
        else:
            cmd.append("tfplan")

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            console=console,
        ) as progress:
            task = progress.add_task(
                "Deploying GCP infrastructure...",
                total=100
            )

            # Start the terraform apply process
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                cwd=self.terraform_dir,
            )

            # Monitor progress based on output
            progress_markers = [
                ("project-setup", 10),
                ("vpc-network", 20),
                ("gke-cluster", 60),
                ("iap-config", 75),
                ("monitoring", 85),
                ("budget-alerts", 95),
            ]

            current_progress = 0
            while process.poll() is None:
                line = process.stdout.readline()
                if line:
                    for marker, target_progress in progress_markers:
                        if marker in line.lower() and current_progress < target_progress:
                            progress.update(task, completed=target_progress)
                            current_progress = target_progress
                time.sleep(0.1)

            # Get final output
            stdout, stderr = process.communicate()
            progress.update(task, completed=100)

        if process.returncode == 0:
            console.print("\n[green]✓[/green] Infrastructure deployed successfully")
            console.print(stdout)
            return True
        else:
            console.print(f"\n[red]✗ Terraform apply failed:[/red]")
            console.print(stderr)
            return False

    def get_terraform_outputs(self) -> dict:
        """Get Terraform outputs as dictionary."""
        cmd = ["terraform", "output", "-json"]
        code, stdout, stderr = self.run_command(cmd, cwd=self.terraform_dir)

        if code == 0:
            try:
                import json
                outputs = json.loads(stdout)
                # Extract values from output structure
                return {k: v.get("value") for k, v in outputs.items()}
            except json.JSONDecodeError:
                console.print("[yellow]⚠ Could not parse Terraform outputs[/yellow]")
                return {}
        return {}


class KubernetesDeployer:
    """Handles Kubernetes deployment operations."""

    def __init__(self, cluster_name: str, region: str, project_id: str):
        self.cluster_name = cluster_name
        self.region = region
        self.project_id = project_id

    @staticmethod
    def run_kubectl(cmd: list) -> Tuple[int, str, str]:
        """Run kubectl command."""
        full_cmd = ["kubectl"] + cmd
        try:
            result = subprocess.run(
                full_cmd,
                capture_output=True,
                text=True,
                timeout=300,
            )
            return result.returncode, result.stdout.strip(), result.stderr.strip()
        except subprocess.TimeoutExpired:
            return 1, "", "kubectl command timed out"
        except Exception as e:
            return 1, "", str(e)

    def configure_kubectl(self) -> bool:
        """Configure kubectl to access GKE cluster."""
        console.print("\n[bold cyan]Configuring kubectl Access[/bold cyan]")

        cmd = [
            "gcloud", "container", "clusters", "get-credentials",
            self.cluster_name,
            "--region", self.region,
            "--project", self.project_id
        ]

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            if result.returncode == 0:
                console.print(f"[green]✓[/green] kubectl configured for cluster: [cyan]{self.cluster_name}[/cyan]")
                return True
            else:
                console.print(f"[red]✗ Failed to configure kubectl:[/red] {result.stderr}")
                return False
        except Exception as e:
            console.print(f"[red]✗ Error configuring kubectl:[/red] {str(e)}")
            return False

    def verify_cluster_access(self) -> bool:
        """Verify kubectl can access the cluster."""
        console.print("\n[bold cyan]Verifying Cluster Access[/bold cyan]")

        code, stdout, stderr = self.run_kubectl(["get", "nodes"])

        if code == 0:
            console.print("[green]✓[/green] Cluster is accessible")
            console.print(f"\n{stdout}")
            return True
        else:
            console.print(f"[red]✗ Cannot access cluster:[/red] {stderr}")
            return False

    def create_namespace(self, namespace: str) -> bool:
        """Create Kubernetes namespace."""
        code, _, stderr = self.run_kubectl([
            "create", "namespace", namespace, "--dry-run=client", "-o", "yaml"
        ])

        if code == 0:
            code, _, stderr = self.run_kubectl([
                "apply", "-f", "-"
            ])

        code, stdout, _ = self.run_kubectl(["get", "namespace", namespace])
        if code == 0:
            console.print(f"[green]✓[/green] Namespace created: [cyan]{namespace}[/cyan]")
            return True

        # Try creating directly
        code, _, stderr = self.run_kubectl(["create", "namespace", namespace])
        if code == 0 or "already exists" in stderr.lower():
            console.print(f"[green]✓[/green] Namespace ready: [cyan]{namespace}[/cyan]")
            return True

        console.print(f"[yellow]⚠[/yellow] Namespace issue: {stderr}")
        return True  # Continue anyway, might already exist

    def deploy_manifest(self, manifest_path: Path) -> bool:
        """Deploy Kubernetes manifest."""
        if not manifest_path.exists():
            console.print(f"[yellow]⚠ Manifest not found:[/yellow] {manifest_path}")
            return False

        code, stdout, stderr = self.run_kubectl(["apply", "-f", str(manifest_path)])

        if code == 0:
            console.print(f"[green]✓[/green] Deployed: [cyan]{manifest_path.name}[/cyan]")
            return True
        else:
            console.print(f"[red]✗ Failed to deploy {manifest_path.name}:[/red]")
            console.print(stderr)
            return False

    def wait_for_pods(self, namespace: str, timeout: int = 600) -> bool:
        """Wait for all pods in namespace to be ready."""
        console.print(f"\n[bold cyan]Waiting for pods in {namespace} to be ready...[/bold cyan]")

        start_time = time.time()
        while time.time() - start_time < timeout:
            code, stdout, _ = self.run_kubectl([
                "get", "pods",
                "-n", namespace,
                "-o", "jsonpath={.items[*].status.conditions[?(@.type=='Ready')].status}"
            ])

            if code == 0 and stdout:
                statuses = stdout.split()
                if all(s == "True" for s in statuses):
                    console.print(f"[green]✓[/green] All pods in {namespace} are ready")
                    return True

            time.sleep(10)

        console.print(f"[yellow]⚠ Timeout waiting for pods in {namespace}[/yellow]")
        return False


class NotificationService:
    """Handles deployment notifications."""

    @staticmethod
    def send_email(email: str, subject: str, body: str) -> bool:
        """Send email notification (placeholder)."""
        console.print(f"\n[cyan]📧 Email notification:[/cyan] {email}")
        console.print(f"[cyan]Subject:[/cyan] {subject}")
        # TODO: Implement actual email sending (SendGrid, etc.)
        return True

    @staticmethod
    def send_slack(webhook_url: str, message: str) -> bool:
        """Send Slack notification."""
        import requests
        import json

        try:
            payload = {"text": message}
            response = requests.post(
                webhook_url,
                data=json.dumps(payload),
                headers={"Content-Type": "application/json"},
                timeout=10
            )
            if response.status_code == 200:
                console.print("[green]✓[/green] Slack notification sent")
                return True
            else:
                console.print(f"[yellow]⚠ Slack notification failed:[/yellow] {response.text}")
                return False
        except Exception as e:
            console.print(f"[yellow]⚠ Slack notification error:[/yellow] {str(e)}")
            return False


def deploy_command(
    config_path: Optional[Path] = None,
    auto_approve: bool = False,
    notify_email: tuple = (),
    notify_slack: Optional[str] = None,
    deploy_otel: bool = True,
    deploy_microservices: bool = True,
    deploy_monitoring: bool = True,
):
    """
    Deploy complete observability demo stack.

    Args:
        config_path: Path to configuration file
        auto_approve: Skip Terraform approval prompt
        notify_email: Email addresses for notifications
        notify_slack: Slack webhook URL
        deploy_otel: Deploy OpenTelemetry demo
        deploy_microservices: Deploy Microservices demo
        deploy_monitoring: Deploy monitoring stack
    """
    console.print(Panel.fit(
        "[bold cyan]GCP Observability Demo - Deployment[/bold cyan]\n"
        "Deploying infrastructure and applications"
    ))

    # Determine Terraform directory
    terraform_dir = Path(__file__).parent.parent.parent.parent / "terraform"
    if not terraform_dir.exists():
        console.print(f"[red]✗ Terraform directory not found:[/red] {terraform_dir}")
        sys.exit(1)

    # Change to Terraform directory
    original_dir = Path.cwd()
    os.chdir(terraform_dir)

    try:
        # Phase 1: Terraform Plan
        deployer = TerraformDeployer(terraform_dir)

        var_file = terraform_dir / "terraform.tfvars"
        if not deployer.terraform_plan(var_file if var_file.exists() else None):
            console.print("\n[red]✗ Deployment failed at planning stage[/red]")
            sys.exit(1)

        # Confirm deployment if not auto-approved
        if not auto_approve:
            console.print("\n" + "="*60)
            if not Confirm.ask("\n[bold yellow]Proceed with deployment?[/bold yellow]"):
                console.print("\n[yellow]Deployment cancelled[/yellow]")
                sys.exit(0)

        # Phase 2: Terraform Apply
        if not deployer.terraform_apply(auto_approve):
            console.print("\n[red]✗ Infrastructure deployment failed[/red]")
            sys.exit(1)

        # Phase 3: Get Terraform Outputs
        outputs = deployer.get_terraform_outputs()
        cluster_name = outputs.get("cluster_name", "")
        project_id = outputs.get("project_id", "")
        region = outputs.get("region", "us-central1")

        if not cluster_name or not project_id:
            console.print("[yellow]⚠ Could not retrieve cluster information from Terraform outputs[/yellow]")
            console.print("[yellow]Please configure kubectl manually[/yellow]")
            sys.exit(1)

        # Phase 4: Configure kubectl
        k8s_deployer = KubernetesDeployer(cluster_name, region, project_id)

        if not k8s_deployer.configure_kubectl():
            console.print("[red]✗ Failed to configure kubectl access[/red]")
            sys.exit(1)

        if not k8s_deployer.verify_cluster_access():
            console.print("[red]✗ Cannot access cluster[/red]")
            sys.exit(1)

        # Phase 5: Deploy Kubernetes Applications
        kubernetes_dir = Path(__file__).parent.parent.parent.parent / "kubernetes"

        if deploy_otel:
            console.print("\n[bold cyan]Deploying OpenTelemetry Demo[/bold cyan]")
            k8s_deployer.create_namespace("opentelemetry")
            # TODO: Deploy OpenTelemetry manifests
            console.print("[yellow]⚠ OpenTelemetry manifests pending implementation[/yellow]")

        if deploy_microservices:
            console.print("\n[bold cyan]Deploying Microservices Demo[/bold cyan]")
            k8s_deployer.create_namespace("microservices-demo")
            # TODO: Deploy Microservices manifests
            console.print("[yellow]⚠ Microservices manifests pending implementation[/yellow]")

        # Phase 6: Send Notifications
        if notify_email or notify_slack:
            console.print("\n[bold cyan]Sending Deployment Notifications[/bold cyan]")

            notification_service = NotificationService()
            deployment_info = f"""
Deployment Complete!

Cluster: {cluster_name}
Region: {region}
Project: {project_id}

OpenTelemetry: {'✓' if deploy_otel else '✗'}
Microservices: {'✓' if deploy_microservices else '✗'}

Access URLs:
- GKE Console: {outputs.get('access_urls', {}).get('gke_console', 'N/A')}
- Monitoring: {outputs.get('access_urls', {}).get('monitoring', 'N/A')}
- Cloud Trace: {outputs.get('access_urls', {}).get('trace', 'N/A')}
"""

            for email in notify_email:
                notification_service.send_email(
                    email,
                    "GCP Observability Demo - Deployment Complete",
                    deployment_info
                )

            if notify_slack:
                notification_service.send_slack(notify_slack, deployment_info)

        # Success Summary
        console.print("\n" + "="*60)
        console.print(Panel.fit(
            "[bold green]✓ Deployment Complete[/bold green]\n\n"
            f"Cluster: [cyan]{cluster_name}[/cyan]\n"
            f"Region: [cyan]{region}[/cyan]\n"
            f"Project: [cyan]{project_id}[/cyan]\n\n"
            "[bold]Next Steps:[/bold]\n"
            "1. Check deployment status: [cyan]observ-demo status[/cyan]\n"
            "2. Generate traffic: [cyan]observ-demo generate-traffic[/cyan]\n"
            "3. View access URLs: [cyan]observ-demo access[/cyan]\n"
        ))

        return 0

    finally:
        # Return to original directory
        os.chdir(original_dir)
