import boto3
import json
import os


log_group_name = os.environ['STAR_LORD_LOG_GROUP_NAME']

def lambda_handler(event, context):
    source_ip = event['source_ip']
    security_group_id = event['security_group_id']
    port = event['port']
    region = event['region']

    
    # Remover regra do Security Group
    ec2 = boto3.client('ec2', region_name=region)
    ec2.revoke_security_group_ingress(
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
    
    # Registrar log de remoção no CloudWatch
    log_message = f"IP {source_ip} removido do Security Group {security_group_id} na porta {port}."
    log_to_cloudwatch(log_group_name, log_message)
    
    return {
        'statusCode': 200,
        'body': json.dumps('IP removido do Security Group.')
    }

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
