{
  "States": {
    "Setup1": {
      "Type": "Pass",
      "Next": "Fail",
      "Result": {"test": "first", "data": "mine"}
    },
    "Fail": {
      "Type": "Fail",
      "Error": "Failed Test",
      "CausePath": "$.test"
   }
  }
}
