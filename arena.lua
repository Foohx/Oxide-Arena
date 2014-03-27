PLUGIN.Title = "Arena"
PLUGIN.Description = "Arena API - Time for arena minigames!"
PLUGIN.Author = "eDeloa, Hatemail & update by Fooxh"
PLUGIN.Version = "1.0.1"

print(PLUGIN.Title .. " (" .. PLUGIN.Version .. ") plugin loading")

function PLUGIN:Init()
    -- Load the config file
    local b, res = config.Read("arena")
    self.Config = res or {}
    if (not b) then
        self:LoadDefaultConfig()
        if (res) then
            config.Save("arena")
        end
    end

    self.ArenaData = {}
    self.ArenaData.Games = {}
    self.ArenaData.CurrentGame = nil
    self.ArenaData.Users = {}
    self.ArenaData.UserCount = 0
    self.ArenaData.IsOpen = false
    self.ArenaData.HasStarted = false
    self.ArenaData.HasEnded = false

    -- create ArenaData.InventoryToClean
    self.ArenaDataFile_InventoryToClean = util.GetDatafile( "arena_inventory" )
    local txt = self.ArenaDataFile_InventoryToClean:GetText()
    if (txt ~= "") then
        self.ArenaData.InventoryToClean = json.decode( txt )
    else
        self.ArenaData.InventoryToClean = {}
    end 
end

function PLUGIN:PostInit()
    flags_plugin = plugins.Find("flags")
    if (not flags_plugin) then
        error("You do not have the Flags plugin installed! Check here: http://forum.rustoxide.com/resources/flags.155")
        return
    end

    spawns_plugin = plugins.Find("spawns")
    if (not spawns_plugin) then
        error("You do not have the Spawns plugin installed! Check here: http://forum.rustoxide.com/resources/spawns.233")
        return
    end
    arena_loaded = true

    if (not arena_loaded) then
        error("This plugin requires the Flags and Spawns plugins to be installed!")
        return
    end
    flags_plugin:AddFlagsChatCommand(self, "arena_game", {"arena_admin"}, self.cmdArenaGame)
    flags_plugin:AddFlagsChatCommand(self, "arena_open", {"arena_admin"}, self.cmdArenaOpen)
    flags_plugin:AddFlagsChatCommand(self, "arena_close", {"arena_admin"}, self.cmdArenaClose)
    flags_plugin:AddFlagsChatCommand(self, "arena_start", {"arena_admin"}, self.cmdArenaStart)
    flags_plugin:AddFlagsChatCommand(self, "arena_end", {"arena_admin"}, self.cmdArenaEnd)
    flags_plugin:AddFlagsChatCommand(self, "arena_spawnfile", {"arena_admin"}, self.cmdArenaSpawnFile)

    flags_plugin:AddFlagsChatCommand(self, "arena_list", {}, self.cmdArenaList)
    flags_plugin:AddFlagsChatCommand(self, "arena_join", {}, self.cmdArenaJoin)
    flags_plugin:AddFlagsChatCommand(self, "arena_leave", {}, self.cmdArenaLeave)
    self:LoadArenaSpawnFile(self.Config.SpawnFileName)
end

-- *******************************************
-- CHAT COMMANDS
-- *******************************************
function PLUGIN:cmdArenaList(netuser, cmd, args)
    rust.SendChatToUser(netuser, self.Config.ChatName, "Game#         Arena Game")
    rust.SendChatToUser(netuser, self.Config.ChatName, "---------------------------")
    for i = 1, #self.ArenaData.Games do
        rust.SendChatToUser(netuser, self.Config.ChatName, "#" .. i .. "                  " .. self.ArenaData.Games[i].GameName)
    end
end

function PLUGIN:cmdArenaGame(netuser, cmd, args)
    if (not args[1]) then
        rust.Notice(netuser, "Syntax: /arena_game {gameID}")
        return
    end

    local gameID = tonumber(args[1])
    local success, err = self:SelectArenaGame(gameID)
    if (not success) then
        rust.Notice(netuser, err)
        return
    end

    rust.Notice(netuser, self.ArenaData.Games[self.ArenaData.CurrentGame].GameName .. " is now the next Arena game.")
end

function PLUGIN:cmdArenaOpen(netuser, cmd, args)
    local success, err = self:OpenArena()
    if (not success) then
        rust.Notice(netuser, err)
        return
    end
end

