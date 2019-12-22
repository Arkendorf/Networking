local enet = require "enet"
local socket = require "socket"
local bitser = require "bitser"

local network = {
  server = {},
  client = {},
}

-- Set how often the client and server send and receive information
local updates_per_sec = 30
local rate = 1/updates_per_sec
local tick = 0

-- What port to start to the client and server on by default
-- What port to broadcast too and receive broadcasts from
local broadcast_port = 11111
local default_server_port = 11112
local default_client_port = 11113


-- Set up objects for the udp broadcast socket, the enet host, and the enet server
local udp = false
local host = false
local server = false

-- What the client must send to the broadcast address to be recognized as an instance of this program
local password = "doom"

-- Callback information
-- The functions listed in callback are called when an incoming event matches their key
-- Keys allows users to specify what incoming information will be received, so keys can be stripped when sent and readded when received
-- Strictness determines whether an event is a one-time occurance, or a continuous stream of data
local callbacks = {}
local keys = {}
local strictness = {}

-- The list of queued messages to send during the next update
local queue = {}



-- Creates the initial udp socket and clears callback information
-- Returns true if the udp socket is successfully created, false if otherwise
network.load = function()
  -- Create the socket
  udp = socket.udp()
  if udp then
    -- Clear callback information
    callbacks = {}
    keys = {}
    strictness = {}

    return true
  else
    return false
  end
end

-- Formats information to be sent over the network
-- Combines the event and data and serialize them into a string, using bitser
-- If keys are specified for the event, they are stripped from the data
-- Returns the formatted data
network.format = function(event, data)
  local formatted_data = {}
  if keys[event] then
    -- Strip the keys from the data
    for i, v in ipairs(keys[event]) do
      table.insert(formatted_data, data[v])
    end
  else
    formatted_data = data
  end
  -- Convert the event and data to a string
  return bitser.dumps({event, formatted_data})
end


-- Unformat information
-- Deserialize the string using bitser, and split the information back into an event and data
-- If keys are specified for the event, place them back in the data
-- Returns the unformatted data
network.unformat = function(data)
  -- Deserialize the data
  local event, data = unpack(bitser.loads(data))
  local unformatted_data = {}
  if keys[event] then
    -- Add keys back into the data
    for i, v in ipairs(keys[event]) do
      unformatted_data[v] = data[i]
    end
  else
    unformatted_data = data
  end
  return event, unformatted_data
end

-- Add a callback to an event
-- This function will be called when the associated event is received
-- If the event has no callbacks yet, create a new list of callbacks
network.add_callback = function(event, func)
  if callbacks[event] then
    table.insert(callbacks[event], func)
  else
    callbacks[event] = {func}
  end
end

-- Remove a callback from an event
-- If the event is successfully removed, the function returns true
-- If the event does not exist, or if the callback does not exist, the function returns false
network.remove_callback = function(event, func)
  -- Check if there are callbacks for the specified event
  if callbacks[event] then
    for i, v in ipairs(callbacks[event]) do
      if v == func then
        -- Remove the callback
        table.remove(callbacks[event], i)
        return true
      end
    end
  end
  return false
end

-- Activate all the callbacks associated with the specified event
-- Pass the callbacks the data that is received, and the peer that activated it (if they exist)
-- Returns true if the callback is executed successfully, false if the callback isn't found
network.activate_callback = function(event, data, peer)
  if callbacks[event] then
    -- Iterate through all callbacks associated with the event
    for i, func in ipairs(callbacks[event]) do
      func(data, peer)
    end
    return true
  end
  return false
end

-- Set the keys for an event
-- Pass the function the name of the event, and a table of keys that the data sent with the event will have
-- For example, if you send the data {x = 27, y = 15} along with an event, pass this function the table {"x", "y"}
-- When the data is formatted, it will be converted from {x = 27, y = 15} to {27, 15}
-- When it is received, if the client and server have the same keys, it will be converted back to {x = 27, y = 15}
-- If no table is passed to the function or if the length of the table is less than zero, the keys for that event will be reset
network.set_keys = function(event, key_table)
  if keytable and #key_table > 0 then
    keys[event] = key_table
  else
    keys[event] = nil
  end
end

-- Set the strictness of an event
-- If an event is strict, it will remain in the queue and always be sent
-- If an event is not strict, it may be removed from the queue before being sent
-- Information about specific, one-time occurances should be strict
-- However, information that is constantly being updated and sent should not be, such as coordinates
network.set_strictness = function(event, bool)
  strictness[event] = bool
