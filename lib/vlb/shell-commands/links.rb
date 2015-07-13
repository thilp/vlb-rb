module VikiLinkBot
  class Shell

    {
        aide: 'https://github.com/thilp/vlb-rb'
    }.each do |k, v|
      class_eval <<-RUBY
        def #{k}(m, *_)
          m.reply "#{v}"
        end
      RUBY
    end

  end
end