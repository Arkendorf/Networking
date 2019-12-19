local enet = require "enet"
local socket = require "socket"

local client = {}

-- Set up update rate (we don't want to update every frame, as that's too intensive)
local updates_per_sec = 30
local rate = 1/updates_per_sec
local tick = 0

local client_port = 22222

local udp = false

local password = "doom"

local promotions = {}

client.load = function()
  udp = socket.udp()
  udp:settimeout(0)
  udp:setsockname("0.0.0.0", client_port)
end

client.update = function(dt)
  tick = tick + dt
  if tick > rate then
    tick = tick - rate

    client.listen()
  end
end

client.draw = function()
  for i, v in ipairs(promotions) do
    love.graphics.print(v.ip..":"..tostring(v.port), 0, i*12)
  end
end

client.keypressed = function(key)
  if key == "r" then
    client.refresh()
  end
end

client.quit = function()
  udp:close()
  udp = false
end

client.listen = function()
  local data, ip, port
  repeat
    data, ip, port = udp:receivefrom()
    if data == password then
      if not client.promotion_received(ip, port) then
        table.insert(promotions, {ip = ip, port = port})
      end
    end
  until not data
end

client.promotion_received = function(ip, port)
  for i, v in ipairs(promotions) do
    if v.ip == ip and v.port == port then
      return true
    end
  end
  return false
end

client.refresh = function()
  promotions = {}
end

return client
