require 'vlb/watcher'
require 'vlb/trust_authority'
require 'vlb/utils'

module VikiLinkBot
  class Shell

    def watch(m, input)
      if input.args.size < 3
        m.reply "Usage : !#{__method__} <description> <canal> <conditions>"
        return
      end
      if m.channel.nil?
        m.reply "Cette commande n'est utilisable que sur un canal."
        return
      end
      return if VikiLinkBot::TrustAuthority.reject?(m, :whitelisted?)

      watch_name = input.args.first

      chan_name = input.args[1]
      unless VikiLinkBot::Watcher.trusted_sources.key?(chan_name)
        m.reply "Désolé, je ne surveille pas le canal #{chan_name}."
        return
      end

      constraints = input.args.drop(2)

      begin
        constraints = self.class.watch_parse(constraints)
      rescue LispParseError => e
        m.reply "Problème lors de l'analyse des contraintes : #{e}"
        return
      end

      log "Creating new watcher with constraints: #{constraints}"

      wid = VikiLinkBot::Watcher.register(
          lambda { |mm, _json| mm.channel.name == chan_name && eval(constraints) },
          lambda do |_, _json|
            m.reply "[watch] #{watch_name} (#{chan_name})"
            m.reply "[watch] par #{_json['user']} sur [[#{_json['title']}]]#{
                    (_json['comment'] && !_json['comment'].empty?) ? ' « ' + _json['comment'] + ' »' : '' }"
          end)

      (@watched ||= {})[watch_name] = wid

      m.reply 'Je vous préviendrai !'
    end

    def unwatch(m, input)
      if input.args.empty?
        m.reply "Usage : !#{__method__} <description>"
        return
      end
      if m.channel.nil?
        m.reply "Cette commande n'est utilisable que sur un canal."
        return
      end
      return if VikiLinkBot::TrustAuthority.reject?(m, :whitelisted?)

      desc = input.args.first
      if @watched.key?(desc)
        VikiLinkBot::Watcher.unregister(@watched[desc])
        m.reply 'Je ne vous préviendrai plus pour cet évènement.'
      else
        m.reply 'Désolé, je ne connais pas cet évènement.'
      end
    end

    def watched(m, _)
      if @watched.empty?
        m.reply 'Rien actuellement.'
      else
        m.reply Utils.join_multiple(@watched.keys.map(&:inspect), ', ', ' et ')
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
      end
    end

    def self.watch_parse(tokens)
      tokens.unshift('(', 'AND')
      tokens << ')'
      watch_parse_expr(tokens)
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
          rescue; false; end
        GENERATED
        g.strip
      elsif t == '#t' || t == '#f'
        (t == '#t').to_s
      elsif t =~ %r{ ^ \d [\d_.]* (?!<\.) $ }x
        t.delete('_')
      else
        raise LispParseError.new("expression incomprise : #{t.inspect}")
      end
    end

  end

  class LispParseError < VikiLinkBot::Utils::VLBError
  end

end