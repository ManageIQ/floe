{
  "Comment": "An example of the Amazon States Language using an invalid resource (it must be lower case)",
  "StartAt": "FirstState",
  "States": {
    "FirstState": {
      "Type": "Task",
      "TimeoutSeconds": 20,
      "Resource": "docker://kbrock/HELLO-WORLD:latest",
      "End": true
    }
  }
}
