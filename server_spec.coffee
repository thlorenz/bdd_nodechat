

mem_rss_stub = 10

process_stub = 
  memoryUsage: -> rss: mem_rss_stub

beforeEach ->

  @addMatchers
    hasCode: (code) -> @actual.code is code
    hasRSS: -> @actual.obj.rss is mem_rss_stub
    isEmpty: -> @actual.length is 0

  @fu_stub = 
    gets: {}
    get: (id, callback) -> @gets[id] = callback; undefined

  @res_stub =  
    code: -1, obj: {}
    simpleJSON: (code, obj) -> @code = code; @obj = obj; undefined
    connection:
      remoteAddress: "some address"

  @fu_get = (method, req = { }) -> 
    res = @res_stub 
    @fu_stub.gets["/#{method}"] req, res
    res

  mocked_libs = "./fu": @fu_stub
  require_stub = (library) -> mocked_libs[library] || require library


  @sut = require("./server")
  @sut.init { require: require_stub, process: process_stub }

describe 'given a chat server with no sessios', ->
  describe 'and i ask who is connected', ->
    beforeEach -> @res = @fu_get 'who'
    
    it 'has code 200', -> expect(@res).hasCode 200
    it 'returns no nicks', -> expect(@res.obj.nicks).isEmpty

  describe 'and someone parts', ->
    beforeEach -> @res = @fu_get 'part', { url: 'part?id=1' }

    it 'has code 200', -> expect(@res).hasCode 200
      
  describe 'and someone with empty nick wants to join', ->
    beforeEach -> @res = @fu_get 'join', { url: "/join?nick=" }
    
    it 'has code 400', -> expect(@res).hasCode 400
    it 'warns about bad nick', -> expect(@res.obj.error).toContain "nick"
 
  describe 'when jim joins', ->
    beforeEach -> @res = @fu_get 'join', { url: '/join?nick=jim' } 

    it 'has code 200', -> expect(@res).hasCode 200
    it 'returns session id', -> expect(@res.obj.id).toBeGreaterThan 0
    it 'returns nick: jim', -> expect(@res.obj.nick).toEqual 'jim'
    it 'returns mem usage', -> expect(@res).hasRSS()
