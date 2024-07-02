{
  "Comment": "Testing Choice failures - sample input: {test: 1}",
  "StartAt": "Setup",
  "States": {
    "Setup": {
      "Comment": "(Implied test) Result => output:Result",
      "Type": "Pass",
      "Next": "ChooseTest",
      "Parameters": {"test.$": "$.test", "num1": 1, "str1": "1", "num2": 1, "str2": "1"}
    },
    "ChooseTest": {
      "Type":  "Choice",
      "Choices": [
        {"Variable": "$.test", "NumericEquals": 1, "Next": "Test1"},
        {"Variable": "$.test", "NumericEquals": 2, "Next": "Test2"},
        {"Variable": "$.test", "NumericEquals": 3, "Next": "Test3"},
        {"Variable": "$.test", "NumericEquals": 4, "Next": "Test4"},
        {"Variable": "$.test", "NumericEquals": 5, "Next": "Test5"},
        {"Variable": "$.test", "NumericEquals": 6, "Next": "Test6"},
        {"Variable": "$.test", "NumericEquals": 7, "Next": "Test7"},
        {"Variable": "$.test", "NumericEquals": 8, "Next": "Test8"},
        {"Variable": "$.test", "NumericEquals": 9, "Next": "Test9"}
      ]
    },
    "Test1": {
      "Comment": "Variable missing -> Invalid path '$.foo'. The choice state's condition path references an invalid value.",
      "Type":  "Choice",
      "Choices": [
        {"Variable": "$.missing", "NumericEquals": 1, "Next": "Match"}
      ]
    },
    "Test2": {
      "Comment": "Variable wrong type -> nothing matched",
      "Type":  "Choice",
      "Choices": [
        {"Variable": "$.str1", "NumericEquals": 1, "Next": "Match"}
      ],
      "Default": "Default"
    },
    "Test3": {
      "Comment": "Target missing -> Invalid path '$.missing': The choice state's condition path references an invalid value.",
      "Type":  "Choice",
      "Choices": [
        {"Variable": "$.num1", "NumericEqualsPath": "$.missing", "Next": "Match"}
      ],
      "Default": "Default"
    },
    "Test4": {
      "Comment": "Target constant wrong type -> compilation fail floe and aws: {Variable: $.num1, NumericEquals: abc, Next: Fail}",
      "Type":  "Pass",
      "Next": "Match"
    },
    "Test5": {
      "Comment": "equals Target wrong type -> Nothing matched",
      "Type":  "Choice",
      "Choices": [
        {"Variable": "$.num1", "NumericEqualsPath": "$.str2", "Next": "Match"}
      ],
      "Default": "Default"
    },
    "Test6": {
      "Comment": "both wrong type -> Nothing matched",
      "Type":  "Choice",
      "Choices": [
        {"Variable": "$.str1", "NumericEqualsPath": "$.str2", "Next": "Match"}
      ],
      "Default": "Default"
    },
    "Test7": {
      "Comment": "equals both wrong type -> Nothing matched",
      "Type":  "Choice",
      "Choices": [
        {"Variable": "$.num1", "StringEqualsPath": "$.num2", "Next": "Match"}
      ],
      "Default": "Default"
    },
    "Test8": {
      "Comment": "GT with src wrong type -> Nothing matched",
      "Type":  "Choice",
      "Choices": [
        {"Variable": "$.num1", "StringGreaterThanPath": "$.str2", "Next": "Match"}
      ],
      "Default": "Default"
    },
    "Test9": {
      "Comment": "GT with both wrong type -> Invalid value provided at path '$.num2'",
      "Type":  "Choice",
      "Choices": [
        {"Variable": "$.num1", "StringGreaterThanPath": "$.num2", "Next": "Match"}
      ],
      "Default": "Default"
    },
    "Match": {
      "Type": "Pass",
      "End": true
    },
    "Default": {
      "Type": "Pass",
      "End": true,
      "Result": "Nothing matched"
    }
  }
}
