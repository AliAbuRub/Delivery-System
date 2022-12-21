import json
import boto3

def lambda_handler(event, context):
    try:
        data = json.loads(event['body'])
        ID = data['ID'] 
        date = data['date'] 
        x = data['x']
        y = data['y']
    except Exception as error:
        print(error)
        
    method = event['httpMethod']

    # this will create dynamodb resource object and 'dynamodb' is resource name
    dynamodb = boto3.resource('dynamodb')
    # this will search for dynamoDB table 
    table = dynamodb.Table("shipment_management")
    
    if method == "GET":
        all = table.scan()
        all = all['Items']  #retrun list of items
        JsonValue = str(all)

    if method == "POST":
        try:
            response = table.get_item(Key={'ID': ID})
            response = response['Item']['ID']
        except Exception as error:
            table.put_item(Item={'ID': ID, "date":date, 'x':x,'y':y})
            JsonValue = "The ID has been added to the database!"
        if response == ID:
                JsonValue = "The ID already in the database!"

    if method == "DELETE":
        response = table.delete_item(
            Key={'ID': ID}
        )
        JsonValue = "Shipment has been deleted"
    
    return {
        'statusCode': 200,
        'body': json.dumps(JsonValue)
    }
  