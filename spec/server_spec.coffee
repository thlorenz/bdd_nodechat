qs = require 'querystring'

mem_rss_stub = 10
port_stub = 1

process_stub = 
  memoryUsage: -> rss: mem_rss_stub
  env: 
    PORT: port_stub

beforeEach ->

  @addMatchers
    hasCode: (code) -> @actual.code is code
    hasRSS: -> @actual.obj.rss is mem_rss_stub
    isEmpty: -> @actual.length == 0
    toContainOnly: (item) -> @actual.length is 1 and @actual[0] is item
  

  @res_stub =  
    code: -1, obj: {}
    simpleJson: (code, obj) -> @code = code; @obj = obj; undefined
    connection:
      remoteAddress: "some address"


  @query_messages = (since, id) ->
    res = @server_get 'recv', { url: "/recv?since=#{since}&id=#{id}" }
    res.obj.messages

  @listens_on = {}
  routes = {}
  
  @server_get = (method, req = { }) -> 
    res = @res_stub 
    routes["/#{method}"] req, res
    res

  @sut = require("./../server")
  @sut.init
    route_static: (file) -> 
    route: (id, callback) -> routes[id] = callback; undefined
    listen: (port, host) => @listens_on = port: port, host: host 
    log:  (msg) -> # don't clutter up the test output
    memoryUsage: -> rss: mem_rss_stub 
    env: PORT: port_stub

describe 'given a chat server with no sessions', ->

  it 'listens on the given port', -> expect(@listens_on.port).toEqual port_stub 
  it 'listens on a host', -> expect(@listens_on.host).not.isEmpty()

  describe 'and i ask who is connected', ->
    beforeEach -> @res = @server_get 'who'
    
    it 'has code 200', -> expect(@res).hasCode 200
    it 'returns no nicks', -> expect(@res.obj.nicks).isEmpty()

  describe 'and someone parts', ->
    beforeEach -> @res = @server_get 'part', { url: 'part?id=1' }

    it 'has code 200', -> expect(@res).hasCode 200
      
  describe 'and someone with empty nick wants to join', ->
    beforeEach -> @res = @server_get 'join', { url: "/join?nick=" }
    
    it 'has code 400', -> expect(@res).hasCode 400
    it 'warns about bad nick', -> expect(@res.obj.error).toContain "nick"
 
  describe 'when jim joins', ->
    beforeEach ->
      @res = @server_get 'join', { url: '/join?nick=jim' } 
      @jims_id = @res.obj.id
      # tests query immediately (unlike real client), so we'l claim server started a bit ealier
      @server_starttime = @res.obj.starttime - 1 

    it 'has code 200', -> expect(@res).hasCode 200
    it 'returns session id', -> expect(@jims_id).toBeGreaterThan 0
    it 'returns nick: jim', -> expect(@res.obj.nick).toEqual 'jim'
    it 'returns mem usage', -> expect(@res).hasRSS()
    it 'returns server starttime', -> expect(@server_starttime).toBeGreaterThan 0

    describe 'and i ask who is connected', ->
      beforeEach -> @res = @server_get 'who'

      it 'has code 200', -> expect(@res).hasCode 200
      it 'returns jim only', -> expect(@res.obj.nicks).toContainOnly 'jim'

    describe 'and i query all messages of jim since startup', ->
      beforeEach -> @messages = @query_messages @server_starttime, @jims_id

      it 'returns 1 message', -> expect(@messages.length).toEqual 1 
      it 'message is from jim', -> expect(@messages[0].nick).toEqual 'jim'
      it 'message tells me that he joined', -> expect(@messages[0].type).toEqual 'join'

    describe 'and some other jim tries to join'  , ->
      beforeEach -> @res = @server_get 'join', { url: '/join?nick=jim' } 

      it 'has code 400', -> expect(@res).hasCode 400
      it 'warns about nick in use', -> expect(@res.obj.error).toContain 'in use'

    describe 'and bob joins as well', ->
      beforeEach -> @res = @server_get 'join', { url: '/join?nick=bob' } 

      it 'returns nick: bob', -> expect(@res.obj.nick).toEqual 'bob'
      
      describe 'and i ask who is connected', ->
        beforeEach -> 
          @res = @server_get 'who'
          @nicks = @res.obj.nicks

        it 'has code 200', -> expect(@res).hasCode 200
        it 'returns exactly 2 nicks', -> expect(@nicks.length).toEqual 2
        it 'returns jim', ->  expect(@nicks).toContain 'jim'
        it 'returns bob', -> expect(@nicks).toContain 'bob'

    describe 'and jim parts', ->
      beforeEach -> @res = @server_get 'part', { url: "/part?id=#{@jims_id}" }

      it 'has code 200', -> expect(@res).hasCode 200
      it 'returns mem usage', -> expect(@res).hasRSS()

      describe 'and i ask who is connected', ->
        beforeEach -> @res = @server_get 'who'
        
        it 'has code 200', -> expect(@res).hasCode 200
        it 'returns no nicks', -> expect(@res.obj.nicks).isEmpty()

      describe 'and i query all messages of jim since startup', ->
        beforeEach -> @messages = @query_messages @server_starttime, @jims_id

        it 'returns 2 messages', -> expect(@messages.length).toEqual 2 
        it 'message tells me that jim joined', -> 
          expect(@messages[1].nick).toEqual 'jim'
          expect(@messages[1].type).toEqual 'part'

    describe 'and someone unknown sends a message', ->
      beforeEach -> @res = @server_get 'send', { url: "/send?id=#{@jims_id + 1}&text=some text" }
      it 'has code 400', -> expect(@res).hasCode 400

    describe 'and jim sends an empty message', ->
      beforeEach -> @res = @server_get 'send', { url: "/send?id=#{@jims_id}&text=" }
      it 'has code 400', -> expect(@res).hasCode 400

    describe 'and jim sends a message', ->
      beforeEach -> 
        @jims_message = "some message"
        @res = @server_get 'send', { url: "/send?id=#{@jims_id}&text=#{qs.escape @jims_message}" }
      it 'has code 200', -> expect(@res).hasCode 200

      describe 'and i query all messages of jim since startup', ->
        beforeEach -> 
          @messages = @query_messages @server_starttime, @jims_id

        it 'returns 2 messages', -> expect(@messages.length).toEqual 2 
        it 'message is from jim', -> expect(@messages[1].nick).toEqual 'jim'
        it 'message tells me that he posted a message', -> expect(@messages[1].type).toEqual 'msg'
        it 'message contains the message text', -> expect(@messages[1].text).toEqual @jims_message 
