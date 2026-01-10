"""
Setup configuration for observ-demo CLI package.
"""
from setuptools import setup, find_packages

setup(
    name="observ-demo",
    version="0.1.0",
    description="GCP Observability Demo Automation Platform",
    long_description="A production-ready automation solution for deploying and managing observability demos on Google Cloud Platform (GCP).",
    long_description_content_type="text/plain",
    author="Your Name",
    author_email="your.email@example.com",
    url="https://github.com/yourusername/observ-demo",
    packages=find_packages(exclude=["tests", "tests.*"]),
    include_package_data=True,
    install_requires=[
        "click>=8.1.7",
        "pydantic>=2.5.0",
        "pyyaml>=6.0.1",
        "rich>=13.7.0",
        "google-cloud-storage>=2.14.0",
        "google-cloud-compute>=1.15.0",
        "google-cloud-container>=2.35.0",
        "google-cloud-monitoring>=2.18.0",
        "google-cloud-logging>=3.9.0",
        "google-cloud-billing>=1.12.0",
        "google-cloud-secret-manager>=2.17.0",
        "google-auth>=2.26.0",
        "kubernetes>=28.1.0",
        "requests>=2.31.0",
        "python-dotenv>=1.0.0",
        "jsonschema>=4.20.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.4.3",
            "pytest-cov>=4.1.0",
            "pytest-mock>=3.12.0",
            "black>=23.12.0",
            "flake8>=7.0.0",
            "mypy>=1.8.0",
            "pylint>=3.0.3",
            "isort>=5.13.2",
            "pre-commit>=3.6.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "observ-demo=observ_demo.cli:main",
        ],
    },
    python_requires=">=3.11",
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "Intended Audience :: System Administrators",
        "Topic :: System :: Systems Administration",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Operating System :: OS Independent",
    ],
    keywords="gcp cloud observability opentelemetry terraform automation",
)
