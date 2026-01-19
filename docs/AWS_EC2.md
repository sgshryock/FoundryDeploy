# Running FoundryDeploy on AWS EC2

This guide explains how to deploy Foundry VTT on AWS EC2 instances.

## Quick Start Options

1. **Manual Setup** - Launch an EC2 instance and run the setup script
2. **Cloud-Init** - Use the provided user data script for automatic provisioning
3. **Terraform** - Deploy with Infrastructure as Code

---

## Prerequisites

- AWS Account with EC2 permissions
- SSH key pair created in AWS
- Basic understanding of AWS Security Groups

## Recommended Instance Types

| Instance Type | vCPUs | RAM | Use Case | Monthly Cost* |
|--------------|-------|-----|----------|---------------|
| t3.micro | 2 | 1 GB | Testing only | ~$8 |
| **t3.small** | 2 | 2 GB | Small groups (1-4 players) | ~$15 |
| t3.medium | 2 | 4 GB | Medium groups (5-8 players) | ~$30 |
| t3.large | 2 | 8 GB | Large groups, many modules | ~$60 |

*Approximate costs in US regions, excluding storage and data transfer.

---

## Method 1: Manual Setup

### Launch EC2 Instance

1. Go to **EC2 > Launch Instance**
2. **Name:** Foundry-VTT-Server
3. **AMI:** Ubuntu Server 22.04 LTS (or Debian 12)
4. **Instance type:** t3.small (recommended)
5. **Key pair:** Select your SSH key
6. **Network settings:**
   - Allow SSH from your IP
   - Allow HTTP (port 80) from anywhere
   - Allow HTTPS (port 443) from anywhere
7. **Storage:** 50 GB gp3 (minimum 20 GB)
8. **Launch instance**

### Connect and Setup

```bash
# SSH to your instance
ssh -i ~/.ssh/your-key.pem ubuntu@<public-ip>

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y git docker.io docker-compose-v2 nginx openssl

# Start Docker
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# Log out and back in for group changes
exit

# SSH back in
ssh -i ~/.ssh/your-key.pem ubuntu@<public-ip>

# Download and run setup
curl -fsSL https://raw.githubusercontent.com/sgshryock/FoundryDeploy/main/setup -o setup
chmod +x setup
./setup
```

---

## Method 2: Cloud-Init (Recommended)

Use the provided cloud-init script to automatically provision the instance.

### Via AWS Console

1. Go to **EC2 > Launch Instance**
2. Configure as above
3. Expand **Advanced details**
4. Paste the contents of `aws/cloud-init.yaml` into **User data**
5. Launch instance

### Via AWS CLI

```bash
# Download the cloud-init file
curl -fsSL https://raw.githubusercontent.com/sgshryock/FoundryDeploy/main/aws/cloud-init.yaml -o cloud-init.yaml

# Launch instance
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --instance-type t3.small \
  --key-name your-key-name \
  --security-group-ids sg-xxxxxxxx \
  --user-data file://cloud-init.yaml \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Foundry-VTT}]'
```

### Complete Setup

After cloud-init completes (2-3 minutes):

```bash
# SSH to instance
ssh -i ~/.ssh/your-key.pem ubuntu@<public-ip>

# Switch to foundry user
sudo su - foundry

# Run setup
./setup
```

---

## Method 3: Terraform

Deploy using Infrastructure as Code for reproducible deployments.

### Prerequisites

