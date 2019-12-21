local enet = require "enet"
local socket = require "socket"
local bitser = require "bitser"

local network = {
  server = {},
  client = {},
}

local updates_per_sec = 30
local rate = 1/updates_per_sec
local tick = 0

local broadcast_port = 11111
local server_port = 11112
local client_port = 11113

local udp = false
local host = false
local server = false

local status = "disconnected"

local password = "doom"

local valid_addresses = {}

local peers = {}

local callbacks = {}

network.load = function()
  udp = socket.udp()
  callbacks = {}
end

network.server.start = function()
  network.load()
  udp:settimeout(0)
  udp:setsockname("0.0.0.0", broadcast_port)

  host = assert(enet.host_create("*:"..tostring(server_port)))
end

network.server.update = function(dt)
  tick = tick + dt
  if tick > rate then
    tick = tick - rate

    network.server.listen()

    network.server.update_enet(dt)
  end
end

network.server.quit = function()
  udp:close()
  udp = false

  host:flush()
  host:destroy()
  host = false
end

network.server.update_enet = function(dt)
  local event = host:service()
  while event do
    if event.type == "connect" then
      table.insert(peers, event.peer)
      network.activate_callback("connect", nil, event.peer)
    elseif event.type == "disconnect" then
      for i, v in ipairs(peers) do
        if v == event.peer then
          table.remove(peers, i)
        end
      end
      network.activate_callback("disconnect", nil, event.peer)
    else
      network.activate_callback(network.unformat(event.data), event.peer)
    end

    event = host:service()
  end
end

network.server.listen = function()
  local data, ip, port = udp:receivefrom()
  while data do
    if data == password then
      udp:sendto(server_port, ip, port)
    end
    data, ip, port = udp:receivefrom()
  end
end

network.server.send = function(event, data, peer)
  peer:send(network.format(event, data))
end

network.server.send_all = function(event, data)
  host:broadcast(network.format(event, data))
end

network.server.send_except = function(event, data)
  local formatted_data = network.format(event, data)
  for i, v in ipairs(peers) do
    peer:send(formatted_data)
  end
end



network.client.start = function()
  status = "disconnected"

  udp = socket.udp()
  udp:settimeout(0)
  udp:setsockname("0.0.0.0", client_port)
  assert(udp:setoption("broadcast", true))

  network.client.promote()
end

network.client.update = function(dt)
  tick = tick + dt
  if tick > rate then
    tick = tick - rate

    if status == "disconnected" then
      network.client.listen()
    else
      network.client.update_enet(dt)
    end
  end
end

network.client.quit = function()
  if status == "disconnected" then
    network.client.close_udp()
  else
    network.client.close_enet()
  end
end

network.client.update_enet = function(dt)
  local event = host:service()
  while event do
    if event.type == "connect" then
      status = "connected"
      network.activate_callback("connect")
    elseif event.type == "disconnect" then
      network.activate_callback("disconnect")
    else
      network.activate_callback(network.unformat(event.data))
    end
    event = host:service()
  end
end

network.client.close_udp = function()
  udp:close()
  udp = false
end

network.client.close_enet = function()
  server:disconnect()
  host:flush()
  host:destroy()
  server = false
  host = false
end

network.client.promote = function()
  udp:sendto(password, "255.255.255.255", broadcast_port)
end

network.client.listen = function()
  local data, ip, port = udp:receivefrom()
  while data do
    table.insert(valid_addresses, {ip = ip, port = data})
    data, ip, port = udp:receivefrom()
  end
end

network.client.refresh = function()
  valid_addresses = {}
  network.client.promote()
end

network.client.connect = function(ip, port)
  host = enet.host_create()
  server = host:connect(ip..":"..tostring(port))

  if server then
    status = "connecting"
    network.client.close_udp()
    return true
  else
    return false
  end
end

network.client.get_addresses = function()
  return valid_addresses
end

network.client.get_status = function()
  return status
end

network.client.send = function(event, data)
  server:send(network.format(event, data))
end



network.format = function(event, data)
  return bitser.dumps({event, data})
end

network.unformat = function(data)
  return unpack(bitser.loads(data))
end

network.add_callback = function(event, func)
  if callbacks[event] then
    table.insert(callbacks[event], func)
  else
    callbacks[event] = {func}
  end
end

network.remove_callback = function(event, func)
  if callbacks[event] then
    for i, v in ipairs(callbacks[event]) do
      if v == func then
        table.remove(callbacks[event], i)
        return true
      end
    end
  end
  return false
end

network.activate_callback = function(event, data, peer)
  if callbacks[event] then
    for i, v in ipairs(callbacks[event]) do
      v(data, peer)
    end
  end
end

return network
