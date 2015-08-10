require 'vlb/watcher'
require 'vlb/trust_authority'
require 'vlb/utils'
require 'vlb/vlisp'

module VikiLinkBot
  class Shell

    def watch(m, input)
      if input.args.size < 2
        m.reply "Usage : !#{__method__} <nom> \"<condition>\" [<format de notif>]"
        return
      end
      if m.channel.nil?
        m.reply "Cette commande n'est utilisable que sur un canal."
        return
      end
      return if VikiLinkBot::TrustAuthority.reject?(m, :whitelisted?)

      watch_name, constraints, output_format = input.args
      output_format ||=
          '[[' + Format(:blue, '${title}') + ']] par ' + Format(:green, '${user}') + ' : « ${comment} »'

      begin
        watch_register(watch_name, '#vikidia-rc-json', m.channel, constraints, output_format)
      rescue VikiLinkBot::VLisp::ReadError, VikiLinkBot::VLisp::TranslationError => e
        m.reply "Problème lors de l'analyse des contraintes : #{e}"
      rescue VikiLinkBot::VLisp::AnticipatedError => e
        m.reply 'Format de contraintes valide, mais condition toujours ' +
                    (e.is_a?(VikiLinkBot::VLisp::AlwaysTrueError) ? 'vraie' : 'fausse') + ' !'
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
        if (@watched ||= {}).key?(name)
          VikiLinkBot::Watcher.unregister(@watched.delete(name)[:wid])
          m.reply 'Je ne vous préviendrai plus pour cet évènement.'
        else
          m.reply 'Désolé, je ne connais pas cet évènement.'
        end
      end
    end

    def watched(m, input)
      @watched ||= {}
      if input.args.empty?
        if @watched.empty?
          m.reply '∅'
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
        VikiLinkBot::VLisp.lisp2ruby(input.args, enclose_with_and: true).split("\n").each do |line|
          m.reply line
          sleep 1
        end
      rescue VikiLinkBot::VLisp::ReadError => e
        m.reply "Problème lors de l'analyse des contraintes : #{e}"
      rescue VikiLinkBot::VLisp::TranslationError => e
        m.reply "Problème lors de la traduction des contraintes : #{e}"
      end
    end

    def watch_register(watch_name, watched_channel, notif_channel, str_constraints, output_format)
      return if watch_name.is_a?(Cinch::Message)  # ignore direct calls from IRC

      @watched ||= {}
      if (old = @watched.delete(watch_name))
        VikiLinkBot::Watcher.unregister(old[:wid])
      end

      constraints = VikiLinkBot::VLisp.lisp2ruby(str_constraints, enclose_with_and: true, check_anticipated: true)
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

  end
end