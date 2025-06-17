import requests
from requests.exceptions import RequestException, HTTPError, URLRequired
from datetime import datetime, timedelta
import pytz
import json
import os
from google.oauth2 import service_account
from google.auth.transport import requests as Requests
import sys
path = os.path.dirname(os.path.realpath(__file__))

"""
Created by Jeremy Runkle
Last updated 5/9/2024
Requires pytz
Run the following pip installs to get the required packages:
    pip install --upgrade google-auth
    pip install requests
    pip install pytz
Pulls logs from lastpass
Changes should be made to the config file 'rq_chronicle_api_config.txt'
Requires Lastpass customer ID, hash, and Chronicle customer ID
State will be saved to LASTPASS_state.txt
https://support.lastpass.com/s/document-item?language=en_US&bundleId=lastpass&topicId=LastPass/api_event_reporting.html&_LANG=enus
"""

#read from config file
import configparser
config = configparser.ConfigParser()
config.read_file(open(f"{path}/rq_chronicle_api_config.txt", "r"))

#LASTPASS variables
LASTPASS_CUSTOMER_ID = config.get("LastPass", "LASTPASS_CUSTOMER_ID")
LASTPASS_HASH = config.get("LastPass", "LASTPASS_HASH")
LASTPASS_URL = "https://lastpass.com/enterpriseapi.php"

#Chronicle variables
SCOPES = ['https://www.googleapis.com/auth/malachite-ingestion']
SERVICE_ACCOUNT_FILE_PATH = f'{path}/ingestion.json'
if (config.has_option("Chronicle", "SERVICE_ACCOUNT_FILE_PATH")):
    SERVICE_ACCOUNT_FILE_PATH = config.get("Chronicle", "SERVICE_ACCOUNT_FILE_PATH")
LOG_TYPE = 'LASTPASS'   #Insert ingestion label
INGESTION_API_URL = 'https://malachiteingestion-pa.googleapis.com/v2/unstructuredlogentries:batchCreate'   #Reference https://cloud.google.com/chronicle/docs/reference/ingestion-api#regional_endpoints for endpoint
CHRONICLE_CUSTOMER_ID = config.get("Chronicle", "CHRONICLE_CUSTOMER_ID")
CHRONICLE_NAMESPACE = 'IngestionAPI'
LOG_BATCH_SIZE = 100  #DO NOT CHANGE
SIZE_THRESHOLD_BYTES = 950000  #DO NOT CHANGE



#DO NOT CHANGE
def chronicle_ingest(data):   #data is a list of logs
    #set up data
    index = 0
    parsed_data = list(map(lambda i: {"logText": str(json.dumps(i).encode("utf-8"), "utf-8")}, data))
    #set up session
    credentials = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT_FILE_PATH, scopes=SCOPES)
    session = Requests.AuthorizedSession(credentials)
    body = {
        "customer_id": CHRONICLE_CUSTOMER_ID,
        "log_type": LOG_TYPE,
        "namespace": CHRONICLE_NAMESPACE,
        "entries": [],
    }
    #Send payloads less than SIZE_THRESHOLD_BYTES and LOG_BATCH_SIZE
    while index < len(parsed_data):
        next_batch = parsed_data[index:index + LOG_BATCH_SIZE]
        size_of_current_payload = sys.getsizeof(json.dumps(body))
        size_of_next_batch = sys.getsizeof(json.dumps(next_batch))
        #loops over logs individually if too large
        if size_of_next_batch >= SIZE_THRESHOLD_BYTES:
            print(f"Size of next {len(next_batch)} logs too large; looping over logs separately")
            size_of_next_log = sys.getsizeof(json.dumps(parsed_data[index]))
            if size_of_current_payload + size_of_next_log <= SIZE_THRESHOLD_BYTES:
                body["entries"].append(parsed_data[index])
                index += 1
                continue
        elif size_of_current_payload + size_of_next_batch <= SIZE_THRESHOLD_BYTES:
            print(f"Adding batch of {len(next_batch)} log(s) to payload")
            body["entries"].extend(next_batch)
            index += LOG_BATCH_SIZE
            continue
        send_to_chronicle(session, body)
        body["entries"].clear()
    if body["entries"]:
        send_to_chronicle(session, body)

#DO NOT CHANGE
def send_to_chronicle(session, body):
    header = {"Content-Type": "application/json"}
    log_count = len(body["entries"])
    print(f"Attempting to push {log_count} log(s) to Chronicle.")
    response = session.request("POST", INGESTION_API_URL, json=body, headers=header)
    
    try:
        response.raise_for_status()
        # If the Ingestion API execution is successful, it will return an empty
        # dictionary.
        if not response.json():
            print(f"{log_count} log(s) pushed successfully to Chronicle.")
    except Exception as err:
        raise RuntimeError(
            f"Error occurred while pushing logs to Chronicle. "
            f"Status code {response.status_code}. Reason: {response.json()}"
        ) from err

def pullLogs(state):
    body = { 
        "cid": LASTPASS_CUSTOMER_ID,
        "provhash": LASTPASS_HASH,
        "cmd": "reporting",
        "data": {
            "from": state,
            "to": datetime.now(pytz.timezone("US/Eastern")).strftime("%Y-%m-%d %H:%M:%S")
        }
    }

    try:
        response = requests.post(LASTPASS_URL,data=json.dumps(body))
        formatted_response = list(json.loads(response.text)["data"].values())
        if (len(formatted_response) <= 0):
            print("no logs to pull :(")
            sys.exit(-1)
        return (formatted_response)
    except requests.exceptions.RequestException as e:
        raise SystemExit(e)

def getState():
    try:
        with open(f'{path}/{LOG_TYPE}_state.txt', 'r') as state_file:
            state = state_file.read().strip()
            return (str(state))
    except:
        print("No state file found, will pull from one week ago")
        return (datetime.now(pytz.timezone("US/Eastern")) - timedelta(days=7)).strftime("%Y-%m-%d %H:%M:%S")

def saveState(logs):
    timestamp = logs[0]["Time"]
    state = (datetime.strptime(timestamp, "%Y-%m-%d %H:%M:%S") + timedelta(seconds=1)).strftime("%Y-%m-%d %H:%M:%S") #add one second to avoid duplicate logs
    with open(f"{path}/{LOG_TYPE}_state.txt","w") as state_file:
        state_file.write(str(state))

logs = pullLogs(getState())
chronicle_ingest(logs)
saveState(logs)
