# frozen_string_literal: true

module Floe
  class Workflow
    module States
      class Parallel < Floe::Workflow::State
        def initialize(*)
          raise NotImplementedError
        end

        def kickoff!(params)
          # params["children"] = children.map {} #guids?
          # maybe move workflow
          child_active_states = children.map { |child| Workflow.create_state(child.name, params["Input"], params["Guid"]}
          params["ChildGuids"] = child_active_states.map { |child| child.last["Guid"] }
          params["ChildStates"] => [] # completed children
          child_active_states + [self.name, params]
        end
      end
    end
  end
end
