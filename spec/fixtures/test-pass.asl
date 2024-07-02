{
  "Comment": "Testing how pass works with various inputs",
  "StartAt": "Setup1",
  "States": {
    "Setup1": {
      "Comment": "(Implied test) Result => output:Result",
      "Type": "Pass",
      "Next": "UnderTest1",
      "Result": {"color": "test1"}
    },
    "UnderTest1": {
      "Comment": "1: InputPath => output:InputPath applied to input. InputPath changed effective input. No result means use effective input",
      "Type": "Pass",
      "Next": "Verify1",
      "InputPath": "$.color"
    },
    "Verify1": {
      "Type":  "Choice",
      "Choices": [
        {"Variable": "$", "StringEquals": "test1", "Next": "Setup1b"}
      ],
      "Default": "Fail1"
    },
    "Fail1": {
      "Type": "Fail",
      "Error": "Test 1 Failure"
    },
    "Setup1b": {
      "Type": "Pass",
      "Next": "UnderTest1b",
      "Result": {"color":{"passed_in": "test1b"}}
    },
    "UnderTest1b": {
      "Comment": "1b: InputPath, Parameters => output: Parameters (values relative to effective input). No result means use effectyive input. (No remnants of Raw Input or Effective Input in output)",
      "Type": "Pass",
      "Next": "Verify1b",
      "InputPath": "$.color",
      "Parameters": {
        "param1.$": "$.passed_in",
        "param2": "param2"
      }
    },
    "Verify1b": {
      "Type":  "Choice",
      "Choices": [
        {
          "And": [
            {"Variable": "$.param1", "StringEquals": "test1b"},
            {"Variable": "$.param2", "StringEquals": "param2"}
          ], "Next": "Setup1c"
        }
      ],
      "Default": "Fail1b"
    },
    "Fail1b": {
      "Type": "Fail",
      "Error": "Test 1b Failure"
    },

    "Setup1c": {
      "Type": "Pass",
      "Next": "UnderTest1c",
      "Result": {"color":{"passed_in": "test1c"}}
    },
    "UnderTest1c": {
      "Comment": "1c: InputPath, Parameters, ResultPath => output: raw input + Parameters (relative to effective input) at ResultPath",
      "Type": "Pass",
      "Next": "Verify1c",
      "InputPath": "$.color",
      "ResultPath": "$.result",
      "Parameters": {
        "param1.$": "$.passed_in",
        "param2": "param2"
      }
    },
    "Verify1c": {
      "Type":  "Choice",
      "Choices": [
        {
          "And": [
            {"Variable": "$.color.passed_in", "StringEquals": "test1c"},
            {"Variable": "$.result.param1", "StringEquals": "test1c"},
            {"Variable": "$.result.param2", "StringEquals": "param2"}
          ], "Next": "Setup1d"
        }
      ],
      "Default": "Fail1c"
    },
    "Fail1c": {
      "Type": "Fail",
      "Error": "Test 1c Failure"
    },
    "Setup1d": {
      "Type": "Pass",
      "Next": "UnderTest1d",
      "Result": {"color":{"passed_in": "test1d"}}
    },
    "UnderTest1d": {
      "Comment": "1d: ResultPath => output: raw input + raw input at ResultPath",
      "Type": "Pass",
      "Next": "Verify1d",
      "ResultPath": "$.result"
    },
    "Verify1d": {
      "Type":  "Choice",
      "Choices": [
        {
          "And": [
            {"Variable": "$.color.passed_in", "StringEquals": "test1d"},
            {"Variable": "$.result.color.passed_in", "StringEquals": "test1d"}
          ], "Next": "Setup2"
        }
      ],
      "Default": "Fail1d"
    },
    "Fail1d": {
      "Type": "Fail",
      "Error": "Test 1d Failure"
    },

    "Setup2": {
      "Type": "Pass",
      "Next": "UnderTest2",
      "Result": {"color":{"passed_in": "test2"}}
    },
    "UnderTest2": {
      "Comment": "2: InputPath, Result => output: Result. Effective input is ignored, and InputPath has no effect",
      "Type": "Pass",
      "Next": "Verify2",
      "InputPath": "$.color",
      "Result": {
        "key": "result2"
      }
    },
    "Verify2": {
      "Type":  "Choice",
      "Choices": [
        {"And": [
          {"Variable": "$.key", "StringEquals": "result2"}
        ], "Next": "Setup2b"
        }
      ],
      "Default": "Fail2"
    },
    "Fail2": {
      "Type": "Fail",
      "Error": "Test 2 Failure"
    },

    "Setup2b": {
      "Type": "Pass",
      "Next": "UnderTest2b",
      "Result": {"color": {"passed_in": "test2b"}}
    },
    "UnderTest2b": {
      "Comment": "2b: InputPath, Result, ResultPath => output: raw input + Result. Effective input is ignored, so InputPath has no effect.",
      "Type": "Pass",
      "Next": "Verify2b",
      "InputPath": "$.color",
      "Result": "result2b",
      "ResultPath": "$.result"
    },

    "Verify2b": {
      "Comment": "NOTE: $.passed_in failed",
      "Type":  "Choice",
      "Choices": [
        {
          "And": [
            {"Variable": "$.color.passed_in", "StringEquals": "test2b"},
            {"Variable": "$.result", "StringEquals": "result2b"}
          ], "Next": "Setup3"
        }
      ],
      "Default": "Fail2b"
    },
    "Fail2b": {
      "Type": "Fail",
      "Error": "Test 2b Failure"
    },

    "Setup3": {
      "Type": "Pass",
      "Next": "UnderTest3",
      "Result": {"color": {"passed_in": "test3"}}
    },
    "UnderTest3": {
      "Comment": "3: InputPath, Parameters, Result, ResultPath => raw input + Result. Effective input is ignored.",
      "Type": "Pass",
      "Next": "Verify3",
      "InputPath": "$.color",
      "Parameters": {
        "param1.$": "$.passed_in",
        "param2": "param2"
      },
      "Result": "result3",
      "ResultPath": "$.result"
    },
    "Verify3": {
      "Comment": "NOTE: $.passed_in failed",
      "Type":  "Choice",
      "Choices": [
        {
          "And": [
            {"Variable": "$.color.passed_in", "StringEquals": "test3"},
            {"Variable": "$.result", "StringEquals": "result3"}
          ], "Next": "Setup4"
        }
      ],
      "Default": "Fail3"
    },
    "Fail3": {
      "Type": "Fail",
      "Error": "Test 3 Failure"
    },

    "Setup4": {
      "Type": "Pass",
      "Next": "UnderTest4",
      "Result": {"color":{"passed_in": "test4"}}
    },
    "UnderTest4": {
      "Comment": "4: InputPath, Parameters, OutputPath",
      "Type": "Pass",
      "Next": "Verify4",
      "InputPath": "$.color",
      "OutputPath": "$.param1",
      "Parameters": {
        "param1.$": "$.passed_in",
        "param2": "param2"
      }
    },
    "Verify4": {
      "Type":  "Choice",
      "Choices": [
        {
          "And": [
            {"Variable": "$", "StringEquals": "test4"}
          ], "Next": "Setup4b"
        }
      ],
      "Default": "Fail4"
    },
    "Fail4": {
      "Type": "Fail",
      "Error": "Test 4 Failure"
    },

    "Setup4b": {
      "Type": "Pass",
      "Next": "UnderTest4b",
      "Result": {"color":{"passed_in": "test4b"}}
    },
    "UnderTest4b": {
      "Comment": "4b: ResultPath, OutputPath",
      "Type": "Pass",
      "Next": "Verify4b",
      "ResultPath": "$.result",
      "OutputPath": "$.result"
    },
    "Verify4b": {
      "Type":  "Choice",
      "Choices": [
        {
          "And": [
            {"Variable": "$.color.passed_in", "StringEquals": "test4b"}
          ], "Next": "Succeed"
        }
      ],
      "Default": "Fail4b"
    },
    "Fail4b": {
      "Type": "Fail",
      "Error": "Test 4b Failure"
    },

    "Succeed": {
      "Type": "Pass",
      "End": true
    }
  }
}