- [Terraform](https://terraform.io) installed
- AWS CLI configured with credentials

### Deploy

```bash
# Clone the repository
git clone https://github.com/sgshryock/FoundryDeploy.git
cd FoundryDeploy/aws/terraform

# Initialize Terraform
terraform init

# Create terraform.tfvars with your settings
cat > terraform.tfvars << 'EOF'
key_name        = "your-ssh-key-name"
instance_type   = "t3.small"
root_volume_size = 50

# Optional: restrict SSH access to your IP
ssh_cidr_blocks = ["YOUR.IP.ADDRESS/32"]

# Optional: create Elastic IP for static IP
create_elastic_ip = true

tags = {
  Project     = "FoundryVTT"
  Environment = "production"
}
EOF

# Review plan
terraform plan

# Deploy
terraform apply
```

### Terraform Outputs

After deployment, Terraform will output:
- Public IP address
- SSH command
- Foundry URL
- Setup instructions

### Destroy

```bash
terraform destroy
```

---

## Security Configuration

### Security Group Rules

| Type | Port | Source | Description |
|------|------|--------|-------------|
| SSH | 22 | Your IP | Management access |
| HTTP | 80 | 0.0.0.0/0 | Redirect to HTTPS |
| HTTPS | 443 | 0.0.0.0/0 | Foundry access |

### Restricting Access

For private games, restrict HTTP/HTTPS to specific IPs:

```bash
# AWS CLI - update security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxx \
  --protocol tcp \
  --port 443 \
  --cidr YOUR.PLAYER1.IP/32

aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxx \
  --protocol tcp \
  --port 443 \
  --cidr YOUR.PLAYER2.IP/32
```

Or in Terraform:

```hcl
allowed_cidr_blocks = [
  "YOUR.IP/32",
  "PLAYER1.IP/32",
  "PLAYER2.IP/32"
]
```

---

## SSL Certificates

### Self-Signed (Default)

FoundryDeploy generates self-signed certificates automatically. Players will need to accept the browser warning.

### Let's Encrypt (Recommended for Production)

For trusted SSL certificates:

1. **Get a domain name** pointing to your EC2 public IP
2. **Install certbot:**
   ```bash
   sudo apt install certbot python3-certbot-nginx
   ```
3. **Obtain certificate:**
   ```bash
   sudo certbot --nginx -d yourdomain.com
   ```
4. **Auto-renewal** is configured automatically

### Using Elastic IP

For stable IP addresses (recommended for DNS):

```hcl
# In Terraform
create_elastic_ip = true
```

Or manually:
1. EC2 > Elastic IPs > Allocate
2. Associate with your instance
3. Update DNS to point to the Elastic IP

---

## Cost Optimization

### Reserved Instances

For long-running servers, consider Reserved Instances:
- 1-year: ~30% savings
- 3-year: ~50% savings

### Spot Instances

For development/testing (not recommended for production):
- Up to 90% savings
- May be interrupted

### Auto-Stop

Create a Lambda function or use Instance Scheduler to stop the instance when not in use.

---

## Backup and Recovery

### EBS Snapshots

```bash
# Create snapshot
aws ec2 create-snapshot \
  --volume-id vol-xxxxxxxx \
  --description "Foundry VTT Backup $(date +%Y%m%d)"
```

### Automated Backups

Use AWS Backup or a scheduled Lambda:

```bash
# Add to crontab for daily snapshots
0 4 * * * aws ec2 create-snapshot --volume-id vol-xxxxxxxx --description "Daily Foundry Backup"
```

### S3 Backup

For off-instance backups:

```bash
# Backup Foundry data to S3
docker run --rm \
  -v foundrydeploy_foundry_data:/data \
  -e AWS_ACCESS_KEY_ID=xxx \
  -e AWS_SECRET_ACCESS_KEY=xxx \
  amazon/aws-cli s3 sync /data s3://your-bucket/foundry-backup/
```

---

## Monitoring

### CloudWatch

Enable detailed monitoring in Terraform:

```hcl
enable_monitoring = true
```

### Basic Metrics

- CPU Utilization
- Network In/Out
- Disk Read/Write

### CloudWatch Alarms

```bash
# Alert when CPU > 80%
aws cloudwatch put-metric-alarm \
  --alarm-name "Foundry-High-CPU" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=i-xxxxxxxx \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:region:account:topic
```

---

## Troubleshooting

### Can't Connect via SSH

1. Check Security Group allows port 22 from your IP
2. Verify key pair matches the instance
3. Check instance is in "running" state
4. Check VPC has internet gateway and route table

### Can't Access Foundry

1. Verify Security Group allows ports 80 and 443
2. Check nginx is running: `sudo systemctl status nginx`
3. Check Foundry is running: `docker compose ps`
4. Test locally: `curl -k https://localhost`

### Cloud-Init Didn't Complete

Check cloud-init logs:

```bash
sudo cat /var/log/cloud-init-output.log
sudo cat /var/log/cloud-init.log
```

### Out of Disk Space

```bash
# Check disk usage
df -h

# Clean Docker
docker system prune -a

# Increase EBS volume size in AWS Console
# Then extend filesystem
sudo growpart /dev/xvda 1
sudo resize2fs /dev/xvda1
```

---

## Architecture Diagram

```
                    Internet
                        │
                        ▼
              ┌─────────────────┐
              │   Route 53      │  (Optional: DNS)
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │ Elastic IP      │  (Optional: Static IP)
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │ Security Group  │  Ports: 22, 80, 443
              └────────┬────────┘
                       │
                       ▼
    ┌──────────────────────────────────────┐
    │            EC2 Instance              │
    │  ┌─────────────────────────────────┐ │
    │  │           nginx                  │ │
    │  │      (Reverse Proxy)            │ │
    │  │    Ports 80, 443 → 30000        │ │
    │  └─────────────┬───────────────────┘ │
    │                │                     │
    │  ┌─────────────▼───────────────────┐ │
    │  │         Docker                   │ │
    │  │  ┌─────────────────────────┐    │ │
    │  │  │    Foundry VTT          │    │ │
    │  │  │    Container            │    │ │
    │  │  │    Port 30000           │    │ │
    │  │  └─────────────────────────┘    │ │
    │  └─────────────────────────────────┘ │
    │                                      │
    │  ┌─────────────────────────────────┐ │
    │  │       EBS Volume (gp3)          │ │
    │  │    /var/lib/docker              │ │
    │  │    (Foundry data)               │ │
    │  └─────────────────────────────────┘ │
    └──────────────────────────────────────┘
```

---

## Future Enhancements

The following are potential future improvements (not currently implemented):

- **ECS/Fargate** - Serverless container deployment
- **ALB** - Application Load Balancer with ACM certificates
- **RDS** - External database for larger deployments
- **CloudFront** - CDN for static assets
