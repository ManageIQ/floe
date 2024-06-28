module BasicClassAttribute
  # you probably want to use active support class_attribute instead:
  # https://github.com/rails/rails/blob/main/activesupport/lib/active_support/core_ext/module/redefine_method.rb
  # https://github.com/rails/rails/blob/main/activesupport/lib/active_support/core_ext/class/attribute.rb#L89
  def basic_class_attribute(name, default: nil)
    # may need to add line in RUBY to silence redefinition:
    # alias #{name} #{name}
    class_method = <<~RUBY
      def #{name} ; end
      def #{name}=(value)
        define_method(:#{name}) { value } if singleton_class?
        singleton_class.define_method(:#{name}) { value }
        value
      end
    RUBY

    location = caller_locations(1, 1).first
    class_eval(["class << self", class_method, "end"].join(";").tr("\n", ";"), location.path, location.lineno)

    public_send(:"#{name}=", default)
  end
end