function PLUGIN:cmdArenaClose(netuser, cmd, args)
    local success, err = self:CloseArena()
    if (not success) then
        rust.Notice(netuser, err)
        return
    end
end

function PLUGIN:cmdArenaStart(netuser, cmd, args)
    local success, err = self:StartArena()
    if (not success) then
        rust.Notice(netuser, err)
        return
    end
end

function PLUGIN:cmdArenaEnd(netuser, cmd, args)
    local success, err = self:EndArena()
    if (not success) then
        rust.Notice(netuser, err)
        return
    end
end

function PLUGIN:cmdArenaSpawnFile(netuser, cmd, args)
    if (not args[1]) then
        rust.Notice(netuser, "Syntax: /arena_spawnfile {filename}")
        return
    end

    local success, err = self:LoadArenaSpawnFile(args[1])
    if (not success) then
        rust.Notice(netuser, err)
        return
    end
  
    rust.Notice(netuser, "Successfully loaded the spawn file.")
end

function PLUGIN:cmdArenaJoin(netuser, cmd, args)
    local success, err = self:JoinArena(netuser)
    if (not success) then
        rust.Notice(netuser, err)
        return
    end

    rust.Notice(netuser, "Successfully joined the Arena.")
end

function PLUGIN:cmdArenaLeave(netuser, cmd, args)
    local success, err = self:LeaveArena(netuser)
    if (not success) then
        rust.Notice(netuser, err)
        return
    end

    rust.Notice(netuser, "Successfully left the Arena.")
end

--[[function PLUGIN:cmdQuickSetup(netuser, cmd, args)
  self:LoadArenaSpawnFile("arena1")
  self:SelectArenaGame(1)
  self:OpenArena()
  self:JoinArena(netuser)
  self:StartArena()
end]]--

-- *******************************************
-- API COMMANDS
-- *******************************************
function PLUGIN:RegisterArenaGame(gamename)
    table.insert(self.ArenaData.Games, {GameName = gamename})
    return #(self.ArenaData.Games)
end

-- *******************************************
-- FORWARDED HOOKS
-- *******************************************
--[[
plugins.Call("CanSelectArenaGame", gameid)
plugins.Call("OnSelectArenaGamePost", gameid)

plugins.Call("CanArenaOpen")
plugins.Call("OnArenaOpenPost")

plugins.Call("CanArenaClose")
plugins.Call("OnArenaClosePost")

plugins.Call("CanArenaStart")
plugins.Call("OnArenaStartPost")

plugins.Call("CanArenaEnd")
plugins.Call("OnArenaEndPre")
plugins.Call("OnArenaEndPost")

plugins.Call("CanArenaJoin", netuser)
plugins.Call("OnArenaJoinPost", netuser)

plugins.Call("OnArenaLeavePost", netuser)

plugins.Call("OnArenaSpawnPost", playerclient, usecamp, avatar)
]]--

-- *******************************************
-- HOOK FUNCTIONS
-- *******************************************
function PLUGIN:OnSpawnPlayer(playerclient, usecamp, avatar)
  if (not arena_loaded) then
    error("This plugin requires the Flags and Spawns plugins to be installed!")
    return
  end

  if (self.ArenaData.HasStarted and self:IsPlaying(playerclient.netUser)) then
    timer.Once(0.2, function() self:TeleportPlayerToArena(playerclient.netUser) plugins.Call("OnArenaSpawnPost", playerclient, usecamp, avatar) end)
  --elseif (self:HasLeft(playerclient.netUser)) then
  --  timer.Once(0.1, function() self:TeleportPlayerHome(playerclient.netUser) self.ArenaData.Users[rust.GetUserID(netuser)] = nil end)
  --  timer.Once(0.1, function() plugins.Call("OnArenaLeavePost", playerclient.netUser) end)
  end

    local netuser = playerclient.netUser
    if ( self.ArenaData.InventoryToClean[rust.GetUserID(netuser)] ~= nil) then
        timer.Once( 5,
        function()
            self.ArenaData.InventoryToClean[rust.GetUserID(playerclient.netUser)] = nil
            local inv = rust.GetInventory(playerclient.netUser)
            inv:Clear()
            self:KillPlayer( playerclient.netUser )
        end)
    end
end

function PLUGIN:OnUserConnect(netuser)
    if (not arena_loaded) then
        error("This plugin requires the Flags and Spawns plugins to be installed!")
        return
    end

    if (flags_plugin:HasActualFlag(netuser, "leftarena")) then
        timer.Once(0, function() self:KillPlayer(netuser) end)
        flags_plugin:RemoveFlag(netuser, "leftarena")
    end
