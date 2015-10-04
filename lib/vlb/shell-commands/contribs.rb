require 'vlb/shell-core/command'
require 'vlb/shell-core/command-dispatchers/cartesian'
require 'vlb/shell-core/command-filters/nonempty-args'

module VikiLinkBot
  class Shell

    COMMANDS[:contribs] = Command.new(Dispatcher::CartesianProduct, Filter::NonemptyArgs) do |m, wiki, username|
      if username =~ / \d{1,3} (?: \.\d{1,3} ){3} /x # IPv4
        editcount = '?'
      else
        json = wiki.api(action: 'query', list: 'users', ususers: username, usprop: 'editcount')
        editcount = begin
          json['query']['users'][0]['editcount'] || raise
        rescue
          m.reply "#{username} n'existe pas sur #{wiki.domain}"
          next
        end
      end
      m.reply "#{editcount} - #{wiki.article_url('Special:Contributions/' + username)}"
    end

    COMMANDS[:contribs].define_singleton_method(:empty_args_action) do |m, _|
      m.reply 'Donnez-moi au moins un pseudonyme ou une IP !'
    end

  end
end
