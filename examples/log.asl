{
  "Comment": "Print log messages",
  "StartAt": "Log Info",
  "States": {
    "Log Info": {
      "Type": "Task",
      "Resource": "floe://log",
      "Parameters": {
        "Level": "INFO",
        "Message": "Hello, Floe!"
      },
      "Next": "Log Debug"
    },
    "Log Debug": {
      "Type": "Task",
      "Resource": "floe://log",
      "Parameters": {
        "Level": "DEBUG",
        "Message": "Hello, Floe!"
      },
      "Next": "Log From Input"
    },
    "Log From Input": {
      "Type": "Task",
      "Resource": "floe://log",
      "Parameters": {
        "Level": "INFO",
        "Message.$": "States.Format('Hello, {}!', $.name)"
      },
      "End": true
    }
  }
}
