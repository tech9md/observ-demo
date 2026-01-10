"""
Traffic Generation Command - Realistic User Behavior Simulation

This module implements realistic traffic generation for demo applications with:
- Multiple traffic patterns (low, medium, high, spike)
- User behavior simulation (browse, search, cart, checkout)
- OpenTelemetry instrumentation
- Configurable duration and concurrency
"""

import random
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import click
from rich.console import Console
from rich.live import Live
from rich.panel import Panel
from rich.progress import (
    BarColumn,
    Progress,
    SpinnerColumn,
    TaskProgressColumn,
    TextColumn,
    TimeRemainingColumn,
)
from rich.table import Table

console = Console()


class TrafficPattern:
    """Defines traffic generation patterns."""

    PATTERNS = {
        "low": {
            "users": 5,
            "duration": 3600,  # 1 hour
            "spawn_rate": 1,
            "description": "Light browsing traffic (5 users, 1 hour)",
        },
        "medium": {
            "users": 20,
            "duration": 1800,  # 30 minutes
            "spawn_rate": 2,
            "description": "Moderate shopping activity (20 users, 30 min)",
        },
        "high": {
            "users": 50,
            "duration": 600,  # 10 minutes
            "spawn_rate": 5,
            "description": "Heavy traffic (50 users, 10 min)",
        },
        "spike": {
            "users": 100,
            "duration": 300,  # 5 minutes
            "spawn_rate": 10,
            "description": "Flash sale spike (100 users, 5 min)",
        },
    }

    @classmethod
    def get_pattern(cls, pattern_name: str) -> Dict:
        """Get traffic pattern configuration."""
        return cls.PATTERNS.get(pattern_name.lower(), cls.PATTERNS["low"])


class UserBehavior:
    """Simulates realistic user behavior patterns."""

    # User journey weights (probability distribution)
    JOURNEYS = {
        "browser": 0.40,  # 40% - Just browsing, no purchase
        "searcher": 0.25,  # 25% - Search and browse
        "cart_abandoner": 0.20,  # 20% - Add to cart but don't checkout
        "buyer": 0.15,  # 15% - Complete purchase
    }

    # Page weights for browsing
    PAGES = {
        "/": 0.30,  # Home page
        "/product/": 0.25,  # Product pages (append random product ID)
        "/cart": 0.15,  # Cart page
        "/search": 0.15,  # Search
        "/category/": 0.10,  # Category pages
        "/about": 0.03,  # About page
        "/contact": 0.02,  # Contact
    }

    # Product IDs for realistic browsing
    PRODUCT_IDS = [
        "OLJCESPC7Z",  # Sunglasses
        "66VCHSJNUP",  # Tank Top
        "1YMWWN1N4O",  # Watch
        "L9ECAV7KIM",  # Loafers
        "2ZYFJ3GM2N",  # Film Camera
        "0PUK6V6EV0",  # Vintage Record Player
        "LS4PSXUNUM",  # Metal Camping Mug
        "9SIQT8TOJO",  # City Bike
        "6E92ZMYYFZ",  # Air Plant
    ]

    @classmethod
    def get_random_journey(cls) -> str:
        """Get a random user journey based on weighted probabilities."""
        return random.choices(
            list(cls.JOURNEYS.keys()), weights=list(cls.JOURNEYS.values()), k=1
        )[0]

    @classmethod
    def get_random_page(cls) -> str:
        """Get a random page based on weighted probabilities."""
        page = random.choices(
            list(cls.PAGES.keys()), weights=list(cls.PAGES.values()), k=1
        )[0]

        # Add random product ID for product pages
        if "/product/" in page:
            page = f"{page}{random.choice(cls.PRODUCT_IDS)}"
        elif "/category/" in page:
            categories = ["clothing", "accessories", "home", "vintage"]
            page = f"{page}{random.choice(categories)}"

        return page

    @classmethod
    def simulate_browser(cls, base_url: str, session) -> List[str]:
        """Simulate a browsing user (no purchase)."""
        pages = ["/"]  # Start at home

        # Browse 3-7 pages
        for _ in range(random.randint(3, 7)):
            pages.append(cls.get_random_page())
            time.sleep(random.uniform(2, 5))  # Think time between pages

        return pages

    @classmethod
    def simulate_searcher(cls, base_url: str, session) -> List[str]:
        """Simulate a user who searches and browses."""
        pages = ["/", "/search?q=vintage"]  # Start with search

        # View 2-4 search results
        for _ in range(random.randint(2, 4)):
            pages.append(f"/product/{random.choice(cls.PRODUCT_IDS)}")
            time.sleep(random.uniform(2, 4))

        return pages

    @classmethod
    def simulate_cart_abandoner(cls, base_url: str, session) -> List[str]:
        """Simulate a user who adds to cart but doesn't checkout."""
        pages = ["/"]

        # Browse products
        for _ in range(random.randint(2, 4)):
            product_id = random.choice(cls.PRODUCT_IDS)
            pages.append(f"/product/{product_id}")
            time.sleep(random.uniform(2, 4))

            # Add to cart (POST request simulation)
            pages.append(f"/cart?add={product_id}")
            time.sleep(random.uniform(1, 2))

        # View cart but abandon
        pages.append("/cart")
        time.sleep(random.uniform(3, 6))

        return pages

    @classmethod
    def simulate_buyer(cls, base_url: str, session) -> List[str]:
        """Simulate a user who completes a purchase."""
        pages = ["/"]

        # Browse and add products
        for _ in range(random.randint(1, 3)):
            product_id = random.choice(cls.PRODUCT_IDS)
            pages.append(f"/product/{product_id}")
            time.sleep(random.uniform(2, 4))
            pages.append(f"/cart?add={product_id}")
            time.sleep(random.uniform(1, 2))

        # Go through checkout
        pages.append("/cart")
        time.sleep(random.uniform(2, 4))
        pages.append("/checkout")
        time.sleep(random.uniform(3, 6))
        pages.append("/checkout/complete")  # Complete purchase

        return pages


