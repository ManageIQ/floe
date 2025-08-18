{
  "Comment": "Execute a REST API call",
  "StartAt": "Login",
  "States": {
    "Login": {
      "Type": "Task",
      "Resource": "floe://http",
      "Parameters": {
        "Method": "GET",
        "Url": "http://localhost:3000/api/auth",
        "Headers": {
          "ContentType": "application/json",
          "Authorization.$": "States.Format('Basic {}', States.Base64Encode(States.Format('{}:{}', $$.Credentials.username, $$.Credentials.password)))"
        },
        "Options": {"Encoding": "JSON"}
      },
      "ResultSelector": {"auth_token.$": "$.Body.auth_token"},
      "ResultPath": "$$.Credentials",
      "Next": "List VMs"
    },
    "List VMs": {
      "Type": "Task",
      "Resource": "floe://http",
      "Parameters": {
        "Method": "GET",
        "Url": "http://localhost:3000/api/vms",
        "Headers": {
          "ContentType": "application/json",
          "X-Auth-Token.$": "$$.Credentials.auth_token"
        },
        "Options": {"Encoding": "JSON"}
      },
      "ResultSelector": {
        "Status.$": "$.Status",
        "Resources.$": "$.Body.resources"
      },
      "End": true
    }
  }
}
