require 'vlb/watcher'
require 'vlb/trust_authority'
require 'vlb/utils'

module VikiLinkBot
  class Shell

    def watch(m, input)
      if input.args.size < 2
        m.reply "Usage : !#{__method__} <nom> <conditions> [<format de notif>]"
        return
      end
      if m.channel.nil?
        m.reply "Cette commande n'est utilisable que sur un canal."
        return
      end
      return if VikiLinkBot::TrustAuthority.reject?(m, :whitelisted?)

      watch_name = input.args.first
      if input.args[1] == '('
        opening, closing = 0, 0
        constraints = input.args.drop(1).take_while do |e|
          case e
            when '('
              opening += 1
              true
            when ')'
              ret = (opening != closing)
              closing += 1
              ret
            else
              true
          end
        end
      else
        constraints = [input.args[1]]
      end
      output_format = input.args[1 + constraints.size] ||
          '[[' + Format(:blue, '${title}') + ']] par ' + Format(:green, '${user}') + ' : « ${comment} »'

      begin
        watch_register(watch_name, '#vikidia-rc-json', m.channel, constraints, output_format)
      rescue LispParseError => e
        m.reply "Problème lors de l'analyse des contraintes : #{e}"
      rescue LispAnticipatedError => e
        m.reply "Format de contraintes valide, mais #{e}"
      else
        m.reply 'Je vous préviendrai !'
      end
    end

    def unwatch(m, input)
      if input.args.empty?
        m.reply "Usage : !#{__method__} <description>+"
        return
      end
      if m.channel.nil?
        m.reply "Cette commande n'est utilisable que sur un canal."
        return
      end
      return if VikiLinkBot::TrustAuthority.reject?(m, :whitelisted?)

      input.args.each do |name|
        if @watched.key?(name)
          VikiLinkBot::Watcher.unregister(@watched.delete(name)[:wid])
          m.reply 'Je ne vous préviendrai plus pour cet évènement.'
        else
          m.reply 'Désolé, je ne connais pas cet évènement.'
        end
      end
    end

    def watched(m, input)
      if input.args.empty?
        if @watched.empty?
          m.reply 'Rien actuellement.'
        else
          m.reply Utils.join_multiple(@watched.keys.map(&:inspect), ', ', ' et ')
        end
      else
        input.args.each do |name|
          if @watched.include?(name)
            w = @watched[name]
            m.reply "#{name} (##{w[:wid]}) : #{w[:constraints]}"
          else
            m.reply "Je ne connais pas #{name.inspect}"
          end
          sleep 1
        end
      end
    end

    def lisp2ruby(m, input)
      begin
        self.class.watch_parse(input.args).split("\n").each do |line|
          m.reply line
          sleep 1
        end
      rescue LispParseError => e
        m.reply "Problème lors de l'analyse des contraintes : #{e}"
      rescue LispAnticipatedError => e
        m.reply "Format de contraintes valide, mais #{e}"
      end
    end

    def watch_register(watch_name, watched_channel, notif_channel, str_constraints, output_format)
      return if watch_name.is_a?(Cinch::Message)  # ignore direct calls from IRC

      @watched ||= {}
      if (old = @watched.delete(watch_name))
        VikiLinkBot::Watcher.unregister(old[:wid])
      end

      constraints = watch_parse(str_constraints)
      log "Creating new watcher with constraints: #{constraints}"
      wid = VikiLinkBot::Watcher.register(
                                    lambda { |m, _json| m.channel.name == watched_channel && eval(constraints) },
                                    lambda do |_, _json|
                                      comment = self.class.sprintf(output_format, _json)
                                      notif_channel.send("[watch] #{watch_name}" + (comment.empty? ? '' : " - #{comment}"))
                                    end
      )
      @watched[watch_name] = {wid: wid, constraints: str_constraints, code: constraints}
    end

    # @return [String]
    def self.sprintf(format, json)
      format.gsub(%r{ \$\{ ([^\}]+) \} }x) { json[$1] || '' }
    end

    def self.watch_parse(tokens)
      tokens.unshift('(', 'AND')
      tokens << ')'
      res = watch_parse_expr(tokens)
      begin
        always = eval(res.gsub(%r{begin;?\s*|;?\s*rescue;false;end}, ''))
        raise LispAnticipatedError.new("expression toujours #{always ? 'vraie' : 'fausse'}")
      rescue NameError
        res
      end
    end

    @lisp_functions = {
        :AND => [:watch_fvar_and, '&&'],
        :OR => [:watch_fvar_or, '||'],
        :+ => [:watch_fvar_plus, '+'],
        :- => [:watch_fvar_minus, '-'],
        :* => [:watch_fvar_mult, '*'],
        :/ => [:watch_fvar_div, '/'],
        :> => [:watch_fbin_gt, '>'],
        :>= => [:watch_fbin_ge, '>='],
        :< => [:watch_fbin_lt, '<'],
        :<= => [:watch_fbin_le, '<='],
        :!= => [:watch_fbin_notequal, '!='],
        '='.to_sym => [:watch_fbin_equal, '=='],
        :EMPTY? => [:watch_fvarmeth_empty, 'empty?'],
        :SIZE => [:watch_fmeth_size, 'size'],
    }

    @lisp_functions.each do |k, v|
      next unless v.is_a?(Array) && v.first.to_s.start_with?('watch_fvar_')
      class_eval <<-RUBY
        def self.#{v.first}(args)
          'begin; ( ' + args.join(' #{v.last} ') + ' );rescue;false;end'
        end
      RUBY
      @lisp_functions[k] = v.first
    end

    @lisp_functions.each do |k, v|
      next unless v.is_a?(Array) && v.first.to_s.start_with?('watch_fbin_')
      class_eval <<-RUBY
        def self.#{v.first}(args)
          'begin; (' + args.to_ary.combination(2).map { |a, b| a + ' #{v.last} ' + b }.join(' ) && ( ') + ' );rescue;false;end'
        end
      RUBY
      @lisp_functions[k] = v.first
    end

    @lisp_functions.each do |k, v|
      next unless v.is_a?(Array) && v.first.to_s.start_with?('watch_fvarmeth_')
      class_eval <<-RUBY
        def self.#{v.first}(args)
          'begin; ( ' + args.map { |e| e + ".#{v.last}" }.join(' ) && ( ') + ' );rescue;false;end'
        end
      RUBY
      @lisp_functions[k] = v.first
    end
    @lisp_functions.each do |k, v|
      next unless v.is_a?(Array) && v.first.to_s.start_with?('watch_fmeth_')
      class_eval <<-RUBY
        def self.#{v.first}(args)
          raise LispParseError.new("#{k} attend 1 argument (reçu " + args.size + ')') unless args.size == 1
          'begin; ( ' + args.first + ".#{v.last} );rescue;false;end"
        end
      RUBY
      @lisp_functions[k] = v.first
    end

    @lisp_functions[:NOT] = :watch_f_not
    def self.watch_f_not(args)
      'begin;( ' + args.map { |e| '!' + e }.join(' ) && ( ') + ' );rescue;false;end'
    end

    @lisp_functions[:IF] = :watch_f_if
    def self.watch_f_if(args)
      raise LispParseError.new("IF attend 3 arguments (reçu #{args.size})") unless args.size == 3
      'begin;( ' + args[0] + ' ? ' + args[1] + ' : ' + args[2] + ' );rescue;false;end'
    end

    def self.watch_parse_expr(tokens)
      t = tokens.shift
      if t == '('
        fun = tokens.shift.upcase.to_sym
        raise LispParseError.new("fonction '#{fun}' inconnue") unless @lisp_functions.key?(fun)
        (args ||= []) << watch_parse_expr(tokens) until tokens.empty? || tokens.first == ')'
        raise LispParseError.new("parenthèse fermante absente pour l'appel à #{fun}") if tokens.empty?
        tokens.shift  # remove our ')'
        method(@lisp_functions[fun]).call(args)
      elsif t =~ %r{ ^ [-a-z_/]+ $ }xi
        '_json' + '[' + t.split('/').map { |k| k.inspect }.join('][') + ']'
      elsif t =~ %r{ ^ ( [-a-z_/]+ ) : ( " .* | / .* | \#[tf] | \w+ ) $ }xi
        key, value = $1, $2
        key_parts = key.gsub(%r{ ^ / | / $ }x, '').split('/')
        raise LispParseError.new(%q{le nom "_json" n'est pas utilisable dans les conditions}) if key_parts.include?('_json')
        lhs = '_json[' + key_parts.map { |k| k.inspect }.join('][') + ']'
        if value.start_with?('/')
          unless value.end_with?('/', '/i')
            raise LispParseError.new("expression rationnelle non fermée pour #{key_parts.join('/')}")
          end
          regex_opts = 0
          if value.end_with?('/i')
            regex_opts |= Regexp::IGNORECASE
            value.chop!
          end
          value = "!(#{lhs} =~ #{Regexp.new(value[1..-2], regex_opts).inspect}).nil?"
        elsif value.start_with?('#')
          value = (value.end_with?('t') ? '' : '!') + lhs
        elsif value =~ %r{ ^ \d [\d_.]* (?<!\.) $ }x
          value.delete!('_')
          value = "#{lhs} == #{value}"
        else
          if value.start_with?('"')
            raise LispParseError.new("chaîne de caractères non fermée pour #{key_parts.join('/')}") unless value.end_with?('"')
            value = "#{lhs} == #{value}"
          else
            value = "#{lhs} == #{value.inspect}"
          end
        end
        g = <<-GENERATED
          begin
            #{value}
          rescue;false;end
        GENERATED
        g.strip
      elsif t == '#t' || t == '#f'
        (t == '#t').to_s
      elsif t =~ %r{ ^ [+-]* \d [\d_.]* (?!<\.) $ }x
        t.delete('_', '+')
      else
        raise LispParseError.new("expression incomprise : #{t.inspect}")
      end
    end

  end

  class LispParseError < VikiLinkBot::Utils::VLBError; end

  class LispAnticipatedError < VikiLinkBot::Utils::VLBError; end

end