end

-- Remove all non-strict items from the queue
-- Information in the queue is only sent x times a second, determined by the updates_per_sec variable
-- However, the queue is cleaned every time the server or client is updated, regardless of whether or not they have actually sent out the information
network.clean_queue = function()
  for i = #queue, 1, -1 do
    local v = queue[i]
    -- If the item in the queue is not strict, remove it
    if not v.strict then
      table.remove(queue, i)
    end
  end
end

-- Takes an ip and port as parameters, and returns a formatted string representing an ip address (in the formate 'ip:port')
network.address_string = function(ip, port)
  return tostring(ip)..":"..tostring(port)
end


-- The server's port and address
local server_port = default_server_port
local address = false

-- The list of peers connected to the server
local peers = {}

-- Starts a server
-- Creates a udp socket that listens for broadcasts from clients
-- Creates an enet host that clients can connect to
-- Can optionally specify an ip to host the server on
-- Returns the host if it is successfully created, or false if not
network.server.start = function(port)
  -- Set the port for the server
  server_port = port or default_server_port
  -- Create the udp socket
  if network.load() then
    -- If the udp socket is successfully created, adjust its settings
    udp:settimeout(0)
    if udp:setsockname("0.0.0.0", broadcast_port) then
      -- If the udp socket is successfully bound, create the enet host
      -- Find the address of the host, using another udp socket, then create the host on that address
      address = network.address_string(network.server.get_ip(), server_port)
      host = enet.host_create(address)

      return host
    end
  end
  return false
end

-- Updates the server x times a second based on the updates_per_sec variable
-- Cleans the queue
-- Returns true if the server has been updated, and false if not
network.server.update = function(dt)
  tick = tick + dt
  if tick > rate then
    tick = tick - rate

    network.server.listen()

    network.server.listen_enet()

    network.server.send_queue()

    return true
  end
  network.clean_queue()

  return false
end

-- Quits the server
-- Shuts down the udp socket, as well as the enet host
network.server.quit = function()
  udp:close()
  udp = false

  host:flush()
  host:destroy()
  host = false
end

-- Updates the enet portion of the server
-- Listens for events, and activates the associated callbacks
network.server.listen_enet = function()
  local event = host:service()
  -- Keep looping until no more events register
  while event do
    -- Determine the type of event and activate the proper callback
    if event.type == "connect" then
      -- if a new peer has connected, add them to the list
      table.insert(peers, event.peer)
      network.activate_callback("connect", nil, event.peer)
    elseif event.type == "disconnect" then
      -- If a peer has disconnected, remove them from the list
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

-- Updates the socket portion of the server
-- Receives incoming data, and sends the proper responses
-- If it receives a broadcast from a potential client, its sends them the server's address
network.server.listen = function()
  local data, ip, port = udp:receivefrom()
  -- Keep looping until there is no more data to receive
  while data do
    -- If the potential client has sent the right password, send them the server's address
    if data == password then
      udp:sendto(address, ip, port)
    end
    data, ip, port = udp:receivefrom()
  end
end

-- Returns the list of peers connected to the server
network.server.get_peers = function()
  return peers
end

-- Get the ip address the server is/will be hosted on
-- Uses a udp socket connecting to an arbitrary address (in this case, Google) to find its own address
-- Returns the ip
network.server.get_ip = function()
  local dummy_socket = socket.udp()
  dummy_socket:setpeername("74.125.115.104", 80)
  local ip = dummy_socket:getsockname()
  dummy_socket:close()

  return ip
end

-- Returns the address that the server is hosted on
network.server.get_address = function()
  return address
end

-- Send out all the information in the queue
network.server.send_queue = function()
  for i = #queue, 1, -1 do
    local v = queue[i]
    if v.type == 1 then
      -- Send to one peer
      v.peer:send(v.data)

    elseif v.type == 2 then
      -- Send to all peers
      host:broadcast(v.data)

    elseif v.type == 3 then
      -- Send to all but one peer
      for j, w in ipairs(peers) do
        w:send(v.data)
      end
    end

    table.remove(queue, i)
  end
end

-- Queue an event to be sent to a single peer
network.server.queue = function(event, data, peer)
  table.insert(queue, {type = 1, data = network.format(event, data), strict = strictness[event], peer = peer})
