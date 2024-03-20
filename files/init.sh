#!/bin/bash

# Define environment variables
SSM_PATH_DEFAULT_CREDENTIAL="${SSM_PATH_DEFAULT_CREDENTIAL}"
CLOUD_WATCH="${CLOUD_WATCH}"
BACKUPS="${BACKUPS}"
BACKUP_CRON="${BACKUP_CRON}"
BUCKET_NAME="${BUCKET_NAME}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}"
CW_LOGS_GROUP="${CW_LOGS_GROUP}"
AUTO_RESTORE="${AUTO_RESTORE}"

export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION

# Adding swap space
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Setting up apt sources for Pritunl and MongoDB
sudo tee /etc/apt/sources.list.d/pritunl.list << EOF
deb http://repo.pritunl.com/stable/apt jammy main
EOF

sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv 7568D9BB55FF9E5287D586017AE645C0CF8E292A
curl https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc | sudo apt-key add -

sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list << EOF
deb https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse
EOF

wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -

sudo apt update
sudo apt upgrade -y 
sudo apt install awscli wireguard wireguard-tools mongodb-org pritunl -y 
sudo sh -c 'echo "* hard nofile 64000" >> /etc/security/limits.conf'
sudo sh -c 'echo "* soft nofile 64000" >> /etc/security/limits.conf'
sudo sh -c 'echo "root hard nofile 64000" >> /etc/security/limits.conf'
sudo sh -c 'echo "root soft nofile 64000" >> /etc/security/limits.conf'
sudo systemctl enable mongod pritunl
sudo systemctl start mongod pritunl

sudo pritunl set-mongodb mongodb://localhost:27017/pritunl
sudo systemctl restart pritunl

# Function to set up Pritunl default credentials
setup_pritunl_credentials() {
    PRITUNL_DEFAULT_CREDENTIALS=$(sudo pritunl default-password | grep -E 'username:|password:' | awk '{print $1,$2}')
    aws ssm put-parameter --region $AWS_DEFAULT_REGION --name "$SSM_PATH_DEFAULT_CREDENTIAL" --type "String" --value "$PRITUNL_DEFAULT_CREDENTIALS" --overwrite --type "SecureString"
}

# Check for AUTO_RESTORE condition
if [ "${AUTO_RESTORE}" = "true" ]; then
    # Check if bucket exists
    if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
        echo "Bucket does not exist, proceeding with default setup."
        setup_pritunl_credentials
    else
        # Check if the backup file exists
        BACKUP_FILE="s3://${BUCKET_NAME}-backups-${data.aws_caller_identity.current.account_id}/mongodb_backup.gz"
        if aws s3 ls "${BACKUP_FILE}" 2>&1 | grep -q 'NoSuchKey'; then
            echo "Backup file does not exist, proceeding with default setup."
            setup_pritunl_credentials
        else
            echo "Restoring from backup..."
            aws s3 cp "${BACKUP_FILE}" mongodb_backup.gz
            mongorestore --gzip --archive=mongodb_backup.gz
        fi
    fi
else
    echo "AUTO_RESTORE is set to false, proceeding with default setup."
    setup_pritunl_credentials
fi

# Install CloudWatch Agent
if [ "${CLOUD_WATCH}" = "true" ]; then
sudo wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# Configure CloudWatch Agent
cat <<EOF > cloudwatch-agent-config.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/pritunl.log",
            "log_group_name": "$CW_LOGS_GROUP",
            "log_stream_name": "{instance_id}",
            "timezone": "Local"
          }
        ]
      }
    }
  }
}
EOF

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:cloudwatch-agent-config.json -s
fi