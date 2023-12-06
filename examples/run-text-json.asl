{
  "StartAt": "FirstState",
  "States": {
    "FirstState": {
      "Comment": "result: {value: Hello there}",
      "Type": "Task",
      "Resource": "docker://docker.io/kbrock/error-world:latest",
      "Parameters": {
        "MESSAGE": "logging message\n{\"value\": \"Hello there\"}"
      },
      "End": true
    }
  }
}
