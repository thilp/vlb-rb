$: << File.expand_path(__dir__ + '/../lib/')

%w( vlinq
    store
    vlisp/reader
    vlisp/translator
    vlisp
).each do |name|
  load File.dirname(__FILE__) + "/vlb/#{name}_test.rb"
end