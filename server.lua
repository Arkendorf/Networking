local enet = require "enet"
local socket = require "socket"

local server = {}

local updates_per_sec = 30
local rate = 1/updates_per_sec
local tick = 0

local broadcast_port = 11111
local server_port = 11112

local udp = false
local host = false

local password = "doom"

server.load = function()
  udp = socket.udp()
  udp:settimeout(0)
  udp:setsockname("0.0.0.0", broadcast_port)

  -- host = assert(enet.host_create("*:"..tostring(server_port)))
end

server.update = function(dt)
  tick = tick + dt
  if tick > rate then
    tick = tick - rate

    server.listen()
  end
end

server.listen = function()
  local data, ip, port
  repeat
    data, ip, port = udp:receivefrom()
    if data and data == password then
      udp:sendto(server_port, ip, port)
    end
  until not data
end

server.draw = function()
end

server.quit = function()
  udp:close()
  udp = false
end

return server
