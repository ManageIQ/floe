{
  "Comment": "statelint: Parse error: Field \"param1.$\" of Parameters at \"State Machine.Test2\" is not a JSONPath or intrinsic function expression",
  "StartAt": "Setup",
  "States": {
    "Setup": {
      "Type": "Pass",
      "Next": "Test1",
      "Result": {"num1": 1}
    },
    "Test1": {
      "Comment": "Parameter not a path",
      "Type":  "Pass",
      "Parameters": {
        "param1.$": "nonparam"
      },
      "Next": "Match"
    },
    "Match": {
      "Type": "Pass",
      "End": true
    }
  }
}
