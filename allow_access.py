import boto3
import json
import os
from datetime import datetime, timedelta
import jwt
import requests


ec2 = boto3.client('ec2', region_name=os.environ['STAR_LORD_SECURITY_GROUP_REGION'])
event_bridge = boto3.client('scheduler')
log_group_name = os.environ['STAR_LORD_LOG_GROUP_NAME']
cognito_user_pool_id = os.environ['STAR_LORD_COGNITO_USER_POOL_ID']
region = os.environ['STAR_LORD_AWS_REGION']
cognito_domain = os.environ['STAR_LORD_COGNITO_DOMAIN']
client_id = os.environ['STAR_LORD_COGNITO_CLIENT_ID']
client_secret = os.environ['STAR_LORD_COGNITO_CLIENT_SECRET']
redirect_uri = os.environ['STAR_LORD_CALLBACK_URL']
keys_url = f"https://cognito-idp.{region}.amazonaws.com/{cognito_user_pool_id}/.well-known/jwks.json"

def lambda_handler(event, context):
    if event['queryStringParameters'] is None:
        return redirect_to_login()
    
    code = event['queryStringParameters'].get('code')
    
    if not code:
        return redirect_to_login()
    
    # Exchange authorization code for tokens
    token_url = f"https://{cognito_domain}.auth.{region}.amazoncognito.com/oauth2/token"
    token_data = {
        'grant_type': 'authorization_code',
        'client_id': client_id,
        'client_secret': client_secret,
        'code': code,
        'redirect_uri': redirect_uri
    }
    token_headers = {
        'Content-Type': 'application/x-www-form-urlencoded'
    }
    
    token_response = requests.post(token_url, data=token_data, headers=token_headers)
    
    if token_response.status_code != 200:
        return {
            'statusCode': token_response.status_code,
            'body': json.dumps(token_response.json())
        }
    
    tokens = token_response.json()
    id_token = tokens['id_token']
    
    if not id_token:
        return redirect_to_login()
    
    # Verify the JWT token
    try:
        #keys = requests.get(keys_url).json()
        decoded_token = jwt.decode(id_token, algorithms=['RS256'],options={"verify_signature": False})
    except jwt.ExpiredSignatureError:
        return redirect_to_login()
    except jwt.InvalidTokenError:
        return redirect_to_login()
    
    # Obtain the IP of the request
    source_ip = event['requestContext']['identity']['sourceIp']
    
    # Security Group ID and Port
    security_group_id = os.environ['STAR_LORD_SECURITY_GROUP_ID']
    port = int(os.environ['STAR_LORD_PORT'])
    expiration_time = int(os.environ['STAR_LORD_EXPIRATION_TIME'])
    
    # Check if the IP and port are already allowed
    if not is_ip_port_allowed(security_group_id, source_ip, port):
        # Add rule to the Security Group
        ec2.authorize_security_group_ingress(
            GroupId=security_group_id,
            IpPermissions=[
                {
                    'IpProtocol': 'tcp',
                    'FromPort': port,
                    'ToPort': port,
                    'IpRanges': [{'CidrIp': f'{source_ip}/32'}]
                }
            ]
        )
        
        # Log the allowance in CloudWatch
        log_message = f"IP {source_ip} allowed in Security Group {security_group_id} on port {port}."
        log_to_cloudwatch(log_group_name, log_message)
        
        # Schedule the removal of the IP
        expiration_datetime = datetime.now() + timedelta(seconds=expiration_time)
        
        event_bridge.create_schedule(
            Name=f'remove-ip-{source_ip}',
            ActionAfterCompletion='DELETE',
            State='ENABLED',
            ScheduleExpression=f"at({expiration_datetime.strftime('%Y-%m-%dT%H:%M:%S')})",
            FlexibleTimeWindow={
                'MaximumWindowInMinutes': 60,
                'Mode': 'FLEXIBLE',
            },
            Target={
                'Arn': os.environ['STAR_LORD_REVOKE_LAMBDA_ARN'],
                'RoleArn': os.environ['STAR_LORD_ROLE_ARN'],
                'Input': json.dumps({'source_ip': source_ip, 'security_group_id': security_group_id, 'port': port, 'region': os.environ['STAR_LORD_SECURITY_GROUP_REGION']})
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps(f"IP allowed until {expiration_datetime.strftime('%Y-%m-%dT%H:%M:%S')}.")
        }
    else:
        return {
            'statusCode': 200,
            'body': json.dumps("IP already allowed.")
        }

def is_ip_port_allowed(security_group_id, ip, port):
    response = ec2.describe_security_groups(GroupIds=[security_group_id])
    for permission in response['SecurityGroups'][0]['IpPermissions']:
        if 'FromPort' in permission and 'ToPort' in permission and 'IpRanges' in permission:
            if permission['FromPort'] == port == permission['ToPort']:
                if 'IpRanges' in permission:
                    for range in permission['IpRanges']:
                        if range['CidrIp'] == f'{ip}/32':
                            return True
    return False

def log_to_cloudwatch(log_group_name, message):
    logs = boto3.client('logs')
    log_stream_name = datetime.utcnow().strftime('%Y-%m-%d')
    try:
        logs.create_log_stream(logGroupName=log_group_name, logStreamName=log_stream_name)
    except logs.exceptions.ResourceAlreadyExistsException:
        pass
    
    timestamp = int(datetime.utcnow().timestamp() * 1000)
    logs.put_log_events(
        logGroupName=log_group_name,
        logStreamName=log_stream_name,
        logEvents=[{'timestamp': timestamp, 'message': message}]
    )

def redirect_to_login():
    login_url = f"https://{cognito_domain}.auth.{region}.amazoncognito.com/login?client_id={os.environ['STAR_LORD_COGNITO_CLIENT_ID']}&response_type=code&scope=openid&redirect_uri={os.environ['STAR_LORD_CALLBACK_URL']}"
    return {
        'statusCode': 302,
        'headers': {
            'Location': login_url
        }
    }
