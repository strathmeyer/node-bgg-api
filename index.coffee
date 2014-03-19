require 'newrelic' if process.env.environment == 'production'
Hapi = require 'hapi'
Nipple = require 'nipple'
querystring = require 'querystring'
{parseString} = require 'xml2js'
{log} = console

cache_cfg = if process.env.REDISTOGO_URL
  rtg = require("url").parse(process.env.REDISTOGO_URL)
  {
    engine: 'catbox-redis'
    host: rtg.hostname
    port: rtg.port
    password: rtg.auth.split(":")[1]
  }
else
  'catbox-redis'

port = process.env.PORT || 5000
log "Listening on " + port
server = Hapi.createServer '0.0.0.0', port,
  cache: cache_cfg
  cors: true

getBggEndpoint = (endpoint, params, next)->
  query = querystring.stringify params
  url = "http://boardgamegeek.com/xmlapi2/#{endpoint}?#{query}"
  opts = {}

  log "making request to: #{url}"
  Nipple.get url, opts, (err, res, payload)->
    return next err if err

    unless /xml/.test(res.headers['content-type'])
      bggError = Hapi.error.notFound('BGG did not return XML. Most likely: Invalid object or user')
      return next(bggError)

    parseString payload, (err, result) ->
      return next err if err

      if result.error
        next Hapi.error.notFound(result.error.$.message)
      else
        next null, result

MINUTE = 60 * 1000
HOUR = 60 * MINUTE
server.method 'getBggEndpoint', getBggEndpoint,
  cache:
    expiresIn: 6 * HOUR
  generateKey: (endpoint, params)->
    endpoint + JSON.stringify(params)

bggRoute = (name)->
  server.route
    method: 'GET'
    path: "/api/v1/#{name}"
    handler: (request, reply)->
      server.methods.getBggEndpoint name, request.query, (err, result)->
        reply if err then err else result

bggRoute route for route in [
  'thing'
  'family'
  'forumlist'
  'forum'
  'thread'
  'user'
  'guild'
  'plays'
  'collection'
  'hot'
  'search'
]

server.start()
