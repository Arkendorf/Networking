local network = require "network"

local server = {}

server.load = function()
  network.server.start()
end

server.update = function(dt)
  network.server.update(dt)
end

server.draw = function()
end

server.quit = function()
  network.server.quit()
end

return server
