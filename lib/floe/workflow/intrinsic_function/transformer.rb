# Disable rubocops against the `match` method, since this is a Parslet specific
#   match method and not the typical `Object#match`.
# rubocop:disable Performance/RegexpMatch, Performance/RedundantMatch

require "parslet"

module Floe
  class Workflow
    class IntrinsicFunction
      class Transformer < Parslet::Transform
        OptionalArg = Struct.new(:type)
        VariadicArgs = Struct.new(:type)

        class << self
          def process_args(args, function, signature = nil)
            args = resolve_args(args)
            if signature
              check_arity(args, function, signature)
              check_types(args, function, signature)
            end
            args
          end

          private

          def resolve_args(args)
            if args.nil?
              # 0 args
              []
            elsif args.kind_of?(Array)
              # >1 arg
              args.map { |a| a[:arg] }
            else
              # 1 arg
              [args[:arg]]
            end
          end

          def check_arity(args, function, signature)
            if signature.any?(OptionalArg)
              signature_required = signature.reject { |a| a.kind_of?(OptionalArg) }
              signature_size = (signature_required.size..signature.size)

              raise ArgumentError, "wrong number of arguments to #{function} (given #{args.size}, expected #{signature_size})" unless signature_size.include?(args.size)
            elsif signature.any?(VariadicArgs)
              signature_required = signature.reject { |a| a.kind_of?(VariadicArgs) }

              raise ArgumentError, "wrong number of arguments to #{function} (given #{args.size}, expected at least #{signature_required.size})" unless args.size >= signature_required.size
            else
              raise ArgumentError, "wrong number of arguments to #{function} (given #{args.size}, expected #{signature.size})" unless signature.size == args.size
            end
          end

          def check_types(args, function, signature)
            # Adjust the signature for VariadicArgs to create a copy of the expected type for each given arg
            if signature.last.kind_of?(VariadicArgs)
              signature = signature[0..-2] + Array.new(args.size - signature.size + 1, signature.last.type)
            end

            args.zip(signature).each_with_index do |(arg, type), index|
              type = type.type if type.kind_of?(OptionalArg)

              if type.kind_of?(Array)
                raise ArgumentError, "wrong type for argument #{index + 1} to #{function} (given #{arg.class}, expected one of #{type.join(", ")})" unless type.any? { |t| arg.kind_of?(t) }
              else
                raise ArgumentError, "wrong type for argument #{index + 1} to #{function} (given #{arg.class}, expected #{type})" unless arg.kind_of?(type)
              end
            end
          end
        end

        rule(:null_literal  => simple(:v)) { nil }
        rule(:true_literal  => simple(:v)) { true }
        rule(:false_literal => simple(:v)) { false }

        rule(:string   => simple(:v)) { v.to_s[1..-2] }
        rule(:number   => simple(:v)) { v.match(/[eE.]/) ? Float(v) : Integer(v) }
        rule(:jsonpath => simple(:v)) { Floe::Workflow::Path.value(v.to_s, context, input) }

        STATES_FORMAT_PLACEHOLDER = /(?<!\\)\{\}/.freeze

        rule(:states_format => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.Format", [String, VariadicArgs[[String, TrueClass, FalseClass, Integer, Float, NilClass]]])
          str, *rest = *args

          # TODO: Handle templates with escaped characters, including invalid templates
          #   See https://states-language.net/#intrinsic-functions (number 6)

          expected_args = str.scan(STATES_FORMAT_PLACEHOLDER).size
          actual_args = rest.size
          if expected_args != actual_args
            raise ArgumentError, "number of arguments to States.Format do not match the occurrences of {} (given #{actual_args}, expected #{expected_args})"
          end

          rest.each do |arg|
            str = str.sub(STATES_FORMAT_PLACEHOLDER, arg.nil? ? "null" : arg.to_s)
          end

          # TODO: Handle arguments that have escape characters within them but are interpolated
          str.gsub!("\\'", "'")
          str.gsub!("\\{", "{")
          str.gsub!("\\}", "}")
          str.gsub!("\\\\", "\\")

          str
        end

        rule(:states_array => {:args => subtree(:args)}) do
          Transformer.process_args(args, "States.Array")
        end

        rule(:states_array_partition => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.ArrayPartition", [Array, Integer])
          array, chunk = *args
          raise ArgumentError, "invalid value for argument 2 to States.ArrayPartition (given #{chunk}, expected a positive Integer)" unless chunk.positive?

          array.each_slice(chunk).to_a
        end

        rule(:states_array_contains => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.ArrayContains", [Array, Object])
          array, target = *args

          array.include?(target)
        end

        rule(:states_array_range => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.ArrayRange", [Integer, Integer, Integer])
          range_begin, range_end, increment = *args
          raise ArgumentError, "invalid value for argument 3 to States.ArrayRange (given #{increment}, expected a non-zero Integer)" if increment.zero?

          (range_begin..range_end).step(increment).to_a
        end

        rule(:states_array_get_item => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.ArrayGetItem", [Array, Integer])
          array, index = *args
          raise ArgumentError, "invalid value for argument 2 to States.ArrayGetItem (given #{index}, expected 0 or a positive Integer)" unless index >= 0

          array[index]
        end

        rule(:states_array_length => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.ArrayLength", [Array])
          array = args.first

          array.size
        end

        rule(:states_array_unique => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.ArrayUnique", [Array])
          array = args.first

          array.uniq
        end

        rule(:states_base64_encode => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.Base64Encode", [String])
          str = args.first

          require "base64"
          Base64.strict_encode64(str).force_encoding("UTF-8")
        end

        rule(:states_base64_decode => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.Base64Decode", [String])
          str = args.first

          require "base64"
          begin
            Base64.strict_decode64(str)
          rescue ArgumentError => err
            raise ArgumentError, "invalid value for argument 1 to States.Base64Decode (#{err})"
          end
        end

        rule(:states_hash => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.Hash", [Object, String])
          data, algorithm = *args
          raise NotImplementedError if data.kind_of?(Hash)
          if data.nil?
            raise ArgumentError, "invalid value for argument 1 to States.Hash (given null, expected non-null)"
          end

          algorithms = %w[MD5 SHA-1 SHA-256 SHA-384 SHA-512]
          unless algorithms.include?(algorithm)
            raise ArgumentError, "invalid value for argument 2 to States.Hash (given #{algorithm.inspect}, expected one of #{algorithms.map(&:inspect).join(", ")})"
          end

          require "openssl"
          algorithm = algorithm.sub("-", "")
          data = data.to_json unless data.kind_of?(String)
          OpenSSL::Digest.hexdigest(algorithm, data)
        end

        rule(:states_json_to_string => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.JsonToString", [Object])
          json = args.first
          JSON.generate(json)
        end

        rule(:states_math_random => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.MathRandom", [Integer, Integer, OptionalArg[Integer]])
          range_start, range_end, seed = *args
          unless range_start < range_end
            raise ArgumentError, "invalid values for arguments to States.MathRandom (start must be less than end)"
          end

          seed ||= Random.new_seed
          Random.new(seed).rand(range_start..range_end)
        end

        rule(:states_math_add => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.MathAdd", [Integer, Integer])

          args.sum
        end

        rule(:states_string_split => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.StringSplit", [String, String])
          str, delimeter = *args

          case delimeter.size
          when 0
            str.empty? ? [] : [str]
          when 1
            str.split(delimeter)
          else
            str.split(/[#{Regexp.escape(delimeter)}]+/)
          end
        end

        rule(:states_string_to_json => {:args => subtree(:args)}) do
          args = Transformer.process_args(args(), "States.StringToJson", [String])
          string = args.first
          JSON.parse(string)
        rescue JSON::ParserError => e
          raise ArgumentError, "invalid json: #{e.message}"
        end

        rule(:states_uuid => {:args => subtree(:args)}) do
          Transformer.process_args(args, "States.UUID", [])

          require "securerandom"
          SecureRandom.uuid
        end
      end
    end
  end
end

# rubocop:enable Performance/RegexpMatch, Performance/RedundantMatch