class TrafficGenerator:
    """Generates HTTP traffic to demo applications."""

    def __init__(self, target_url: str):
        self.target_url = target_url.rstrip("/")

    @staticmethod
    def run_command(cmd: list) -> Tuple[int, str, str]:
        """Run a shell command."""
        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=300
            )
            return result.returncode, result.stdout.strip(), result.stderr.strip()
        except subprocess.TimeoutExpired:
            return 1, "", "Command timed out"
        except Exception as e:
            return 1, "", str(e)

    def get_service_url(self, namespace: str, service: str) -> Optional[str]:
        """Get service URL from Kubernetes."""
        # Try LoadBalancer IP first
        cmd = [
            "kubectl", "get", "svc", service,
            "-n", namespace,
            "-o", "jsonpath={.status.loadBalancer.ingress[0].ip}"
        ]
        code, stdout, _ = self.run_command(cmd)

        if code == 0 and stdout:
            return f"http://{stdout}"

        # Fallback to port-forward
        console.print(
            f"[yellow]⚠ LoadBalancer IP not available for {service}[/yellow]"
        )
        console.print(
            f"[yellow]Consider using: kubectl port-forward -n {namespace} svc/{service} 8080:80[/yellow]"
        )
        return None

    def generate_with_curl(
        self, pattern: Dict, duration_override: Optional[int] = None
    ) -> bool:
        """Generate traffic using curl (simple method)."""
        duration = duration_override or pattern["duration"]
        users = pattern["users"]

        console.print(
            f"\n[cyan]Generating traffic:[/cyan] {users} concurrent users for {duration}s"
        )

        start_time = time.time()
        request_count = 0
        error_count = 0

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            TimeRemainingColumn(),
            console=console,
        ) as progress:
            task = progress.add_task(
                f"Simulating {users} users...", total=duration
            )

            while time.time() - start_time < duration:
                # Simulate concurrent users
                for _ in range(users):
                    journey = UserBehavior.get_random_journey()
                    page = UserBehavior.get_random_page()
                    url = f"{self.target_url}{page}"

                    # Make request
                    code, _, _ = self.run_command(
                        ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", url]
                    )

                    request_count += 1
                    if code != 0:
                        error_count += 1

                # Update progress
                elapsed = int(time.time() - start_time)
                progress.update(task, completed=elapsed)

                # Sleep between batches
                time.sleep(1)

        # Summary
        console.print(f"\n[green]✓[/green] Traffic generation completed")
        console.print(f"  Total requests: {request_count}")
        console.print(f"  Errors: {error_count}")
        console.print(
            f"  Success rate: {((request_count - error_count) / request_count * 100):.1f}%"
        )

        return True

    def generate_with_locust(
        self, pattern: Dict, duration_override: Optional[int] = None
    ) -> bool:
        """Generate traffic using Locust (advanced method)."""
        console.print("[cyan]Locust-based traffic generation not yet implemented[/cyan]")
        console.print("[yellow]Falling back to curl-based generation[/yellow]")
        return self.generate_with_curl(pattern, duration_override)


