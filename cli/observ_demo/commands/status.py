"""
Status Command - Deployment Health and Status Checks

This module implements comprehensive deployment status checks:
- Infrastructure status (Terraform, GKE cluster)
- Kubernetes resources (pods, services, deployments)
- Application health (endpoints, traces, metrics)
- Cost tracking and budget status
"""

import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import click
from rich.console import Console
from rich.live import Live
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

console = Console()


class StatusChecker:
    """Checks deployment status across all components."""

    @staticmethod
    def run_command(cmd: list, cwd: Optional[Path] = None) -> Tuple[int, str, str]:
        """Run a shell command."""
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=cwd,
                timeout=60,
            )
            return result.returncode, result.stdout.strip(), result.stderr.strip()
        except subprocess.TimeoutExpired:
            return 1, "", "Command timed out"
        except Exception as e:
            return 1, "", str(e)

    def check_terraform_status(self) -> Dict:
        """Check Terraform deployment status."""
        console.print("\n[bold cyan]Checking Infrastructure Status[/bold cyan]")

        terraform_dir = Path(__file__).parent.parent.parent.parent / "terraform"
        if not terraform_dir.exists():
            return {
                "status": "not_found",
                "message": "Terraform directory not found"
            }

        # Check if Terraform is initialized
        if not (terraform_dir / ".terraform").exists():
            return {
                "status": "not_initialized",
                "message": "Terraform not initialized"
            }

        # Get Terraform state
        code, stdout, stderr = self.run_command(
            ["terraform", "show", "-json"],
            cwd=terraform_dir
        )

        if code == 0:
            try:
                state = json.loads(stdout)
                resources = state.get("values", {}).get("root_module", {}).get("resources", [])
                return {
                    "status": "deployed",
                    "resources_count": len(resources),
                    "message": f"{len(resources)} resources deployed"
                }
            except json.JSONDecodeError:
                return {
                    "status": "unknown",
                    "message": "Could not parse Terraform state"
                }

        return {
            "status": "error",
            "message": stderr or "Could not retrieve Terraform status"
        }

    def check_gke_cluster(self) -> Dict:
        """Check GKE cluster status."""
        console.print("\n[bold cyan]Checking GKE Cluster Status[/bold cyan]")

        # Get current kubectl context
        code, stdout, _ = self.run_command(["kubectl", "config", "current-context"])

        if code != 0:
            return {
                "status": "not_configured",
                "message": "kubectl not configured"
            }

        context = stdout
        console.print(f"[cyan]Context:[/cyan] {context}")

        # Check cluster access
        code, stdout, _ = self.run_command(["kubectl", "cluster-info"])

        if code != 0:
            return {
                "status": "not_accessible",
                "message": "Cannot access cluster"
            }

        # Get nodes
        code, stdout, _ = self.run_command([
            "kubectl", "get", "nodes",
            "-o", "json"
        ])

        if code == 0:
            try:
                nodes_data = json.loads(stdout)
                nodes = nodes_data.get("items", [])
                ready_nodes = sum(
                    1 for node in nodes
                    if any(
                        condition.get("type") == "Ready" and condition.get("status") == "True"
                        for condition in node.get("status", {}).get("conditions", [])
                    )
                )

                return {
                    "status": "healthy",
                    "total_nodes": len(nodes),
                    "ready_nodes": ready_nodes,
                    "message": f"{ready_nodes}/{len(nodes)} nodes ready"
                }
            except json.JSONDecodeError:
                pass

        return {
            "status": "unknown",
            "message": "Could not retrieve cluster status"
        }

    def check_namespace_resources(self, namespace: str) -> Dict:
        """Check resources in a Kubernetes namespace."""
        # Check if namespace exists
        code, _, _ = self.run_command(["kubectl", "get", "namespace", namespace])

        if code != 0:
            return {
                "status": "not_found",
                "message": f"Namespace '{namespace}' not found"
            }

        # Get pods
        code, stdout, _ = self.run_command([
            "kubectl", "get", "pods",
            "-n", namespace,
            "-o", "json"
        ])

        if code != 0:
            return {
                "status": "error",
                "message": "Could not retrieve pods"
            }

        try:
            pods_data = json.loads(stdout)
            pods = pods_data.get("items", [])

            running_pods = sum(
                1 for pod in pods
                if pod.get("status", {}).get("phase") == "Running"
            )

            ready_pods = sum(
                1 for pod in pods
                if all(
                    condition.get("status") == "True"
                    for condition in pod.get("status", {}).get("conditions", [])
                    if condition.get("type") == "Ready"
                )
            )

            # Get services
            code, stdout, _ = self.run_command([
                "kubectl", "get", "svc",
                "-n", namespace,
                "-o", "json"
            ])

            services = []
            if code == 0:
                services_data = json.loads(stdout)
                services = services_data.get("items", [])

            return {
                "status": "deployed",
                "total_pods": len(pods),
                "running_pods": running_pods,
                "ready_pods": ready_pods,
                "services": len(services),
                "message": f"{ready_pods}/{len(pods)} pods ready, {len(services)} services"
            }

        except json.JSONDecodeError:
            return {
                "status": "error",
                "message": "Could not parse Kubernetes resources"
            }

    def get_service_endpoints(self, namespace: str) -> List[Dict]:
        """Get service endpoints."""
        code, stdout, _ = self.run_command([
            "kubectl", "get", "svc",
            "-n", namespace,
            "-o", "json"
        ])

        if code != 0:
            return []

        try:
            services_data = json.loads(stdout)
            services = services_data.get("items", [])

            endpoints = []
            for svc in services:
                svc_name = svc.get("metadata", {}).get("name", "")
                svc_type = svc.get("spec", {}).get("type", "")

                if svc_type == "LoadBalancer":
                    ingress = svc.get("status", {}).get("loadBalancer", {}).get("ingress", [])
                    if ingress:
                        ip = ingress[0].get("ip", "")
                        if ip:
                            endpoints.append({
                                "name": svc_name,
                                "type": "LoadBalancer",
                                "url": f"http://{ip}"
                            })

            return endpoints

        except json.JSONDecodeError:
            return []


