{
  "Comment": "Testing pass failures - sample input: {test: 1}",
  "StartAt": "Setup",
  "States": {
    "Setup": {
      "Type": "Pass",
      "Next": "ChooseTest",
      "Parameters": {"test.$": "$.test", "num1": 1, "str1": "1"}
    },
    "ChooseTest": {
      "Type":  "Choice",
      "Choices": [
        {"Variable": "$.test", "NumericEquals": 1, "Next": "Test1"}
      ],
      "Default": "Unknown"
    },
    "Test1": {
      "Comment": "Parameter missing -> States.Runtime, cause: The JSONPath '$.missing' specified for the field 'param1.$' could not be found in the input ...",
      "Type":  "Pass",
      "Parameters": {
        "param1.$": "$.missing"
      },
      "Next": "Match"
    },
    "Match": {
      "Type": "Pass",
      "End": true
    },
    "Unknown": {
      "Type": "Fail",
      "Error": "Unknown test number"
    }
  }
}
