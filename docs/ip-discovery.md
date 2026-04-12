# IP Discovery

The EC2 instance gets a new public IP every time it starts — there is no Elastic IP (to stay within AWS free tier).

## Via the GitHub Actions pipeline (recommended)

Trigger **Actions → Proxy → Run workflow** → `status`.

The job outputs:
```
State: running
IP:    1.2.3.4
```

## Via AWS CLI

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=proxy-ec2" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text \
  --profile quickproxy-client
```

Returns the current public IP, or `None` if the instance is stopped.

## Note

Always check the IP after starting the instance — never assume it's the same as last time.
