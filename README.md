# PacerPro Platform Engineering Take-Home

## 1) Overview — What I Built

I built an automated monitoring and remediation system where:

- Sumo Logic detects abnormal behavior on `/api/data`
- AWS Lambda automatically remediates the issue by restarting an EC2 instance
- Amazon SNS sends alert notifications via email
- Terraform provisions and connects all infrastructure

This design mirrors real-world reliability workflows used by Platform and SRE teams.

---

## 2) High-Level Architecture

Sumo Logic Monitor
        ↓
AWS Lambda (Auto-Remediation Logic)
        ↓                    ↓
Start / Reboot EC2      SNS Notification (Email)
        ↑
Terraform provisions all resources

---

## 3) Key Assumptions

Since this is a take-home assignment and not a production environment, the following assumptions were made:

### Logging Assumptions

- Application logs contain the endpoint path `/api/data`
- Slow behavior is approximated by detecting frequent `/api/data` log events
- Real latency metrics (e.g., `response_time_ms`) are not guaranteed in synthetic logs

Reason:
The assignment environment does not provide real production telemetry, so the monitoring logic is designed to be realistic yet adaptable.

### Infrastructure Assumptions

- A single EC2 instance represents the critical service component
- Restarting the instance is a valid remediation strategy
- Lambda is triggered by monitoring alerts (simulated during testing)

Reason:
This reflects common auto-remediation patterns while keeping infrastructure minimal and cost-efficient.

---

## 4) Part 1 — Sumo Logic Monitoring

### Query Used

_sourceCategory=* 
| where _raw contains "/api/data"
| count as slow_calls

### Explanation

- _sourceCategory=*  
  Ensures compatibility with Sumo monitors by scoping logs using metadata.
- where _raw contains "/api/data"  
  Filters logs related to the `/api/data` endpoint.
- count as slow_calls  
  Converts log volume into a numeric signal for alerting.

### Monitor Configuration

- Time window: 10 minutes  
- Trigger condition: slow_calls > 5  
- Evaluation frequency: 1 minute  

### Rationale

- Latency metrics were not consistently available
- Log frequency is used as a proxy for abnormal behavior
- The query is simple, realistic, and monitor-compatible

---

## 5) Part 2 — AWS Lambda Auto-Remediation

### Function Behavior

The Lambda function:

- Reads EC2 instance ID and SNS topic ARN from environment variables
- Determines the current EC2 instance state
- Executes remediation logic:
  - If running → reboot instance
  - If stopped → start instance
- Logs actions to CloudWatch
- Sends structured notifications via SNS

### Core Logic (Simplified)

if state == "running":
    reboot_instance()
elif state == "stopped":
    start_instance()

### Design Rationale

- Handles multiple instance states safely
- Prevents invalid API calls (e.g., rebooting a stopped instance)
- Avoids hardcoding infrastructure identifiers
- Produces auditable operational logs

### Example SNS Notification

{
  "instance_id": "i-xxxxxxxx",
  "previous_state": "running",
  "action_taken": "rebooted",
  "timestamp_utc": "2026-01-29T15:21:22Z",
  "reason": "Triggered by alert (slow /api/data responses)"
}

### Why SNS

- Lightweight and cost-efficient
- Commonly used in AWS incident notification pipelines
- Decouples remediation logic from notification mechanisms

---

## 6) Part 3 — Terraform Infrastructure as Code

### Resources Provisioned

Terraform provisions and connects:

- EC2 instance
- SNS topic and email subscription
- IAM role and policies for Lambda
- Lambda function
- Environment variable bindings

### Why Terraform

- Eliminates manual configuration drift
- Ensures reproducibility
- Reflects industry-standard platform engineering practices
- Automatically wires dependencies between services

### Dynamic Resource Binding Example

environment {
  variables = {
    INSTANCE_ID   = aws_instance.pacerpro_ec2.id
    SNS_TOPIC_ARN = aws_sns_topic.pacerpro_alerts.arn
  }
}

Meaning:
Lambda always targets the EC2 instance and SNS topic created by Terraform.

---

## 7) IAM and Security Considerations

### Approach

A least-privilege security model was applied.

### Permissions Granted

- ec2:DescribeInstances
- ec2:StartInstances
- ec2:RebootInstances (scoped to a single instance)
- sns:Publish (scoped to a single topic)
- CloudWatch logging permissions

### Rationale

- Reduces blast radius in case of compromise
- Aligns with AWS security best practices
- Demonstrates production-grade IAM design principles

---

## 8) Deployment and Testing

### Terraform Deployment

terraform init
terraform validate
terraform plan
terraform apply

### Testing Steps

1. Trigger the Lambda function from the AWS Console
2. Verify EC2 instance state changes
3. Confirm SNS email notification delivery
4. Inspect CloudWatch logs

### Cleanup (Cost Control)

terraform destroy

---

## 9) Design Decisions and Tradeoffs

### Why Lambda over scripts or cron jobs?

- Event-driven architecture
- Serverless execution model
- Automatic scaling
- Common pattern in SRE auto-remediation systems

### Why EC2 restart as remediation?

- Simple yet realistic operational action
- Represents recovery of a degraded service
- Easy to validate and observe

### Why use real AWS resources?

- Provides stronger validation than simulations
- Demonstrates practical cloud engineering capability
- Reflects real-world infrastructure workflows

---

## 10) Summary

This project demonstrates:

- Log-based monitoring design
- Automated remediation workflows
- Secure IAM implementation
- Infrastructure automation using Terraform
- Real-world platform engineering patterns

The solution prioritizes simplicity, correctness, and production realism while maintaining cost efficiency and security best practices.
