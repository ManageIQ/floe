module Floe
  module Boolean
    # for display, it drops the module and displays "Boolean"
    def self.to_s
      "Boolean"
    end
  end
end
TrueClass.include(Floe::Boolean)
FalseClass.include(Floe::Boolean)
