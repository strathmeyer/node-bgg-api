Hapi = require 'hapi'
Faketoe = require 'faketoe'
Nipple = require 'nipple'
log = console.log

server = Hapi.createServer 'localhost', 8000,
  cache: 'catbox-redis'

getBggEndpoint = (endpoint, params, next)->
  parser = Faketoe.createParser (err, result)->
    if err
      next err
    else
      next null, result

  log 'making request!'
  url = "http://boardgamegeek.com/xmlapi2/#{endpoint}"
  Nipple.request 'GET', url, params, (err, res)->
    if err
      next err
    else
      res.pipe parser

server.method 'getBggEndpoint', getBggEndpoint,
  cache:
    expiresIn: 10000
  generateKey: (endpoint, params)->
    endpoint + JSON.stringify(params)

bggHandler = (route)->
  (request, reply)->
    server.methods.getBggEndpoint route, {}, (err, result)->
      if err
        reply err
      else
        reply result

bggRoute = (name)->
  server.route
    method: 'GET'
    path: "/#{name}"
    handler: bggHandler name

bggRoute 'hot'

server.start()