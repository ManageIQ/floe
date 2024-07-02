{
  "StartAt": "UnknownImageName",
  "States": {
    "UnknownImageNameRun": {
      "Type": "Task",
      "Resource": "docker://docker.io/kbrock/unknown:latest",
      "Parameters": {
        "ERROR": "failure message"
      },
      "End": true
    }
  }
}
