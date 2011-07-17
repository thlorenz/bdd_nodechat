sys = require "sys"
router = require("./lib/node-router")
server = router.getServer()

chat_server = require "./server"

verbose_route = (req, res) ->
  console.log "Routing request: ", req
  server.get req, res

chat_server.init 

  # States
  env:            process.env
  memoryUsage:    process.memoryUsage

  # Verbs
  log:            sys.puts
  route_static:   router.staticHandler
  route:          verbose_route 
  listen:         server.listen


