"""
Configuration models and validation using Pydantic.

This module defines the configuration schema for the observability demo
automation platform with comprehensive validation.
"""

import re
from pathlib import Path
from typing import List, Optional

import yaml
from pydantic import BaseModel, Field, field_validator, model_validator


class GCPConfig(BaseModel):
    """GCP-specific configuration."""

    project_id: str = Field(
        ...,
        min_length=6,
        max_length=30,
        description="GCP Project ID"
    )
    billing_account: str = Field(
        ...,
        description="GCP Billing Account ID (format: 012345-6789AB-CDEF01)"
    )
    region: str = Field(
        default="us-central1",
        description="Primary GCP region"
    )
    zone: Optional[str] = Field(
        default=None,
        description="Primary GCP zone (auto-generated if not provided)"
    )
    org_id: Optional[str] = Field(
        default=None,
        description="GCP Organization ID (optional)"
    )

    @field_validator("project_id")
    @classmethod
    def validate_project_id(cls, v: str) -> str:
        """Validate GCP project ID format."""
        # Project IDs must start with a lowercase letter and can contain
        # lowercase letters, numbers, and hyphens
        if not re.match(r'^[a-z][-a-z0-9]{4,28}[a-z0-9]$', v):
            raise ValueError(
                "Project ID must start with a lowercase letter, "
                "contain only lowercase letters, numbers, and hyphens, "
                "and be 6-30 characters long"
            )
        return v

    @field_validator("billing_account")
    @classmethod
    def validate_billing_account(cls, v: str) -> str:
        """Validate GCP billing account format."""
        # Billing accounts are in the format: 012345-6789AB-CDEF01
        if not re.match(r'^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$', v):
            raise ValueError(
                "Billing account must be in format: 012345-6789AB-CDEF01 "
                "(three groups of 6 hexadecimal characters separated by hyphens)"
            )
        return v

    @field_validator("region")
    @classmethod
    def validate_region(cls, v: str) -> str:
        """Validate GCP region format."""
        # Valid regions are like: us-central1, europe-west1, asia-east1
        valid_regions = [
            "us-central1", "us-east1", "us-east4", "us-west1", "us-west2",
            "us-west3", "us-west4",
            "europe-west1", "europe-west2", "europe-west3", "europe-west4",
            "europe-west6", "europe-north1",
            "asia-east1", "asia-east2", "asia-northeast1", "asia-northeast2",
            "asia-northeast3", "asia-south1", "asia-southeast1", "asia-southeast2",
            "australia-southeast1", "southamerica-east1", "northamerica-northeast1",
        ]
        if v not in valid_regions:
            raise ValueError(
                f"Invalid region. Must be one of: {', '.join(valid_regions[:5])}... "
                f"(see GCP documentation for full list)"
            )
        return v

    @model_validator(mode="after")
    def set_zone_from_region(self) -> "GCPConfig":
        """Automatically set zone from region if not provided."""
        if self.zone is None:
            self.zone = f"{self.region}-a"
        return self


class ClusterConfig(BaseModel):
    """GKE cluster configuration."""

    name: str = Field(
        default="observ-demo-cluster",
        description="GKE cluster name"
    )
    mode: str = Field(
        default="autopilot",
        description="Cluster mode: autopilot or standard"
    )
    min_nodes: int = Field(
        default=1,
        ge=1,
        le=10,
        description="Minimum number of nodes (standard mode only)"
    )
    max_nodes: int = Field(
        default=3,
        ge=1,
        le=50,
        description="Maximum number of nodes (standard mode only)"
    )
    machine_type: str = Field(
        default="e2-small",
        description="Machine type for nodes (standard mode only)"
    )
    enable_private_nodes: bool = Field(
        default=True,
        description="Enable private nodes (no external IPs)"
    )
    enable_workload_identity: bool = Field(
        default=True,
        description="Enable Workload Identity for pod authentication"
    )
    enable_vertical_pod_autoscaling: bool = Field(
        default=True,
        description="Enable Vertical Pod Autoscaling"
    )

    @field_validator("mode")
    @classmethod
    def validate_mode(cls, v: str) -> str:
        """Validate cluster mode."""
        if v not in ["autopilot", "standard"]:
            raise ValueError("Cluster mode must be 'autopilot' or 'standard'")
        return v

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        """Validate cluster name format."""
        # Cluster names must start with a letter and contain only
        # lowercase letters, numbers, and hyphens
        if not re.match(r'^[a-z][a-z0-9-]{0,39}$', v):
            raise ValueError(
                "Cluster name must start with a lowercase letter, "
                "contain only lowercase letters, numbers, and hyphens, "
                "and be up to 40 characters long"
            )
        return v

    @model_validator(mode="after")
    def validate_node_config(self) -> "ClusterConfig":
        """Validate node configuration consistency."""
        if self.min_nodes > self.max_nodes:
            raise ValueError("min_nodes cannot be greater than max_nodes")

        # Autopilot mode ignores node configuration
        if self.mode == "autopilot":
            # Reset to defaults as they're not used
            self.min_nodes = 1
            self.max_nodes = 3

        return self


