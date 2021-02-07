require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'

get '/' do
  headers['Content-Type'] = 'text/html;charset=utf-8'
  erb '<h1>Hello World</h1>'
end
