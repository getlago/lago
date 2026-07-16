# frozen_string_literal: true

module LagoUtils
  module RubySandbox
    module SafeEnvironment
      ALLOWED_CONSTANTS = [
        :Object,
        :Module,
        :Class,
        :BasicObject,
        :Kernel,
        :NilClass,
        :NIL,
        :Data,
        :TrueClass,
        :TRUE,
        :FalseClass,
        :FALSE,
        :Encoding,
        :Comparable,
        :Enumerable,
        :String,
        :Symbol,
        :Exception,
        :SystemExit,
        :SignalException,
        :Interrupt,
        :StandardError,
        :TypeError,
        :ArgumentError,
        :IndexError,
        :KeyError,
        :RangeError,
        :ScriptError,
        :SyntaxError,
        :LoadError,
        :NotImplementedError,
        :NameError,
        :NoMethodError,
        :RuntimeError,
        :SecurityError,
        :NoMemoryError,
        :EncodingError,
        :SystemCallError,
        :Errno,
        :ZeroDivisionError,
        :FloatDomainError,
        :Numeric,
        :Integer,
        :Fixnum,
        :Float,
        :Bignum,
        :BigDecimal,
        :Array,
        :Hash,
        :Struct,
        :RegexpError,
        :Regexp,
        :MatchData,
        :Range,
        :IOError,
        :EOFError,
        :STDIN,
        :STDOUT,
        :STDERR,
        :Time,
        :Random,
        :Signal,
        :Proc,
        :LocalJumpError,
        :SystemStackError,
        :Method,
        :UnboundMethod,
        :Math,
        :Enumerator,
        :StopIteration,
        :TOPLEVEL_BINDING,
        :Rational,
        :Complex,
        :RUBY_VERSION,
        :RUBY_RELEASE_DATE,
        :RUBY_PLATFORM,
        :RUBY_PATCHLEVEL,
        :RUBY_REVISION,
        :RUBY_DESCRIPTION,
        :RUBY_COPYRIGHT,
        :RUBY_ENGINE,
        :TracePoint,
        :ARGV,
        :Gem,
        :RbConfig,
        :Config,
        :CROSS_COMPILING,
        :Date,
        :ConditionVariable,
        :Queue,
        :SizedQueue,
        :MonitorMixin,
        :Monitor,
        :Exception2MessageMapper,
        :RubyToken,
        :RubyLex,
        :RUBYGEMS_ACTIVATION_MONITOR,
        :JSON
      ].freeze

      KERNEL_S_METHODS = %w[
        Array
        binding
        block_given?
        catch
        chomp
        chomp!
        chop
        chop!
        eval
        fail
        Float
        format
        global_variables
        gsub
        gsub!
        Integer
        iterator?
        lambda
        local_variables
        loop
        method_missing
        proc
        raise
        scan
        split
        sprintf
        String
        sub
        sub!
        throw
      ].freeze

      SYMBOL_S_METHODS = %w[
        all_symbols
      ].freeze

      STRING_S_METHODS = %w[].freeze

      KERNEL_METHODS = %w[
        ==

        ray
        nding
        ock_given?
        tch
        omp
        omp!
        op
        op!
        ass
        clone
        dup
        eql?
        equal?
        eval
        fail
        Float
        format
        freeze
        frozen?
        global_variables
        gsub
        gsub!
        hash
        id
        initialize_copy
        inspect
        instance_eval
        instance_of?
        instance_variables
        instance_variable_get
        instance_variable_set
        instance_variable_defined?
        Integer
        is_a?
        iterator?
        kind_of?
        lambda
        local_variables
        loop
        methods
        method_missing
        nil?
        private_methods
        print
        proc
        protected_methods
        public_methods
        raise
        remove_instance_variable
        respond_to?
        respond_to_missing?
        scan
        send
        singleton_methods
        singleton_method_added
        singleton_method_removed
        singleton_method_undefined
        split
        sprintf
        String
        sub
        sub!
        taint
        tainted?
        throw
        to_a
        to_s
        type
        untaint
        __send__
      ].freeze

      NILCLASS_METHODS = %w[
        &
        inspect
        nil?
        to_a
        to_f
        to_i
        to_s
        ^
        |
      ].freeze

      SYMBOL_METHODS = %w[
        ===
        id2name
        inspect
        to_i
        to_int
        to_s
        to_sym
      ].freeze

      TRUECLASS_METHODS = %w[
        &
        to_s
        ^
        |
      ].freeze

      FALSECLASS_METHODS = %w[
        &
        to_s
        ^
        |
      ].freeze

      ENUMERABLE_METHODS = %w[
        all?
        any?
        collect
        detect
        each_with_index
        entries
        find
        find_all
        grep
        include?
        inject
        map
        max
        member?
        min
        partition
        reject
        select
        sort
        sort_by
        to_a
        zip
      ].freeze

      STRING_METHODS = %w[
        %
        *
        +
        <<
        <=>
        ==
        =~
        capitalize
        capitalize!
        casecmp
        center
        chomp
        chomp!
        chop
        chop!
        concat
        count
        crypt
        delete
        delete!
        downcase
        downcase!
        dump
        each
        each_byte
        each_line
        empty?
        eql?
        gsub
        gsub!
        hash
        hex
        include?
        index
        initialize
        initialize_copy
        insert
        inspect
        intern
        length
        ljust
        lines
        lstrip
        lstrip!
        match
        next
        next!
        oct
        replace
        reverse
        reverse!
        rindex
        rjust
        rstrip
        rstrip!
        scan
        size
        slice
        slice!
        split
        squeeze
        squeeze!
        strip
        strip!
        start_with?
        sub
        sub!
        succ
        succ!
        sum
        swapcase
        swapcase!
        to_f
        to_i
        to_s
        to_str
        to_sym
        tr
        tr!
        tr_s
        tr_s!
        upcase
        upcase!
        upto
        []
        []=
      ].freeze

      SAFE_ENV = <<~STRING.freeze
        def keep_singleton_methods(klass, singleton_methods)
          klass = Object.const_get(klass)
          singleton_methods = singleton_methods.map(&:to_sym)
          undef_methods = (klass.singleton_methods - singleton_methods)

          undef_methods.each do |method|
            klass.singleton_class.send(:undef_method, method)
          end

        end

        def keep_methods(klass, methods)
          klass = Object.const_get(klass)
          methods = methods.map(&:to_sym)
          undef_methods = (klass.methods(false) - methods)
          undef_methods.each do |method|
            klass.send(:undef_method, method)
          end
        end

        def clean_constants
          (Object.constants - #{ALLOWED_CONSTANTS}).each do |const|
            Object.send(:remove_const, const) if defined?(const)
          end
        end

        keep_singleton_methods(:Kernel, #{KERNEL_S_METHODS})
        keep_singleton_methods(:Symbol, #{SYMBOL_S_METHODS})
        keep_singleton_methods(:String, #{STRING_S_METHODS})

        keep_methods(:Kernel, #{KERNEL_METHODS})
        keep_methods(:NilClass, #{NILCLASS_METHODS})
        keep_methods(:TrueClass, #{TRUECLASS_METHODS})
        keep_methods(:FalseClass, #{FALSECLASS_METHODS})
        keep_methods(:Enumerable, #{ENUMERABLE_METHODS})
        keep_methods(:String, #{STRING_METHODS})

        Kernel.class_eval do
          def `(*args)
            raise NoMethodError, "` is unavailable"
          end

          def system(*args)
            raise NoMethodError, "system is unavailable"
          end
        end

        clean_constants
      STRING
    end
  end
end
