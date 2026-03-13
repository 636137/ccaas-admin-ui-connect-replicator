# FedRAMP Compliance Guide

> **Government CCaaS in a Box** - Repeatable, FedRAMP-Ready Amazon Connect Deployment

This document describes the FedRAMP compliance features implemented in this Terraform deployment and provides guidance for achieving FedRAMP authorization.

---

## Overview

This deployment implements controls across the following FedRAMP control families:

| Control Family | Description | Modules |
|----------------|-------------|---------|
| **AC** | Access Control | IAM, KMS, VPC |
| **AU** | Audit and Accountability | CloudTrail, Config |
| **CA** | Security Assessment | Config Rules |
| **CM** | Configuration Management | Config Rules, Terraform |
| **CP** | Contingency Planning | Backup, DR |
| **IA** | Identification and Authentication | IAM, KMS |
| **IR** | Incident Response | CloudWatch Alarms, SNS |
| **SC** | System and Communications Protection | VPC, KMS, WAF |
| **SI** | System and Information Integrity | WAF, Config, CloudTrail |

---

## Quick Start

### Enable FedRAMP Compliance

```hcl
# terraform.tfvars
enable_fedramp_compliance = true
deploy_in_vpc             = true
enable_waf                = true
enable_backup             = true
security_contact_email    = "security@agency.gov"
```

### Disable FedRAMP (Development Only)

```hcl
# terraform.tfvars
enable_fedramp_compliance = false
```

---

## Module Details

### 1. KMS Encryption (SC-12, SC-13, SC-28)

**Purpose:** Customer-managed encryption keys for all data at rest

**Keys Created:**
| Key | Purpose | Rotation |
|-----|---------|----------|
| Primary | DynamoDB, S3, general encryption | Annual |
| Connect | Call recordings, transcripts | Annual |
| Logs | CloudWatch Logs encryption | Annual |
| Secrets | Secrets Manager encryption | Annual |

**FedRAMP Controls:**
- SC-12: Cryptographic Key Establishment and Management
- SC-13: Cryptographic Protection
- SC-28: Protection of Information at Rest

**Configuration:**
```hcl
module "kms" {
  source = "./modules/kms"
  
  key_administrators  = ["arn:aws:iam::ACCOUNT:role/SecurityAdmin"]
  key_deletion_window = 30  # FedRAMP recommends 30 days
}
```

---

### 2. CloudTrail Audit Logging (AU-2, AU-3, AU-9, AU-12)

**Purpose:** Complete audit trail of all AWS API activity

**Features:**
- Multi-region trail
- Log file integrity validation
- CloudWatch Logs integration
- S3 lifecycle policies (7-year retention)
- Security event alarms

**Audit Events Captured:**
- All management events
- S3 data events
- Lambda invocations
- DynamoDB operations

**Security Alarms:**
| Alarm | Trigger | FedRAMP Control |
|-------|---------|-----------------|
| Unauthorized API Calls | 5+ AccessDenied errors | AU-6, IR-4 |
| Root Account Usage | Any root login | AC-6 |
| IAM Policy Changes | Any IAM modification | AC-2, CM-3 |
| Security Group Changes | Any SG modification | CM-3, SC-7 |
| Console Login Without MFA | Non-MFA login | IA-2 |

**Log Retention:**
| Period | Storage Class | Cost |
|--------|---------------|------|
| 0-90 days | Standard | $$$ |
| 90-365 days | Intelligent-Tiering | $$ |
| 1-3 years | Glacier | $ |
| 3-7 years | Deep Archive | ¢ |

---

### 3. VPC Network Isolation (SC-7, SC-8, AC-4)

**Purpose:** Network segmentation and encrypted transit

**Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│                          VPC (10.0.0.0/16)                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ Private Subnet  │  │ Private Subnet  │  │ Private Sub  │ │
│  │   (us-east-1a)  │  │   (us-east-1b)  │  │  (us-east-1c)│ │
│  │   10.0.0.0/20   │  │   10.0.16.0/20  │  │ 10.0.32.0/20 │ │
│  │                 │  │                 │  │              │ │
│  │  ┌──────────┐   │  │  ┌──────────┐   │  │ ┌──────────┐ │ │
│  │  │  Lambda  │   │  │  │  Lambda  │   │  │ │  Lambda  │ │ │
│  │  └──────────┘   │  │  └──────────┘   │  │ └──────────┘ │ │
│  └────────┬────────┘  └────────┬────────┘  └──────┬───────┘ │
│           │                    │                   │         │
│  ┌────────┴────────────────────┴───────────────────┴───────┐ │
│  │              VPC Endpoints (PrivateLink)                 │ │
│  │  DynamoDB | S3 | Lambda | KMS | Logs | Bedrock | SNS    │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**VPC Endpoints (No Internet Required):**
- DynamoDB (Gateway)
- S3 (Gateway)
- Lambda (Interface)
- Secrets Manager (Interface)
- KMS (Interface)
- CloudWatch Logs (Interface)
- Bedrock Runtime (Interface)
- SNS (Interface)
- STS (Interface)

**VPC Flow Logs:**
- 1-minute aggregation intervals
- KMS encrypted
- 365-day retention

---

### 4. WAF Web Application Firewall (SC-5, SC-7, SI-3)

**Purpose:** Protection against common web attacks

**Rules Enabled:**
| Rule | Protection | Priority |
|------|------------|----------|
| AWSManagedRulesCommonRuleSet | OWASP Top 10 | 1 |
| AWSManagedRulesKnownBadInputsRuleSet | Known exploits | 2 |
| AWSManagedRulesSQLiRuleSet | SQL injection | 3 |
| AWSManagedRulesLinuxRuleSet | Linux vulnerabilities | 4 |
| AWSManagedRulesAmazonIpReputationList | Bad IP addresses | 5 |
| AWSManagedRulesAnonymousIpList | Tor/VPN/Proxy | 6 |
| RateLimitRule | DDoS protection | 7 |
| GeoRestriction | US-only access | 8 |

**Rate Limiting:**
- Default: 2,000 requests per 5 minutes per IP
- Configurable via `waf_rate_limit` variable

**Geographic Restriction:**
- Enabled by default (US-only)
- Configurable via `waf_allowed_countries`

---

### 5. AWS Config Continuous Compliance (CA-7, CM-2, CM-6)

**Purpose:** Continuous monitoring of resource compliance

**Rules Implemented:**

#### Encryption Rules (SC-28)
- S3 bucket server-side encryption
- DynamoDB KMS encryption
- EBS encryption by default
- RDS storage encryption
- CloudWatch Logs encryption

#### Access Control Rules (AC-2, AC-6, IA-2)
- Root account MFA enabled
- IAM user MFA enabled
- No root access keys
- Password policy compliance

#### Logging Rules (AU-2, AU-12)
- CloudTrail enabled
- CloudTrail log file validation
- S3 bucket logging
- VPC Flow Logs enabled

#### Network Security Rules (SC-7)
- Restricted SSH access
- Restricted RDP access
- No public S3 buckets
- Lambda functions in VPC

**Non-Compliance Notifications:**
- EventBridge rule for compliance changes
- SNS topic for alerts
- Automatic email notifications

---

### 6. AWS Backup Disaster Recovery (CP-9, CP-10, CP-6)

**Purpose:** Automated backups and cross-region replication

**Backup Schedule:**
| Type | Frequency | Retention | Cold Storage |
|------|-----------|-----------|--------------|
| Daily | Every day 5 AM UTC | 35 days | After 30 days |
| Weekly | Sunday 5 AM UTC | 90 days | After 30 days |
| Monthly | 1st of month | 1 year | After 30 days |

**Cross-Region Replication:**
- Enabled by default
- Default DR region: us-west-2
- Same retention policies apply

**Resources Backed Up:**
- DynamoDB tables (via ARN)
- Resources tagged with `Backup=true`

**Backup Vault Protection:**
- Restricted deletion (admin approval required)
- Encrypted with customer-managed KMS key

---

## FedRAMP Control Matrix

### Access Control (AC)

| Control | Implementation | Module |
|---------|----------------|--------|
| AC-2 | IAM users with MFA required | Config Rules |
| AC-3 | IAM policies, S3 bucket policies | IAM, Config |
| AC-4 | VPC network ACLs, security groups | VPC |
| AC-6 | No root account usage, least privilege | CloudTrail, Config |

### Audit and Accountability (AU)

