local enet = require "enet"
local socket = require "socket"

local server = {}

-- Set up update rate (we don't want to update every frame, as that's too intensive)
local updates_per_sec = 30
local rate = 1/updates_per_sec
local tick = 0

-- Establish the ports that will be used for the host, and the broadcast
local server_port = 11111
local client_port = 22222

-- Set up our udp socket object
local udp = false

local password = "doom"

server.load = function()
  udp = socket.udp()
  udp:settimeout(0)
  udp:setsockname("0.0.0.0", server_port)
  assert(udp:setoption("broadcast", true))
end

server.update = function(dt)
  tick = tick + dt
  if tick > rate then
    tick = tick - rate

    server.listen()
    server.promote()
  end
end

server.listen = function()
  local data, ip, port
  repeat
    data, ip, port = udp:receivefrom()
    if data == password then
      udp:sendto(host_ip, ip, port)
    end
  until not data
end

server.promote = function()
  udp:sendto(password, "255.255.255.255", client_port)
end

server.draw = function()
end

server.quit = function()
  udp:close()
  udp = false
end

return server