class MonitoringConfig(BaseModel):
    """Monitoring and alerting configuration."""

    email_notifications: List[str] = Field(
        default_factory=list,
        description="Email addresses for notifications"
    )
    slack_webhook: Optional[str] = Field(
        default=None,
        description="Slack webhook URL for notifications"
    )
    budget_amount: float = Field(
        default=100.0,
        ge=10.0,
        description="Monthly budget in USD"
    )
    budget_thresholds: List[float] = Field(
        default=[0.5, 0.75, 0.9, 1.0],
        description="Budget threshold percentages for alerts"
    )

    @field_validator("email_notifications")
    @classmethod
    def validate_emails(cls, v: List[str]) -> List[str]:
        """Validate email addresses."""
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        for email in v:
            if not re.match(email_pattern, email):
                raise ValueError(f"Invalid email address: {email}")
        return v

    @field_validator("slack_webhook")
    @classmethod
    def validate_slack_webhook(cls, v: Optional[str]) -> Optional[str]:
        """Validate Slack webhook URL."""
        if v is not None and not v.startswith("https://hooks.slack.com/"):
            raise ValueError("Slack webhook must start with 'https://hooks.slack.com/'")
        return v

    @field_validator("budget_thresholds")
    @classmethod
    def validate_thresholds(cls, v: List[float]) -> List[float]:
        """Validate budget thresholds."""
        for threshold in v:
            if threshold <= 0 or threshold > 1.0:
                raise ValueError("Budget thresholds must be between 0 and 1.0")

        # Ensure thresholds are sorted
        return sorted(set(v))


class DeploymentConfig(BaseModel):
    """Deployment configuration for applications."""

    deploy_opentelemetry: bool = Field(
        default=True,
        description="Deploy OpenTelemetry demo"
    )
    deploy_microservices: bool = Field(
        default=True,
        description="Deploy Google Microservices demo"
    )
    deploy_monitoring: bool = Field(
        default=True,
        description="Deploy monitoring stack (Prometheus/Grafana)"
    )
    enable_traffic_generation: bool = Field(
        default=True,
        description="Enable automatic traffic generation"
    )
    opentelemetry_image_tag: str = Field(
        default="latest",
        description="OpenTelemetry demo image tag"
    )
    microservices_image_tag: str = Field(
        default="latest",
        description="Microservices demo image tag"
    )


class TerraformConfig(BaseModel):
    """Terraform-specific configuration."""

    state_bucket_name: Optional[str] = Field(
        default=None,
        description="GCS bucket for Terraform state (auto-generated if not provided)"
    )
    state_prefix: str = Field(
        default="terraform/state",
        description="Prefix for state files in bucket"
    )
    enable_versioning: bool = Field(
        default=True,
        description="Enable versioning for state bucket"
    )
    enable_locking: bool = Field(
        default=True,
        description="Enable state locking"
    )