end

function PLUGIN:OnUserDisconnect(networkplayer)
  if (not arena_loaded) then
    error("This plugin requires the Flags and Spawns plugins to be installed!")
    return
  end

  local netuser = networkplayer:GetLocalData()
  if (not netuser or netuser:GetType().Name ~= "NetUser") then
    return
  end

  if (self:IsPlaying(netuser)) then
    flags_plugin:AddFlag(netuser, "leftarena")
    self:LeaveArena(netuser)
  end
end

function PLUGIN:SendHelpText(netuser)
if (not arena_loaded) then
    error("This plugin requires the Flags and Spawns plugins to be installed!")
    return
  end

  rust.SendChatToUser(netuser, self.Config.ChatName, "Use /arena_list to list all Arena games.")
  rust.SendChatToUser(netuser, self.Config.ChatName, "Use /arena_join to join the Arena when it is open.")
  rust.SendChatToUser(netuser, self.Config.ChatName, "Use /arena_leave to leave the Arena.")

  if (flags_plugin:HasFlag(netuser, "arena_admin")) then
    rust.SendChatToUser(netuser, self.Config.ChatName, "Use /arena_spawnfile {filename} to load a spawnfile.")
    rust.SendChatToUser(netuser, self.Config.ChatName, "Use /arena_game {gameID} to select an Arena game.")
    rust.SendChatToUser(netuser, self.Config.ChatName, "Use /arena_open to open the Arena.")
    rust.SendChatToUser(netuser, self.Config.ChatName, "Use /arena_close to close the Arena entrance.")
    rust.SendChatToUser(netuser, self.Config.ChatName, "Use /arena_start to start the Arena game.")
    rust.SendChatToUser(netuser, self.Config.ChatName, "Use /arena_end to end the Arena game.")
  end
end

function PLUGIN:OnSave()
  if (not arena_loaded) then
    error("This plugin requires the Flags and Spawns plugins to be installed!")
    return
  end
end

-- *******************************************
-- MAIN FUNCTIONS
-- *******************************************
function PLUGIN:LoadArenaSpawnFile(filename)
  local fileID, err = spawns_plugin:LoadSpawnFile(filename)
  if (not fileID) then
    return false, err
  end

  if (self.ArenaData.SpawnsFileID) then
    spawns_plugin:UnloadSpawnFile(self.ArenaData.SpawnsFileID)
  end

  self.ArenaData.SpawnsFileID = fileID
  self.ArenaData.SpawnCount = spawns_plugin:GetSpawnPointCount(fileID)
  return true
end

