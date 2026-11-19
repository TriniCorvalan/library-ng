#!/usr/bin/env bash
# Crea o actualiza el stack EC2 (CloudFormation) y escribe los outputs.
set -Eeuo pipefail

region="${1:?AWS region is required}"
stack_name="${2:?CloudFormation stack name is required}"
template_file="${3:?CloudFormation template path is required}"

if [[ ! "$region" =~ ^[a-z0-9-]+$ || ! "$stack_name" =~ ^[A-Za-z][A-Za-z0-9-]*$ ]]; then
  echo "Invalid region or stack name." >&2
  exit 2
fi
if [[ ! -f "$template_file" ]]; then
  echo "Template not found: $template_file" >&2
  exit 2
fi

: "${ORACLE_CREDENTIALS_SECRET_ARN:?Set ORACLE_CREDENTIALS_SECRET_ARN}"
oracle_wallet_object_key="${ORACLE_WALLET_S3_KEY:-Wallet.zip}"
oracle_wallet_bucket_name="${ORACLE_WALLET_S3_BUCKET:-}"
create_instance_role="${CREATE_INSTANCE_ROLE:-false}"
existing_instance_profile="${EXISTING_INSTANCE_PROFILE_NAME:-LabInstanceProfile}"
instance_type="${INSTANCE_TYPE:-t3.medium}"
allowed_http_cidr="${ALLOWED_HTTP_CIDR:-0.0.0.0/0}"

if [[ ! "$ORACLE_CREDENTIALS_SECRET_ARN" =~ ^arn:aws:secretsmanager:${region}:[0-9]{12}:secret:[A-Za-z0-9/_+=.@-]+$ ]]; then
  echo "ORACLE_CREDENTIALS_SECRET_ARN is not a valid Secrets Manager ARN for region $region." >&2
  exit 2
fi
if [[ ! "$oracle_wallet_object_key" =~ ^[A-Za-z0-9._/-]{1,1024}$ ]]; then
  echo "Invalid ORACLE_WALLET_S3_KEY." >&2
  exit 2
fi
if [[ -n "$oracle_wallet_bucket_name" \
  && ! "$oracle_wallet_bucket_name" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]]; then
  echo "Invalid ORACLE_WALLET_S3_BUCKET." >&2
  exit 2
fi
if [[ ! "$create_instance_role" =~ ^(true|false)$ ]]; then
  echo "CREATE_INSTANCE_ROLE must be true or false." >&2
  exit 2
fi

vpc_id="${VPC_ID:-}"
public_subnet_id="${PUBLIC_SUBNET_ID:-}"

if [[ -z "$vpc_id" ]]; then
  vpc_id="$(aws ec2 describe-vpcs \
    --region "$region" \
    --filters Name=isDefault,Values=true \
    --query 'Vpcs[0].VpcId' \
    --output text)"
  if [[ -z "$vpc_id" || "$vpc_id" == "None" ]]; then
    vpc_count="$(aws ec2 describe-vpcs --region "$region" --query 'length(Vpcs)' --output text)"
    if [[ "$vpc_count" == "1" ]]; then
      vpc_id="$(aws ec2 describe-vpcs --region "$region" --query 'Vpcs[0].VpcId' --output text)"
    else
      echo "Set VPC_ID: could not pick a single default VPC (found $vpc_count)." >&2
      exit 1
    fi
  fi
  echo "Resolved VPC_ID=$vpc_id"
fi

if [[ -z "$public_subnet_id" ]]; then
  public_subnet_id="$(aws ec2 describe-subnets \
    --region "$region" \
    --filters "Name=vpc-id,Values=$vpc_id" "Name=map-public-ip-on-launch,Values=true" \
    --query 'Subnets | sort_by(@, &AvailabilityZone) | [0].SubnetId' \
    --output text)"
  if [[ -z "$public_subnet_id" || "$public_subnet_id" == "None" ]]; then
    echo "Set PUBLIC_SUBNET_ID: no subnet with MapPublicIpOnLaunch=true in $vpc_id." >&2
    exit 1
  fi
  echo "Resolved PUBLIC_SUBNET_ID=$public_subnet_id"
