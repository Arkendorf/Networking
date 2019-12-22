local network = require "network"

local server = {}

local address = false

server.load = function()
  network.server.start()
  address = network.server.get_address()
end

server.update = function(dt)
  network.server.update(dt)
end

server.draw = function()
  love.graphics.print(address, 100, 0)
end

server.quit = function()
  network.server.quit()
end

return server