| Control | Implementation | Module |
|---------|----------------|--------|
| AU-2 | CloudTrail event logging | CloudTrail |
| AU-3 | Comprehensive audit records | CloudTrail |
| AU-4 | S3 storage with lifecycle | CloudTrail |
| AU-6 | CloudWatch Logs, alarms | CloudTrail |
| AU-7 | Log search via CloudWatch Insights | CloudTrail |
| AU-9 | Log file validation, KMS encryption | CloudTrail, KMS |
| AU-11 | 7-year retention with Glacier | CloudTrail |
| AU-12 | Multi-region, all event types | CloudTrail |

### Configuration Management (CM)

| Control | Implementation | Module |
|---------|----------------|--------|
| CM-2 | Terraform baseline configuration | All modules |
| CM-3 | Config rule for changes | Config Rules |
| CM-6 | AWS Config continuous monitoring | Config Rules |

### Contingency Planning (CP)

| Control | Implementation | Module |
|---------|----------------|--------|
| CP-6 | Cross-region backup replication | Backup |
| CP-9 | AWS Backup automated backups | Backup |
| CP-10 | Point-in-time recovery | Backup, DynamoDB |

### Identification and Authentication (IA)

| Control | Implementation | Module |
|---------|----------------|--------|
| IA-2 | MFA required for console access | Config Rules |
| IA-5 | Password policy enforcement | Config Rules |

### System and Communications Protection (SC)

| Control | Implementation | Module |
|---------|----------------|--------|
| SC-5 | WAF rate limiting, DDoS protection | WAF |
| SC-7 | VPC, security groups, NACLs, WAF | VPC, WAF |
| SC-8 | VPC endpoints (PrivateLink), TLS | VPC |
| SC-12 | Customer-managed KMS keys | KMS |
| SC-13 | AES-256 encryption | KMS |
| SC-28 | Encryption at rest for all data | KMS, Config |

### System and Information Integrity (SI)

| Control | Implementation | Module |
|---------|----------------|--------|
| SI-2 | Config rules for vulnerabilities | Config Rules |
| SI-3 | WAF malicious input protection | WAF |
| SI-4 | VPC Flow Logs, CloudTrail | VPC, CloudTrail |

---

## Deployment Checklist

### Pre-Deployment

- [ ] Review and customize `terraform.tfvars`
- [ ] Configure `security_contact_email` for alerts
- [ ] Set `kms_key_administrators` IAM ARNs
- [ ] Confirm DR region (`dr_region`)
- [ ] Review VPC CIDR ranges for conflicts

### Post-Deployment

- [ ] Verify CloudTrail is logging
- [ ] Confirm Config rules are evaluating
- [ ] Test backup job execution
- [ ] Subscribe to SNS security alerts
- [ ] Review WAF metrics dashboard
- [ ] Document any non-compliant resources

### Ongoing Operations

- [ ] Weekly: Review security alarm notifications
- [ ] Monthly: Check Config compliance dashboard
- [ ] Monthly: Verify backup completion reports
- [ ] Quarterly: Review and rotate access keys
- [ ] Annually: Update KMS key policies

---

## Cost Estimation

| Component | Monthly Cost (Estimate) |
|-----------|------------------------|
| KMS Keys (4 keys) | $4 |
| CloudTrail | $5-50 (based on events) |
| VPC Endpoints (8 endpoints) | $56 |
| NAT Gateway (3 AZs) | $100+ |
| WAF | $5 + $0.60/million requests |
| Config Rules (18 rules) | $36 |
| AWS Backup | Based on storage |
| **Total (minimum)** | **~$200/month** |

**Cost Optimization:**
- Use `single_nat_gateway = true` for non-prod ($66 savings)
- Disable `enable_vpc_endpoints` if internet access acceptable
- Use `enable_cross_region_backup = false` for dev environments

---

## Support and References

### AWS Documentation
- [FedRAMP on AWS](https://aws.amazon.com/compliance/fedramp/)
- [AWS Services in Scope](https://aws.amazon.com/compliance/services-in-scope/)
- [AWS Security Hub](https://aws.amazon.com/security-hub/)

### FedRAMP Resources
- [FedRAMP.gov](https://www.fedramp.gov/)
- [FedRAMP Control Matrix](https://www.fedramp.gov/assets/resources/documents/FedRAMP_Security_Controls_Baseline.xlsx)

### This Project
- [GitHub Repository](https://github.com/636137/MarcS-CensusDemo)
- [AGENT_OPTIONS_COMPARISON.md](AGENT_OPTIONS_COMPARISON.md)
- [README.md](README.md)