fi

capabilities=()
if [[ "$create_instance_role" == "true" ]]; then
  capabilities+=(--capabilities CAPABILITY_NAMED_IAM)
fi

echo "Deploying CloudFormation stack $stack_name in $region..."
aws cloudformation deploy \
  --region "$region" \
  --stack-name "$stack_name" \
  --template-file "$template_file" \
  --no-fail-on-empty-changeset \
  "${capabilities[@]}" \
  --parameter-overrides \
    "VpcId=$vpc_id" \
    "PublicSubnetId=$public_subnet_id" \
    "OracleCredentialsSecretArn=$ORACLE_CREDENTIALS_SECRET_ARN" \
    "OracleWalletObjectKey=$oracle_wallet_object_key" \
    "OracleWalletBucketName=$oracle_wallet_bucket_name" \
    "CreateInstanceRole=$create_instance_role" \
    "ExistingInstanceProfileName=$existing_instance_profile" \
    "InstanceType=$instance_type" \
    "AllowedHttpCidr=$allowed_http_cidr"

status="$(aws cloudformation describe-stacks \
  --region "$region" \
  --stack-name "$stack_name" \
  --query 'Stacks[0].StackStatus' \
  --output text)"
case "$status" in
  CREATE_COMPLETE|UPDATE_COMPLETE|IMPORT_COMPLETE)
    echo "Stack status: $status"
    ;;
  *)
    echo "Stack status is $status (expected CREATE_COMPLETE or UPDATE_COMPLETE)." >&2
    aws cloudformation describe-stack-events \
      --region "$region" \
      --stack-name "$stack_name" \
      --query 'StackEvents[?ResourceStatus!=`CREATE_IN_PROGRESS` && ResourceStatus!=`UPDATE_IN_PROGRESS`]|[0:8].[Timestamp,LogicalResourceId,ResourceStatus,ResourceStatusReason]' \
      --output table >&2 || true
    exit 1
    ;;
esac

outputs="$(aws cloudformation describe-stacks \
  --region "$region" \
  --stack-name "$stack_name" \
  --query 'Stacks[0].Outputs' \
  --output json)"

instance_id="$(jq -r '.[] | select(.OutputKey=="InstanceId") | .OutputValue' <<< "$outputs")"
wallet_bucket="$(jq -r '.[] | select(.OutputKey=="WalletBucketName") | .OutputValue' <<< "$outputs")"
wallet_key="$(jq -r '.[] | select(.OutputKey=="WalletObjectKey") | .OutputValue' <<< "$outputs")"
website_url="$(jq -r '.[] | select(.OutputKey=="WebsiteUrl") | .OutputValue' <<< "$outputs")"
public_ip="$(jq -r '.[] | select(.OutputKey=="PublicIp") | .OutputValue' <<< "$outputs")"

{
  echo "## EC2 stack ready"
  echo ""
  echo "| Output | Value |"
  echo "|--------|-------|"
  echo "| InstanceId | \`$instance_id\` |"
  echo "| PublicIp | \`$public_ip\` |"
  echo "| WebsiteUrl | $website_url |"
  echo "| WalletBucketName | \`$wallet_bucket\` |"
  echo "| WalletObjectKey | \`$wallet_key\` |"
  echo ""
  echo "Next:"
  echo "1. Upload the Oracle wallet ZIP to \`s3://$wallet_bucket/$wallet_key\`."
  echo "2. Set Actions variable \`EC2_INSTANCE_ID=$instance_id\` in **library** and **library-ng**."
  echo "3. Set Oracle wallet variables in **library**, then run the API deploy workflow, then the frontend."
} | tee "${GITHUB_STEP_SUMMARY:-/dev/stdout}"

echo "INSTANCE_ID=$instance_id"
echo "WALLET_BUCKET=$wallet_bucket"
echo "WALLET_KEY=$wallet_key"
echo "WEBSITE_URL=$website_url"
echo "PUBLIC_IP=$public_ip"
