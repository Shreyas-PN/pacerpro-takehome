import os
import json
import boto3
from datetime import datetime, timezone
from botocore.exceptions import ClientError

ec2 = boto3.client("ec2")
sns = boto3.client("sns")

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    instance_id = os.environ.get("INSTANCE_ID")
    topic_arn = os.environ.get("SNS_TOPIC_ARN")

    if not instance_id:
        raise ValueError("Missing env var: INSTANCE_ID")
    if not topic_arn:
        raise ValueError("Missing env var: SNS_TOPIC_ARN")

    # Get instance state
    response = ec2.describe_instances(InstanceIds=[instance_id])
    state = response["Reservations"][0]["Instances"][0]["State"]["Name"]

    print(f"Current EC2 state: {state}")

    action = ""

    try:
        if state == "running":
            print(f"Rebooting EC2 instance: {instance_id}")
            ec2.reboot_instances(InstanceIds=[instance_id])
            action = "rebooted"
        elif state == "stopped":
            print(f"Starting EC2 instance: {instance_id}")
            ec2.start_instances(InstanceIds=[instance_id])
            action = "started"
        else:
            action = f"no_action_state_{state}"
            print(f"No action taken. Instance state: {state}")

    except ClientError as e:
        print("AWS error:", str(e))
        raise

    # Send SNS notification
    timestamp = datetime.now(timezone.utc).isoformat()
    msg = {
        "instance_id": instance_id,
        "previous_state": state,
        "action_taken": action,
        "timestamp_utc": timestamp,
        "reason": "Triggered by alert (slow /api/data responses)"
    }

    sns.publish(
        TopicArn=topic_arn,
        Subject="PacerPro: EC2 auto-remediation triggered",
        Message=json.dumps(msg, indent=2)
    )

    print("SNS notification sent.")

    return {
        "statusCode": 200,
        "body": json.dumps({"ok": True, "action": action})
    }
