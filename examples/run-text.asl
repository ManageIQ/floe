{
  "StartAt": "FirstState",
  "States": {
    "FirstState": {
      "Comment": "result?: {}",
      "Type": "Task",
      "Resource": "docker://docker.io/kbrock/error-world:latest",
      "Parameters": {
        "MESSAGE": "Hello there"
      },
      "End": true
    }
  }
}
