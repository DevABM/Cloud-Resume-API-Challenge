import boto3
import json
import os

dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    response = table.scan()
    # Ensure response['Items'] is serializable
    items = response['Items']
    
    # Convert sets to lists if necessary
    def convert_sets_to_lists(obj):
        if isinstance(obj, set):
            return list(obj)
        elif isinstance(obj, dict):
            return {k: convert_sets_to_lists(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [convert_sets_to_lists(i) for i in obj]
        return obj
    
    items_serializable = convert_sets_to_lists(items)

    return {
        'statusCode': 200,
        'body': json.dumps(items_serializable, indent=4)  # Pretty-print JSON with indentation
    }
