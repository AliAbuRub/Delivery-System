import json
import boto3

def lambda_handler(event, context):
    method = event['httpMethod']
    
    # this will create dynamodb resource object and 'dynamodb' is resource name
    dynamodb = boto3.resource('dynamodb')
    # this will search for dynamoDB table 
    table = dynamodb.Table("result")

    flag = "Error!"
    if method == "GET":
        all = table.scan()
        all = str(all['Items'])  #retrun list of items
        
        client = boto3.client("ses")
        subject = "Result from the database"

        message = {"Subject": {"Data" : subject},
                    "Body": {"Html": {"Data": all}}}

        response = client.send_email(Source = "ahmedbrimawi@gmail.com",
                Destination = {"ToAddresses": ["ahmedbrimawi@gmail.com"]}, Message = message)
                
        flag = "The email has been send!"
    
    return {
        'statusCode': 200,
        'body': json.dumps(flag)
    }