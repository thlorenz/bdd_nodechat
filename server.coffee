server = exports


HOST = "localhost"
PORT = 8001

MESSAGE_BACKLOG = 200
SESSION_TIMEOUT = 60 * 1000

sys = require "sys"


get_type = (thing) ->
    if thing == null then return "[object Null]"
    Object.prototype.toString.call(thing)


channel = new ->
  messages = []
  callbacks = []

  @appendMessage = (nick, type, text) ->
    m =
      nick: nick
      type: type
      text: text
      timestamp: (new Date).getTime()
    
    switch type
      when "msg"  then sys.puts "<#{nick}> #{text}"
      when "join" then sys.puts "#{nick} joined"
      when "part" then sys.puts "#{nick} part"

    messages.push m

    callbacks.shift().callback m while callbacks.length > 0

    messages.shift while messages.length > MESSAGE_BACKLOG
  
  @query = (since, callback) -> 
    matching = []
    matching.push message for message in messages when message.timestamp > since

    if matching.length isnt 0
      callback matching 
    else
      callbacks.push timestamp: new Date, callback: callback

  clearCallbacks = () ->
    now = new Date
    while callbacks.length > 0 and now - callbacks[0].timestamp > 30 * 1000
      callbacks.shift().callback [] 

  # Let old callbacks hang around for up to 30 seconds
  setInterval clearCallbacks, 3000

  this

mem = rss: 10

sessions = {} 

createSession = (nick) ->
  if nick.length > 50 then return null
  if /[^\w_\-^!]/.exec nick then return null

  for id of sessions
    if sessions[id]?.nick is nick 
      return null

  session =
    nick :nick
    id : Math.floor(Math.random() * 999999999999).toString()
    timestamp: new Date

    poke: -> session.timestamp = new Date

    destroy: ->
      # channel.appendMessage session.nick "part"
      delete sessions[session.id]

    toString: -> "nick: #{@nick} id: #{@id} timestamp: #{@timestamp}"

  sessions[session.id] = session
  session


server.init = (fake) ->

  require = fake.require || require
  process = fake.process || process

  fu = require "./fu"
  qs = require "querystring"
  url = require "url"

  sessions = {}
  startTime = (new Date).getTime()

  mem = null
  updateMemory = -> mem = process.memoryUsage()

  updateMemory() 

  setInterval updateMemory, 10 * 1000 

  fu.get "/join", (req, res) ->
    nick = qs.parse(url.parse(req.url).query).nick
    if nick?.length is 0
      res.simpleJSON 400, error: "Bad nick"
      return

    session = createSession nick
    if not session? 
      return res.simpleJSON 400, error: "Nick in use"
      

    sys.puts "connection: #{nick}@#{res.connection.remoteAddress}"

    channel.appendMessage session.nick, "join"
    res.simpleJSON 200,
      id: session.id
      nick: session.nick
      rss: mem.rss
      starttime: startTime

  fu.get "/who", (req, res) ->
    nicks = []

    for id of sessions
      nicks.push sessions[id].nick

    res.simpleJSON 200, { nicks: nicks, rss: mem.rss }

  fu.get "/part", (req, res) ->
    id = qs.parse(url.parse(req.url).query).id
    if id && sessions[id]
      sessions[id].destroy()

    res.simpleJSON 200, rss: mem.rss
    

  fu.get "/send", (req, res) ->
    id = qs.parse(url.parse(req.url).query).id

    text = qs.parse(url.parse(req.url).query).text
    unless text 
      return res.simpleJSON 400, error: "No empty message allowed"

    session = sessions[id]
    unless session
      return res.simpleJSON 400, error: "No session for id #{id}"

    session.poke()

    channel.appendMessage session.nick, "msg", text
    res.simpleJSON 200, rss: mem.rss
  undefined
