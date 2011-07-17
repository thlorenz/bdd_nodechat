sys = require "sys"
router = require("./lib/node-router")
server = router.getServer()

chat_server = require "./server"

chat_server.init 

  # States
  env:            process.env
  memoryUsage:    process.memoryUsage

  # Verbs
  log:            sys.puts
  route_static:   router.staticHandler
  route:          server.get
  listen:         server.listen


