$: << File.expand_path(__dir__ + '/../lib/')

%w( utils
    vlinq
    store
    vlisp/reader
    vlisp/translator
    vlisp
    shell-core
    wikilink-resolver
).each do |name|
  load File.dirname(__FILE__) + "/vlb/#{name}_test.rb"
end
