vows = require 'vows'
assert = require 'assert'
should = require 'should'

fu_stub = 
    gets: {}
    get: (id, callback) -> @gets[id] = callback; undefined
    
mocked_libs = "./fu": fu_stub
require_stub = (library) -> mocked_libs[library] || require library

mem_rss_stub = 10
process_stub = 
  memoryUsage: -> rss: mem_rss_stub

stub_res = -> 
  code: -1, obj: {}
  simpleJSON: (code, obj) -> @code = code; @obj = obj; undefined
  connection:
    remoteAddress: "some address"
  
get_sut = -> require("./server")
init = (sut) -> sut.init( { require: require_stub, process: process_stub } ); sut

fu_get = (method, req = { }) -> 
    res = stub_res()
    fu_stub.gets["/#{method}"] req, res
    res

# shared asserts
assertStatus = (code) -> (res) -> res.code.should.equal code
assertRSS = -> (res) -> res.obj.rss.should.equal mem_rss_stub 

vows
  .describe('chat server')
  .addBatch 
    'given a chat server with no sessions':
      topic: -> 
        @sut = get_sut() 
        init @sut

      'and i query /who': 
        topic: -> fu_get 'who'
          
        'returns no nicks': (res) -> res.obj.nicks.should.be.empty
        'returns status 200': assertStatus 200

      'and someone with id 1 /parts': 
        topic: -> fu_get 'part', { url: "/part?id=1" }
          
        'returns status 200': assertStatus 200

      'and someone with empty nick wants to join':
        topic: -> fu_get 'join', { url: "/join?nick=" }
        
        'returns status 400': assertStatus 400
        'warns about bad nick': (res) -> res.obj.error.should.include.string "nick"

  .addBatch 
    'given a chat server when jim joined':
      topic: -> 
        @sut = get_sut() 
        init @sut
        fu_get 'join', { url: '/join?nick=jim' }

      'returns status 200': assertStatus 200
      'returns session id': (res) -> res.obj.id.should.be.above 0
      'returns nick: jim': (res) -> res.obj.nick.should.equal 'jim'
      'returns rss mem usage': assertRSS()

      'and i query /who': 
        topic: -> fu_get 'who' 
          
        'returns status 200': assertStatus 200
        'returns jim only': (res) -> res.obj.nicks.should.have.length(1).and.contain 'jim'

      'and some other jim wants to join':
        topic: -> fu_get 'join', { url: "/join?nick=jim" }
        
        'returns status 400': assertStatus 400
        'warns about nick in use': (res) -> res.obj.error.should.include.string "in use"

      'and jim parts':
        topic: (res) -> fu_get 'part', { url: "/part?id=#{res.obj.id}" }
          
        'returns status 200': assertStatus 200
        'returns rss mem usage': assertRSS()
        "removes jim's session": -> @sut.sessions.should.be.empty
.export module

