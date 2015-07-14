require 'vlb/watcher'
require 'vlb/trust_authority'
require 'vlb/utils'

module VikiLinkBot
  class Shell

    def watch(m, tokens)
      if tokens.size < 3
        m.reply "Usage : !#{__method__} <description> <canal> <conditions>"
        return
      end
      if m.channel.nil?
        m.reply "Cette commande n'est utilisable que sur un canal."
        return
      end
      unless VikiLinkBot::TrustAuthority.instance.whitelisted?(m.user, m.channel)
        m.reply 'Désolé, seuls les utilisateurs en liste blanche peuvent utiliser cette commande.'
        return
      end

      watch_name = tokens.shift

      chan_name = tokens.shift
      unless VikiLinkBot::Watcher.trusted_sources.key?(chan_name)
        m.reply "Désolé, je ne surveille pas le canal #{chan_name}."
        return
      end

      constraints = tokens.join(' ').gsub(/([()])/, ' \\1 ').split

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

    def unwatch(m, tokens)
      if tokens.empty?
        m.reply "Usage : !#{__method__} <description>"
        return
      end
      if m.channel.nil?
        m.reply "Cette commande n'est utilisable que sur un canal."
        return
      end
      unless VikiLinkBot::TrustAuthority.instance.whitelisted?(m.user, m.channel)
        m.reply 'Désolé, seuls les utilisateurs en liste blanche peuvent utiliser cette commande.'
        return
      end
      desc = tokens.join(' ')
      if @watched.key?(desc)
        VikiLinkBot::Watcher.unregister(@watched[desc])
        m.reply 'Je ne vous préviendrai plus pour cet évènement.'
      else
        m.reply 'Désolé, je ne connais pas cet évènement.'
      end
    end

    def lisp2ruby(m, tokens)
      begin
        self.class.watch_parse(tokens.join(' ').gsub(/([()])/, ' \\1 ').split).split("\n").each do |line|
          m.reply line
          sleep 1
        end
      rescue LispParseError => e
        m.reply "Problème lors de l'analyse des contraintes : #{e}"
      end
    end

    def self.watch_parse(tokens)
      unless tokens.first == '('
        tokens.unshift('(', 'AND')
        tokens << ')'
      end
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
      elsif t =~ %r{ ^ ( [-a-z_/]+ ) : ( / .* | \#[tf] | \w+ ) $ }xi
        key, value = $1, $2
        key_parts = key.gsub(%r{ ^ / | / $ }x, '').split('/')
        raise LispParseError.new(%q{le nom "_json" n'est pas utilisable dans les conditions}) if key_parts.include?('_json')
        if value.start_with?('/')
          value += ' \\  ' + tokens.shift until tokens.empty? || value.end_with?('/', '/i')
          raise LispParseError.new("expression rationnelle non fermée pour #{key_parts.join('/')}") if tokens.empty?
          regex_opts = Regexp::EXTENDED
          if value.end_with?('/i')
            regex_opts |= Regexp::IGNORECASE
            value.chop!
          end
          value = " =~ #{Regexp.new(value[1..-2], regex_opts).inspect}"
        elsif value.start_with?('#')
          value = " == #{value.end_with?('t')}"
        elsif value =~ /^\d[\d_]*$/
          value = " == #{value}"
        else
          if value.start_with?('"')
            value += ' ' + tokens.shift until tokens.empty? || value.end_with?('"')
            raise LispParseError.new("chaîne de caractères non fermée pour #{key_parts.join('/')}") if tokens.empty?
          end
          value = " == #{value.inspect}"
        end
        g = <<-GENERATED
          begin
            _json#{ '[' + key_parts.map { |k| k.inspect }.join('][') + ']' } #{value}
          rescue
            false
          end
        GENERATED
        g.strip
      elsif t == '#t' || t == '#f'
        (t == '#t').to_s
      elsif t =~ /^\d[\d_]*$/
        t.delete('_')
      else
        raise LispParseError.new("expression incomprise : #{t.inspect}")
      end
    end

  end

  class LispParseError < VikiLinkBot::Utils::VLBError
  end

end