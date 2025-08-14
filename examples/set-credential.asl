{
  "Comment": "An example showing how to set a credential.",
  "StartAt": "Login",
  "States": {
    "Login": {
      "Type": "Task",
      "Resource": "docker://docker.io/agrare/echo:latest",
      "Parameters": {
        "ECHO": "TOKEN"
      },
      "ResultPath": "$$.Credentials",
      "ResultSelector": {
        "bearer_token.$": "$.echo"
      },
      "Next": "DoSomething"
    },
    "DoSomething": {
      "Type": "Task",
      "Resource": "docker://docker.io/agrare/hello-world:latest",
      "Credentials": {
        "bearer_token.$": "$.bearer_token"
      },
      "End": true
    }
  }
}
