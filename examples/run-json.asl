{
  "Comment": "Various Scenarios",
  "StartAt": "FirstState",
  "States": {
    "FirstState": {
      "Comment": "result?: {value: Hello there}",
      "Type": "Task",
      "Resource": "docker://docker.io/kbrock/error-world:latest",
      "Parameters": {
        "MESSAGE": "{\"value\": \"Hello there\"}"
      },
      "End": true
    }
  }
}
