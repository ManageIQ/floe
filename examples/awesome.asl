{
  "Comment": "Directory Listing",
  "StartAt": "a",
  "States": {
    "a":{
      "Type": "Pass",
      "Next": "b"
    },
    "b": {
      "Type": "Wait",
      "Seconds": 1,
      "Next": "ls"
    },
    "ls": {
      "Type": "Task",
      "Resource": "awesome://ls -l Gemfile",
      "Comment": "awesome://ls -l $FILENAME",
      "Next": "c",
      "Parameters": {
        "FILENAME" : "Gemfile"
      }
    },
      "c": {
        "Type": "Succeed"
    }
  }
}
