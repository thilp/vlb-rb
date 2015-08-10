require 'vlb/vlisp/utils'
require 'vlb/vlinq'

module VikiLinkBot
  module VLisp

    class TranslationError < VLispError; end

    class UnknownFunctionError < TranslationError
      def initialize(func_name)
        @func_name = func_name
      end
      def message
        "use of unknown function #{@func_name}"
      end
    end
    class InvalidArityError < TranslationError
      def initialize(func_name, arity, got)
        @func_name = func_name
        @arity = arity
        @got = got
      end
      def message
        "#{@func_name} expects #{@arity} arguments but was called with #{@got}"
      end
    end
    class DubiousOccurrenceError < TranslationError; end

    # Wraps the given string into a protective begin/rescue cocoon that returns false when triggered.
    # @api private
    # @param [#to_s] str
    # @return [String]
    def self.cocoon(str)
      'begin;( ' + str.to_s + ' );rescue;false;end'
    end

    # Translates a VLisp expression into the equivalent Ruby code.
    #
    # @param [Token, Array<Token,Array>] expr a VLisp expression, as produced by {::parse_expr}
    # @return [String] Ruby code equivalent to _expr_
    #
    # @raise [UnknownFunctionError] if the VLisp expression contains a call to an unknown function
    # @raise [InvalidArityError] if the VLisp expression contains a call to a function with an inappropriate number of arguments
    def self.translate_expr(expr)
      case expr
        when Token
          case expr.type
            when :truth
              (expr.text == '#t').to_s
            when :decimal, :hexadecimal
              expr.text.delete('_')
            when :string
              expr.text
            when :regex
              m = @lexers[:regex].match(expr.text)
              flags = []
              flags << Regexp::EXTENDED if m[2].include?('x')
              flags << Regexp::IGNORECASE if m[2].include?('i')
              Regexp.new(m[1], flags.reduce(0, :|)).inspect
            when :jsonref
              cocoon(VikiLinkBot::VLINQ.to_s + ".select('#{expr.text}', _json, separator: '/')")
            else
              raise DubiousOccurrenceError.new(expr)
          end
        when Array
          raise DubiousOccurrenceError.new(expr.first) if expr.first.type != :identifier && expr.first.type != :jsonref
          func_name = expr.first.text.upcase.to_sym
          raise UnknownFunctionError.new(func_name) unless @all_functions.key?(func_name)
          args = expr.drop(1).map { |e| translate_expr(e) }
          send(@all_functions[func_name], args)
        else
          raise DubiousOccurrenceError.new(expr)
      end
    end

    # These are variadic VLisp functions that behave exactly as their usual Lisp equivalent.
    # In the following hash, the key is the VLisp function name, and the value is an [A, B] array
    # where A is a unique qualifier used in the generated method name (see @all_functions below)
    # and B is the Ruby operator or method into which the VLisp function will be translated.
    @variadic_operators = {
        :AND => %w(and &&),
        :OR => %w(or ||),
        :+ => %w(plus +),
        :- => %w(minus -),
        :* => %w(mult *),
        :/ => %w(div /),
    }
    # Here we generate the corresponding methods in the current namespace.
    @variadic_operators.each do |vlisp_name, x|
      meth_name, op = x
      class_eval <<-RUBY
        def self.generated_#{meth_name}(args)
          raise InvalidArityError.new('#{vlisp_name}', 1..VikiLinkBot::Utils::Infinity, args.size) if args.size < 1
          cocoon(args.join(' #{op} '))
        end
      RUBY
    end

    # These are similar to @variadic_operators, but they don't have a meaning as strongly defined with more or less than
    # two arguments. We consider that calling them with only one argument is an error, and calling them with more than
    # two arguments is equivalent to the disjunction calling them with of each consecutive pair of two arguments,
    # i.e. (< A B C) is interpreted as (AND (< A B) (< B C)).
    @binary_operators = {
        :> => %w(gt >),
        :>= => %w(ge >=),
        :< => %w(lt <),
        :<= => %w(le <=),
        :!= => %w(notequal !=),
        '='.to_sym => %w(equal ==),
    }
    @binary_operators.each do |vlisp_name, x|
      meth_name, op = x
      class_eval <<-RUBY
        def self.generated_#{meth_name}(args)
          raise InvalidArityError.new('#{vlisp_name}', 2..VikiLinkBot::Utils::Infinity, args.size) if args.size < 2
          cocoon(args.to_ary.each_cons(2).map { |a,b| a + ' #{op} ' + b }.join(' )&&( '))
        end
      RUBY
    end

    # Unary VLisp functions that are mapped to Ruby method calls.
    @methods = {
        EMPTY?: %w(empty empty?),
        SIZE: %w(size size),
    }
    @methods.each do |vlisp_name, x|
      meth_name, ruby_meth = x
      class_eval <<-RUBY
        def self.generated_#{meth_name}(args)
          raise InvalidArityError.new('#{vlisp_name}', 1, args.size) if args.size != 1
          cocoon(args.first + ".#{ruby_meth}")
        end
      RUBY
    end

    # This completes our mapping between VLisp function names and the methods generated above.
    @all_functions = @variadic_operators.merge(@binary_operators).merge(@methods)
    @all_functions.each do |k, v|
      @all_functions[k] = "generated_#{v.first}".to_sym
    end

    @all_functions[:NOT] = :generated_not
    def self.generated_not(args) # @api private
      raise InvalidArityError.new(:NOT, 1..VikiLinkBot::Utils::Infinity, args.size) if args.size < 1
      cocoon(args.map { |e| '!' + e }.join(' )&&( '))
    end

    @all_functions[:IF] = :generated_if
    def self.generated_if(args) # @api private
      raise InvalidArityError.new(:IF, 3, args.size) if args.size != 3
      cocoon(args[0] + ' ? ' + args[1] + ' : ' + args[2])
    end

    @all_functions[:LIKE] = :generated_like
    def self.generated_like(args) # @api private
      raise InvalidArityError.new(:LIKE, 1..VikiLinkBot::Utils::Infinity, args.size) if args.size < 1
      var_name = 'a'
      h = Hash[args.map { |arg| [var_name = var_name.next, arg]}]
      'begin; ' + h.map { |k,v| "#{k} = #{v}"}.join('; ') + '; ' + h.keys.each_cons(2).map do |a, b|
        "#{a}.is_a?(Regexp) ^ #{b}.is_a?(Regexp) ? !(#{a} =~ #{b}).nil? : #{a} === #{b}"
      end.join(' && ') + ' ;rescue;false;end'
    end

  end
end