class Config(BaseModel):
    """Main configuration model for the observability demo platform."""

    gcp: GCPConfig = Field(
        ...,
        description="GCP-specific configuration"
    )
    cluster: ClusterConfig = Field(
        default_factory=ClusterConfig,
        description="GKE cluster configuration"
    )
    monitoring: MonitoringConfig = Field(
        default_factory=MonitoringConfig,
        description="Monitoring and alerting configuration"
    )
    deployment: DeploymentConfig = Field(
        default_factory=DeploymentConfig,
        description="Deployment configuration"
    )
    terraform: TerraformConfig = Field(
        default_factory=TerraformConfig,
        description="Terraform configuration"
    )

    @model_validator(mode="after")
    def set_terraform_defaults(self) -> "Config":
        """Set Terraform defaults based on GCP configuration."""
        if self.terraform.state_bucket_name is None:
            # Auto-generate state bucket name from project ID
            self.terraform.state_bucket_name = f"{self.gcp.project_id}-terraform-state"

        return self

    @classmethod
    def from_yaml(cls, file_path: Path) -> "Config":
        """
        Load configuration from a YAML file.

        Args:
            file_path: Path to the YAML configuration file

        Returns:
            Config: Validated configuration object

        Raises:
            FileNotFoundError: If the file doesn't exist
            ValueError: If the YAML is invalid or validation fails
        """
        if not file_path.exists():
            raise FileNotFoundError(f"Configuration file not found: {file_path}")

        with open(file_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)

        if data is None:
            raise ValueError("Configuration file is empty")

        return cls(**data)

    def to_yaml(self, file_path: Path) -> None:
        """
        Save configuration to a YAML file.

        Args:
            file_path: Path to save the YAML configuration file
        """
        # Create parent directory if it doesn't exist
        file_path.parent.mkdir(parents=True, exist_ok=True)

        with open(file_path, "w", encoding="utf-8") as f:
            yaml.dump(
                self.model_dump(exclude_none=True),
                f,
                default_flow_style=False,
                sort_keys=False,
                allow_unicode=True,
            )

    def to_terraform_vars(self) -> dict:
        """
        Convert configuration to Terraform variables format.

        Returns:
            dict: Dictionary suitable for Terraform tfvars file
        """
        return {
            "project_id": self.gcp.project_id,
            "region": self.gcp.region,
            "zone": self.gcp.zone,
            "cluster_name": self.cluster.name,
            "cluster_mode": self.cluster.mode,
            "enable_private_nodes": self.cluster.enable_private_nodes,
            "enable_workload_identity": self.cluster.enable_workload_identity,
            "budget_amount": self.monitoring.budget_amount,
            "notification_emails": self.monitoring.email_notifications,
            "state_bucket_name": self.terraform.state_bucket_name,
        }


# Example configuration for documentation
EXAMPLE_CONFIG = {
    "gcp": {
        "project_id": "my-observ-demo",
        "billing_account": "012345-6789AB-CDEF01",
        "region": "us-central1",
        "zone": "us-central1-a",
        "org_id": "",
    },
    "cluster": {
        "name": "observ-demo-cluster",
        "mode": "autopilot",
        "enable_private_nodes": True,
        "enable_workload_identity": True,
    },
    "monitoring": {
        "email_notifications": ["admin@example.com"],
        "slack_webhook": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
        "budget_amount": 100.0,
        "budget_thresholds": [0.5, 0.75, 0.9, 1.0],
    },
    "deployment": {
        "deploy_opentelemetry": True,
        "deploy_microservices": True,
        "deploy_monitoring": True,
        "enable_traffic_generation": True,
    },
}


def create_example_config(file_path: Path) -> None:
    """
    Create an example configuration file.

    Args:
        file_path: Path to save the example configuration
    """
    file_path.parent.mkdir(parents=True, exist_ok=True)

    with open(file_path, "w", encoding="utf-8") as f:
        yaml.dump(
            EXAMPLE_CONFIG,
            f,
            default_flow_style=False,
            sort_keys=False,
            allow_unicode=True,
        )


if __name__ == "__main__":
    # Create example configuration file
    example_path = Path("config/config.example.yaml")
    create_example_config(example_path)
    print(f"Example configuration created at: {example_path}")

    # Validate example configuration
    try:
        config = Config(**EXAMPLE_CONFIG)
        print("✓ Example configuration is valid")
        print(f"\nGenerated Terraform vars:\n{config.to_terraform_vars()}")
    except Exception as e:
        print(f"✗ Example configuration validation failed: {e}")
