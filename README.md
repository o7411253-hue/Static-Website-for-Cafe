# ☕ Frank & Martha's Café - Static Website Infrastructure

## Project Overview

This project demonstrates the implementation of a **highly available, durable, and cost-optimized static website** for a small café business using **Amazon S3** and **Terraform**.

## Infrastructure Resources

| Resource | Purpose |
|----------|---------|
| Source S3 Bucket | Hosts the static website (us-east-1) |
| Destination S3 Bucket | Disaster recovery replica (us-west-2) |
| Bucket Policy | Grants public read access |
| Versioning | Prevents accidental overwrites/deletions |
| Lifecycle Rules | Moves old versions to S3-IA, deletes after 365 days |
| Cross-Region Replication | Automatically replicates data to DR region |
| IAM Role | Permissions for S3 replication |

## Architecture Diagram