function PLUGIN:SelectArenaGame(gameid)
  if (gameid < 1 or gameid > #(self.ArenaData.Games)) then
    return false, "Invalid gameID."
  end

  if (self.ArenaData.IsOpen or self.ArenaData.HasStarted) then
    return false, "The Arena needs to be closed and ended before selecting a new game."
  end

  local success, err = plugins.Call("CanSelectArenaGame", gameid)
  if (not success) then
    return false, err
  end

  self.ArenaData.CurrentGame = gameid
  plugins.Call("OnSelectArenaGamePost", gameid)
  return true
end

function PLUGIN:OpenArena()
  if (not self.ArenaData.CurrentGame) then
    return false, "An Arena game must first be chosen."
  elseif (not self.ArenaData.SpawnsFileID) then
    return false, "A spawn file must first be loaded."
  elseif (self.ArenaData.IsOpen) then
    return false, "The Arena is already open."
  end

  local success, err = plugins.Call("CanArenaOpen")
  if (not success) then
    return false, err
  end

  self.ArenaData.IsOpen = true
  BroadcastNotice("The Arena is now open for: " .. self.ArenaData.Games[self.ArenaData.CurrentGame].GameName .. "!  Type /arena_join to join!", 20)
  plugins.Call("OnArenaOpenPost")
  return true
end

function PLUGIN:CloseArena()
  if (not self.ArenaData.IsOpen) then
    return false, "The Arena is already closed."
  end

  local success, err = plugins.Call("CanArenaClose")
  if (not success) then
    return false, err
  end

  self.ArenaData.IsOpen = false

  BroadcastNotice("The Arena entrance is now closed!")
  plugins.Call("OnArenaClosePost")
  return true
end

function PLUGIN:StartArena()
  if (not self.ArenaData.CurrentGame) then
    return false, "An Arena game must first be chosen."
  elseif (not self.ArenaData.SpawnsFileID) then
    return false, "A spawn file must first be loaded."
  elseif (self.ArenaData.HasStarted) then
    return false, "An Arena game has already started."
  end

  local success, err = plugins.Call("CanArenaStart")
  print(err)
  if (not success) then
    return false, "Selected minigame is not allowing Arena to start."
  end

  plugins.Call("OnArenaStartPre")

  BroadcastNotice("Arena: " .. self.ArenaData.Games[self.ArenaData.CurrentGame].GameName .. " is about to begin!")
  self.ArenaData.HasStarted = true
  self.ArenaData.HasEnded = false

  timer.Once(5, function() self:SaveAllHomeLocations() self:TeleportAllPlayersToArena() plugins.Call("OnArenaStartPost") end)
  return true
end

function PLUGIN:EndArena()
  if (self.ArenaData.HasEnded or ((not self.ArenaData.HasStarted) and (not self.ArenaData.IsOpen))) then
    return false, "An Arena game is not underway."
  end

  local success, err = plugins.Call("CanArenaEnd")
  if (not success) then
    return false, err
  end

  self.ArenaData.IsOpen = false
  self.ArenaData.HasEnded = true

  plugins.Call("OnArenaEndPre")

  -- Kick everyone out
  local netusers = rust.GetAllNetUsers()
  for k,netuser in pairs(netusers) do
    if (self:IsPlaying(netuser)) then
      self:LeaveArena(netuser)
    end
  end

  BroadcastNotice("Arena: " .. self.ArenaData.Games[self.ArenaData.CurrentGame].GameName .. " is now over!")
  self.ArenaData.HasStarted = false
  plugins.Call("OnArenaEndPost")
  return true
end

function PLUGIN:JoinArena(netuser)
  if (not self.ArenaData.IsOpen) then
    return false, "The Arena is currently closed."
  elseif (self:IsPlaying(netuser)) then
    return false, "You are already in the Arena."
  end

  local success, err = plugins.Call("CanArenaJoin", netuser)
  if (not success) then
    return false, err
  end

  self.ArenaData.Users[rust.GetUserID(netuser)] = {}
  self.ArenaData.Users[rust.GetUserID(netuser)].HasJoined = true
  self.ArenaData.UserCount = self.ArenaData.UserCount + 1

  if (self.ArenaData.HasStarted) then
    self:SaveHomeLocation(netuser)
  end
  
  rust.BroadcastChat(self.Config.ChatName, netuser.displayName .. " has joined the Arena!  (Total Players: " .. self.ArenaData.UserCount .. ")")
  plugins.Call("OnArenaJoinPost", netuser)
  return true
end

function PLUGIN:LeaveArena(netuser)
  if (not self:IsPlaying(netuser)) then
    return false, "You are not currently in the Arena."
  end

  self.ArenaData.UserCount = self.ArenaData.UserCount - 1

  if (not self.ArenaData.HasEnded) then
    rust.BroadcastChat(self.Config.ChatName, netuser.displayName .. " has left the Arena!  (Total Players: " .. self.ArenaData.UserCount .. ")")
  end

  if (self.ArenaData.HasStarted) then
    self:TeleportPlayerHome(netuser)
    self.ArenaData.Users[rust.GetUserID(netuser)] = nil
    -- RPC Error Patch
    self.ArenaData.InventoryToClean[rust.GetUserID(netuser)] = 1
    -- -----
    --plugins.Call("OnArenaLeavePost", rust.GetUserID(netuser)) -- bypass RPC errors when any user leave an arena game
  else
    self.ArenaData.Users[rust.GetUserID(netuser)] = nil
  end
  print("DONE A !")
  return true
end

-- *******************************************
-- HELPER FUNCTIONS
-- *******************************************
function PLUGIN:LoadDefaultConfig()
  -- Set default configuration settings
  self.Config.ChatName = "Arena"
  self.Config.SpawnFileName = ""
end

function PLUGIN:IsPlaying(netuser)
  local userID = rust.GetUserID(netuser)
  return (self.ArenaData.Users[userID] and self.ArenaData.Users[userID].HasJoined)
end

function PLUGIN:SaveAllHomeLocations()
  local netusers = rust.GetAllNetUsers()
  for k,netuser in pairs(netusers) do
    if (self:IsPlaying(netuser)) then
      self:SaveHomeLocation(netuser)
    end
  end
end

function PLUGIN:SaveHomeLocation(netuser)
  local userID = rust.GetUserID(netuser)
  local homePos = netuser.playerClient.lastKnownPosition
  self.ArenaData.Users[userID].HomeCoords = {}
  self.ArenaData.Users[userID].HomeCoords.x = homePos.x
  self.ArenaData.Users[userID].HomeCoords.y = homePos.y
  self.ArenaData.Users[userID].HomeCoords.z = homePos.z
end

function PLUGIN:KillAllPlayers()
  local netusers = rust.GetAllNetUsers()
  for k,netuser in pairs(netusers) do
    if (self:IsPlaying(netuser)) then
      self:KillPlayer(netuser)
    end
  end
end

function PLUGIN:KillPlayer(netuser)
  local coords = netuser.playerClient.lastKnownPosition
  coords.x = 7696
  coords.y = 9
  coords.z = 3443
  rust.ServerManagement():TeleportPlayer(netuser.playerClient.netPlayer, coords)
end

function PLUGIN:TeleportAllPlayersToArena()
  local netusers = rust.GetAllNetUsers()
  for k,netuser in pairs(netusers) do
    if (self:IsPlaying(netuser)) then
      self:TeleportPlayerToArena(netuser)
    end
  end
end

function PLUGIN:TeleportPlayerToArena(netuser)
  local spawnIndex = math.random(self.ArenaData.SpawnCount)
  local spawnPoint = spawns_plugin:GetSpawnPointFromIndex(self.ArenaData.SpawnsFileID, spawnIndex)

  local coords = netuser.playerClient.lastKnownPosition
  coords.x = spawnPoint.x
  coords.y = spawnPoint.y
  coords.z = spawnPoint.z
  rust.ServerManagement():TeleportPlayer(netuser.playerClient.netPlayer, coords)
end

function PLUGIN:TeleportPlayerHome(netuser)
  local userID = rust.GetUserID(netuser)
  if (self.ArenaData.Users[userID] and self.ArenaData.Users[userID].HomeCoords) then
    local coords = netuser.playerClient.lastKnownPosition
    coords.x = self.ArenaData.Users[userID].HomeCoords.x
    coords.y = self.ArenaData.Users[userID].HomeCoords.y
    coords.z = self.ArenaData.Users[userID].HomeCoords.z
    rust.ServerManagement():TeleportPlayer(netuser.playerClient.netPlayer, coords)
  end
end

function BroadcastNotice(message, time)
  local netusers = rust.GetAllNetUsers()
  for k,netuser in pairs(netusers) do
    rust.Notice(netuser, message, time)
  end
end

-- Borrowed from the Infection plugin
local Destroy = util.FindOverloadedMethod(Rust.NetCull._type, "Destroy", bf.public_static, {UnityEngine.GameObject})
function PLUGIN:RemoveBag(netuser)
  local curPos = netuser.playerClient.lastKnownPosition
  local lastObj = self:FindNearestLootableObject("LootSack(Clone)", curPos, 30)
    
  if(lastObj ~= nil ) then
    Destroy:Invoke(nil, util.ArrayFromTable(System.Object, {lastObj.gameObject}))
  end
end

local FindObjectsOfType = util.GetStaticMethod(UnityEngine.Object, "FindObjectsOfType")
function PLUGIN:FindNearestLootableObject(name, position, radius)
  local lastDist = radius
  local lastObj = nil
  local objects = FindObjectsOfType(Rust.LootableObject._type)

  local object
  for i = 0, (objects.Length-1) do
    object = objects[i]

    if(object.gameObject.Name == name) then
      local inv = object:GetComponent("Inventory")  
      if (inv) then
        local pos = object.gameObject.transform.position
        local dist = math.ceil(Rust.TransformHelpers.Dist2D(position, pos))

        if(lastDist >= dist) then
          lastObj = object
        end
      end
    end
  end
  
  return lastObj
end

function PLUGIN:BroadcastToPlayers(message)
  local netusers = rust.GetAllNetUsers()
  if (netusers) then
    for k,netuser in pairs(netusers) do
      if (arena_plugin:IsPlaying(netuser)) then
        rust.SendChatToUser(netuser, self.Config.ChatName, message)
      end
    end
  end
end
