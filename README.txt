HOW TO RUN:
1. before initializing your terraform file go to line 15 and change the email to your own. (after running terrafrom file you will get a link to validate your email)
2. go to email_notification python folder and change emails in lines 23 and 24 to your emails as well.
3. Initiate the infrastructure by running 'terraform init'
4. Initilize the database by running the postman collections. Make sure to change the apigetway varible to the provisioned APIGetway's url.
5. Access the ec2 instance using SSH. Make sure you create a key with the name "cx-project.pem" attached to your account. download this key and place it in the folder. Then run the following commands there:
"export AWS_ACCESS_KEY_ID=*****************
export AWS_SECRET_ACCESS_KEY=********************
export AWS_REGION=us-east-1
my_ip=$(curl http://checkip.amazonaws.com)
export my_ip
sudo ./apigt"
6. Trigger the assign function by hitting the end point: ec2_public_ip/assign with this body:
{
"date": "year/month/day"
}
7. Run the workload provided, or as instructed in the project report

8.before running the front end grab the new api gateway URL and paste it in the index.html file in the url1 variable 
  at line: 262 paste youe own api gateway url
  at line 530 : change the IP to your vertual machine ip(EC2)




9.to run the front end we need to launch an instance of chrome that disables CORS protocall 
	open run and type 
	chrome.exe --user-data-dir="C://Chrome dev session" --disable-web-security
	on this version of chrome attatch the index.htm file to it using live server