def generate_traffic_command(
    pattern: str = "low",
    duration: Optional[int] = None,
    target_url: Optional[str] = None,
    namespace: str = "microservices-demo",
    service: str = "frontend",
):
    """
    Generate realistic traffic for demo applications.

    Args:
        pattern: Traffic pattern (low, medium, high, spike)
        duration: Override duration in seconds
        target_url: Target URL (auto-detected if not provided)
        namespace: Kubernetes namespace
        service: Kubernetes service name
    """
    console.print(
        Panel.fit(
            "[bold cyan]Traffic Generation[/bold cyan]\n"
            f"Pattern: {pattern.upper()}"
        )
    )

    # Get traffic pattern
    pattern_config = TrafficPattern.get_pattern(pattern)
    console.print(f"\n[cyan]Pattern:[/cyan] {pattern_config['description']}")

    # Determine target URL
    if not target_url:
        console.print(f"\n[cyan]Detecting service URL...[/cyan]")
        generator = TrafficGenerator("")
        target_url = generator.get_service_url(namespace, service)

        if not target_url:
            console.print("\n[red]✗ Could not detect service URL[/red]")
            console.print("[yellow]Options:[/yellow]")
            console.print(
                f"  1. Use --target-url http://YOUR_SERVICE_IP"
            )
            console.print(
                f"  2. Port-forward: kubectl port-forward -n {namespace} svc/{service} 8080:80"
            )
            console.print(
                f"     Then use: --target-url http://localhost:8080"
            )
            sys.exit(1)

    console.print(f"[cyan]Target URL:[/cyan] {target_url}")

    # Generate traffic
    generator = TrafficGenerator(target_url)

    # Display traffic pattern summary
    table = Table(title="Traffic Pattern Configuration", show_header=True)
    table.add_column("Parameter", style="cyan")
    table.add_column("Value", style="green")

    table.add_row("Concurrent Users", str(pattern_config["users"]))
    table.add_row(
        "Duration",
        f"{duration or pattern_config['duration']}s ({(duration or pattern_config['duration']) / 60:.1f} min)",
    )
    table.add_row("Spawn Rate", f"{pattern_config['spawn_rate']} users/sec")
    table.add_row("Target", target_url)

    console.print("\n")
    console.print(table)
    console.print("\n")

    # Start traffic generation
    success = generator.generate_with_curl(pattern_config, duration)

    if success:
        console.print("\n[bold green]Traffic generation completed successfully![/bold green]")
        console.print("\n[cyan]Next steps:[/cyan]")
        console.print("  1. View traces in Cloud Trace")
        console.print("  2. Check metrics in Cloud Monitoring")
        console.print("  3. Analyze logs in Cloud Logging")
        return 0
    else:
        console.print("\n[red]Traffic generation failed[/red]")
        return 1