end

-- Queue an event to be sent to all peers
network.server.queue_all = function(event, data)
  table.insert(queue, {type = 2, data = network.format(event, data), strict = strictness[event]})
end

-- Queue an event to be sent to all but one peers
network.server.queue_except = function(event, data)
  table.insert(queue, {type = 3, data = network.format(event, data), strict = strictness[event]})
end


-- The port the client's udp socket is attached to
local client_port = default_client_port

-- A list of valid addresses to connect to on the LAN
local valid_addresses = {}

-- The status of the client
local status = "disconnected"

-- Starts a client
-- Opens a udp socket that broadcasts to the broadcast address, in an attempt to find servers on the LAN
-- Can optionally specify a port to use for the socket
-- Returns true if the client is successfully created, false if otherwise
network.client.start = function(port)
  client_port = port or default_client_port

  -- Set the default status of the client
  status = "disconnected"

  -- Create the udp socket object
  if network.load() then
    -- If the socket is successfully created, adjust its settings
    udp:settimeout(0)
    if udp:setsockname("0.0.0.0", client_port) then
      if udp:setoption("broadcast", true) then
        -- if the settings are successfully set, send a message to the broadcast address
        network.client.promote()
        return true
      end
    end
  end
  return false
end

-- Updates the client x times a second based on the updates_per_sec variable
-- Cleans the queue
-- Returns true if the client has been updated, and false if not
network.client.update = function(dt)
  tick = tick + dt
  if tick > rate then
    tick = tick - rate

    if status == "disconnected" then
      network.client.listen()
    else
      network.client.listen_enet()

      network.client.send_queue()
    end

    return true
  end
  network.clean_queue()

  return false
end

-- Quits the client
-- Shuts down the udp socket if it is still active
-- Shuts down the enet host if it is active
network.client.quit = function()
  if status == "disconnected" then
    network.client.close_udp()
  else
    network.client.close_enet()
  end
end

-- Updates the enet portion of the client
-- Listens for events, and activates the associated callbacks
network.client.listen_enet = function()
  local event = host:service()
  -- Keep looping until no more events register
  while event do
    -- Determine the type of event and activate the proper callback
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

-- Shut down the udp portion of the client
network.client.close_udp = function()
  udp:close()
  udp = false
end

-- Shut down the enet portion of the client
network.client.close_enet = function()
  server:disconnect()
  host:flush()
  host:destroy()
  server = false
  host = false
end

-- Sends the password to the broadcast address on the LAN
-- If a server receives this message, it will send the client the server's address
network.client.promote = function()
  udp:sendto(password, "255.255.255.255", broadcast_port)
end

-- Updates the socket portion of the client
-- Receives incoming data
-- If it receives data from a server, it adds that server's ip to the list of valid ips on the LAN
network.client.listen = function()
  local data, ip, port = udp:receivefrom()
  while data do
    table.insert(valid_addresses, data)
    data, ip, port = udp:receivefrom()
  end
end

-- Clear the list of valid ips, and send out another broadcast
network.client.refresh = function()
  valid_addresses = {}
  network.client.promote()
end

-- Attempt to connect to the address specified
-- Creates the enet portion of the client
-- If successful, the udp socket is shut down
-- Returns true if the connection has begun, false if others
network.client.connect = function(address)
  -- Create an enet peer object to connect to the server with
  host = enet.host_create()
  if host then
    -- If the enet peer has been created properly, attempt to connect to the server
    server = host:connect(address)

    if server then
      status = "connecting"
      network.client.close_udp()
      return true
    end
  end
  return false
end

-- Returns the list of valid addresses on the LAN
network.client.get_addresses = function()
  return valid_addresses
end

-- Returns the client's status
-- 'disconnected' when not connected to an enet server
-- 'connecting'   when trying to connect to a server
-- 'connected'    when connected to a server
-- information should only be sent to the server when the client's status is 'connected'
network.client.get_status = function()
  return status
end

-- Send out all the information in the queue
network.client.send_queue = function()
  for i = #queue, 1, -1 do
    local v = queue[i]
    server:send(v.data)

    table.remove(queue, i)
  end
end

-- Queue an event to be sent to the server
network.client.queue = function(event, data)
  table.insert(queue, {data = network.format(event, data), strict = strictness[event]})
end



return network
