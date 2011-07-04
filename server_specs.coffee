vows = require 'vows'
assert = require 'assert'
should = require 'should'

get_sut = -> require("./server")

fu_stub = 
  gets: {}
  get: (id, callback) -> @gets[id] = callback; undefined
  reset: -> @gets = {} 

fu_get = (method, req = { }) -> 
  res = stub_res()
  fu_stub.gets["/#{method}"] req, res
  res

stub_res = -> 
  code: -1, obj: {}
  simpleJSON: (code, obj) -> @code = code; @obj = obj; undefined
  connection:
    remoteAddress: "some address"

mocked_libs = "./fu": fu_stub
require_stub = (library) -> mocked_libs[library] || require library

mem_rss_stub = 10
process_stub = 
  memoryUsage: -> rss: mem_rss_stub

ctx_main = ->
    
  init = (sut) -> sut.init( { require: require_stub, process: process_stub } ); sut
  
  fu_stub.reset()

  @sut = get_sut() 
  init @sut

ctx_jim_joined = -> 
  fu_get 'join', { url: '/join?nick=jim' } 

# shared asserts
assertStatus = (code) -> (res) -> res.code.should.equal code
assertRSS = -> (res) -> res.obj.rss.should.equal mem_rss_stub 

vows
  .describe('chat server')
  .addBatch 
    'given a chat server with no sessions':
      topic: -> 
        ctx_main()

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
        ctx_main()
        ctx_jim_joined()

      'returns status 200': assertStatus 200
      'returns session id': (res) -> res.obj.id.should.be.above 0
      'returns nick: jim': (res) -> res.obj.nick.should.equal 'jim'
      'returns rss mem usage': assertRSS()

      'and i query /who': 
        topic: -> 
          fu_get 'who' 
          
        'returns status 200': assertStatus 200
        'returns jim only': (res) -> res.obj.nicks.should.have.length(1).and.contain 'jim'

      'and some other jim wants to join':
        topic: -> 
          fu_get 'join', { url: "/join?nick=jim" }
        
        'returns status 400': assertStatus 400
        'warns about nick in use': (res) -> res.obj.error.should.include.string "in use"

  .addBatch 
    'given a chat server when jim joined':
      topic: -> 
        ctx_main()
        ctx_jim_joined()

      'and jim parts':
        topic: (res) -> 
          fu_get 'part', { url: "/part?id=#{res.obj.id}" }
          
        'returns status 200': assertStatus 200
        'returns rss mem usage': assertRSS()

        'and i query /who':
          topic: (res) -> 
            fu_get 'who'

          'returns no nicks': (res) -> res.obj.nicks.should.be.empty

  .addBatch 
    'given a chat server when jim joined':
      topic: -> 
        @sut = ctx_main()
        ctx_jim_joined()

      'and bob joins as well':
        topic: -> 
          fu_get 'join', { url: '/join?nick=bob' }
        
        'returns nick: bob': (res) -> res.obj.nick.should.equal 'bob'
.export module