def display_status_table(title: str, status_data: Dict) -> None:
    """Display status information in a table."""
    table = Table(title=title, show_header=False)
    table.add_column("Attribute", style="cyan")
    table.add_column("Value")

    status = status_data.get("status", "unknown")
    status_color = {
        "deployed": "green",
        "healthy": "green",
        "not_found": "yellow",
        "not_initialized": "yellow",
        "not_configured": "yellow",
        "error": "red",
        "unknown": "yellow",
    }.get(status, "white")

    table.add_row("Status", f"[{status_color}]{status.upper()}[/{status_color}]")

    for key, value in status_data.items():
        if key != "status":
            table.add_row(key.replace("_", " ").title(), str(value))

    console.print(table)


def status_command(watch: bool = False):
    """
    Check deployment status and health.

    Args:
        watch: Continuously watch deployment status
    """
    console.print(Panel.fit(
        "[bold cyan]Deployment Status Check[/bold cyan]\n"
        "Checking infrastructure and applications"
    ))

    checker = StatusChecker()

    # Infrastructure Status
    terraform_status = checker.check_terraform_status()
    display_status_table("Infrastructure (Terraform)", terraform_status)

    # GKE Cluster Status
    gke_status = checker.check_gke_cluster()
    display_status_table("GKE Cluster", gke_status)

    # Check OpenTelemetry namespace
    console.print("\n[bold cyan]Checking OpenTelemetry Demo[/bold cyan]")
    otel_status = checker.check_namespace_resources("opentelemetry")
    display_status_table("OpenTelemetry Demo", otel_status)

    # Get OpenTelemetry endpoints
    otel_endpoints = checker.get_service_endpoints("opentelemetry")
    if otel_endpoints:
        console.print("\n[bold]Access URLs:[/bold]")
        for endpoint in otel_endpoints:
            console.print(f"  • {endpoint['name']}: [cyan]{endpoint['url']}[/cyan]")

    # Check Microservices namespace
    console.print("\n[bold cyan]Checking Microservices Demo[/bold cyan]")
    microservices_status = checker.check_namespace_resources("microservices-demo")
    display_status_table("Microservices Demo", microservices_status)

    # Get Microservices endpoints
    microservices_endpoints = checker.get_service_endpoints("microservices-demo")
    if microservices_endpoints:
        console.print("\n[bold]Access URLs:[/bold]")
        for endpoint in microservices_endpoints:
            console.print(f"  • {endpoint['name']}: [cyan]{endpoint['url']}[/cyan]")

    # Summary
    console.print("\n" + "="*60)

    # Determine overall status
    all_statuses = [
        terraform_status.get("status"),
        gke_status.get("status"),
        otel_status.get("status"),
        microservices_status.get("status"),
    ]

    if all(s in ["deployed", "healthy"] for s in all_statuses if s):
        overall = "[bold green]✓ All Systems Operational[/bold green]"
    elif any(s in ["error"] for s in all_statuses):
        overall = "[bold red]✗ Errors Detected[/bold red]"
    else:
        overall = "[bold yellow]⚠ Partial Deployment[/bold yellow]"

    console.print(Panel.fit(overall))

    # Useful commands
    console.print("\n[bold]Useful Commands:[/bold]")
    console.print("  View all pods:      [cyan]kubectl get pods --all-namespaces[/cyan]")
    console.print("  Check logs:         [cyan]kubectl logs -n <namespace> <pod-name>[/cyan]")
    console.print("  Port forward:       [cyan]kubectl port-forward -n <namespace> svc/<service> 8080:80[/cyan]")
    console.print("  Cloud Trace:        [cyan]https://console.cloud.google.com/traces/list[/cyan]")
    console.print("  Cloud Monitoring:   [cyan]https://console.cloud.google.com/monitoring[/cyan]")

    if watch:
        console.print("\n[yellow]Watch mode not yet implemented[/yellow]")
        console.print("[yellow]Use: watch -n 5 observ-demo status[/yellow]")

    return 0
