PLUGIN.Title = "Spawns"
PLUGIN.Description = "Create, manage and share custom spawn locations."
PLUGIN.Author = "eDeloa"
PLUGIN.Version = "1.0.0"

print(PLUGIN.Title .. " (" .. PLUGIN.Version .. ") plugin loaded")

function PLUGIN:Init()
  flags_plugin = plugins.Find("flags")
  if (not flags_plugin) then
    error("You do not have the Flags plugin installed! Check here: http://forum.rustoxide.com/resources/flags.155")
    return
  end

  self.SpawnsData = {}
  self.SpawnsData.Spawns = {}
  self.SpawnsData.NextID = 1

  self.SpawnsData.LoadedSpawns = {}
  self.SpawnsData.LoadedSpawns.Spawns = {}
  self.SpawnsData.LoadedSpawns.NextID = 1

  -- Add Flag Chat Commands
  flags_plugin:AddFlagsChatCommand(self, "spawns_new", {"spawns"}, self.cmdSpawnsNew)
  flags_plugin:AddFlagsChatCommand(self, "spawns_open", {"spawns"}, self.cmdSpawnsOpen)
  flags_plugin:AddFlagsChatCommand(self, "spawns_close", {"spawns"}, self.cmdSpawnsClose)
  
  flags_plugin:AddFlagsChatCommand(self, "spawns_add", {"spawns"}, self.cmdSpawnsAdd)
  flags_plugin:AddFlagsChatCommand(self, "spawns_remove", {"spawns"}, self.cmdSpawnsRemove)
end

-- *******************************************
-- CHAT COMMANDS
-- *******************************************
function PLUGIN:cmdSpawnsNew(netuser, cmd, args)
  if (not args[1]) then
    rust.Notice(netuser, "Syntax: /spawns_new {filename}")
    return
  end

  local success, err = self:CreateNewSpawnFile(args[1])
  if (not success) then
    rust.Notice(netuser, err)
    return
  end
  
  rust.Notice(netuser, "Successfully created and opened the spawn file.")
end

function PLUGIN:cmdSpawnsOpen(netuser, cmd, args)
  if (not args[1]) then
    rust.Notice(netuser, "Syntax: /spawns_open {filename}")
    return
  end

  local success, err = self:OpenSpawnFile(args[1])
  if (not success) then
    rust.Notice(netuser, err)
    return
  end
  
  rust.Notice(netuser, "Successfully opened the spawn file.")
end

function PLUGIN:cmdSpawnsClose(netuser, cmd, args)
  local success, err = self:CloseSpawnFile()
  if (not success) then
    rust.Notice(netuser, err)
    return
  end
  
  rust.Notice(netuser, "Successfully saved and closed the spawn file.")
end

function PLUGIN:cmdSpawnsAdd(netuser, cmd, args)
  local spawnID, err = self:AddSpawn(netuser)
  if (not spawnID) then
    rust.Notice(netuser, err)
    return
  end

  rust.Notice(netuser, "Successfully added spawn point with spawnID: " .. spawnID)
end

function PLUGIN:cmdSpawnsRemove(netuser, cmd, args)
  if (not args[1]) then
    rust.Notice(netuser, "Syntax: /spawns_remove {spawnID}")
    return
  end

  local success, err = self:RemoveSpawn(tonumber(args[1]))
  if (not success) then
    rust.Notice(netuser, err)
    return
  end

  rust.Notice(netuser, "Successfully removed spawn point.")
end

-- *******************************************
-- API COMMANDS
-- *******************************************
function PLUGIN:LoadSpawnFile(filename)
  local fileID = self.SpawnsData.LoadedSpawns.NextID
  self.SpawnsData.LoadedSpawns[fileID] = {}
  
  local loadedSpawns = self.SpawnsData.LoadedSpawns[fileID]
  loadedSpawns.File = util.GetDatafile(filename)
  local txt = loadedSpawns.File:GetText()
  if (txt ~= "") then
    loadedSpawns.Spawns = json.decode(txt)
    if (not loadedSpawns.Spawns) then
      loadedSpawns.File = nil
      loadedSpawns.Spawns = nil
      loadedSpawns = nil
      return false, "Error decoding the spawn file's JSON."
    end

    self.SpawnsData.LoadedSpawns.NextID = self.SpawnsData.LoadedSpawns.NextID + 1
    return fileID
  end

  return false, "Spawn file is empty or does not exist."
end

function PLUGIN:UnloadSpawnFile(fileid)
  if (self:LoadedSpawnExists(fileid)) then
    return false, "No spawn file with that FileID is currently loaded."
  end

  loadedSpawns.File = nil
  loadedSpawns.Spawns = nil
  loadedSpawns = nil
  return true
end

function PLUGIN:GetSpawnPointCount(fileid)
  if (not self:LoadedSpawnExists(fileid)) then
    return false, "No spawn file with that FileID is currently loaded."
  end

  return #self.SpawnsData.LoadedSpawns[fileid].Spawns
end

function PLUGIN:GetSpawnPointFromIndex(fileid, index)
  if (not self:LoadedSpawnExists(fileid)) then
    return false, "No spawn file with that FileID is currently loaded."
  end

  if (self.SpawnsData.LoadedSpawns[fileid].Spawns[index] == nil) then
    return false, "Index out of range."
  end

  return self.SpawnsData.LoadedSpawns[fileid].Spawns[index]
end

function PLUGIN:GetSpawnPointFromSpawnID(fileid, spawnid)
  if (self:LoadedSpawnExists(fileid)) then
    return false, "No spawn file with that FileID is currently loaded."
  end

  local spawnPoints = self.SpawnsData.LoadedSpawns[fileid].Spawns
  for i = 1, #spawnPoints do
    if (spawnid == spawnPoints[i].SpawnID) then
      return spawnPoints[i].SpawnID
    end
  end

  return false, "No spawn point with that SpawnID."
end

-- *******************************************
-- HOOK FUNCTIONS
-- *******************************************
function PLUGIN:SendHelpText(netuser)
  if (not flags_plugin) then
    error("This plugin requires the Flags plugin to be installed!")
    return
  end

  if (flags_plugin:HasFlag(netuser, "spawns")) then
    rust.SendChatToUser(netuser, "Spawns", "Use /spawns_new {filename} to create and open a new spawn file.")
    rust.SendChatToUser(netuser, "Spawns", "Use /spawns_open {filename} to open and edit an existing spawn file.")
    rust.SendChatToUser(netuser, "Spawns", "Use /spawns_close to close the open spawn file.")
    rust.SendChatToUser(netuser, "Spawns", "Use /spawns_add to add a new spawn point.")
    rust.SendChatToUser(netuser, "Spawns", "Use /spawns_remove {spawnID} to remove a spawn point.")
  end
end

function PLUGIN:OnSave()
  if (not flags_plugin) then
    error("This plugin requires the Flags plugin to be installed!")
    return
  end

  self:SaveOpenSpawnFile()
end

-- *******************************************
-- MAIN FUNCTIONS
-- *******************************************
function PLUGIN:CreateNewSpawnFile(filename)
  if (self:IsSpawnFileOpen()) then
    return false, "A spawn file is already open."
  end

  self.SpawnsFile = util.GetDatafile(filename)
  local txt = self.SpawnsFile:GetText()
  if (txt ~= "") then
    self.SpawnsFile = nil
    self.SpawnsData.Spawns = nil
    return false, "A spawn file with that name already exists."
  end
  
  self.SpawnsData.Spawns = {}
  return true
end

function PLUGIN:OpenSpawnFile(filename)
  if (self:IsSpawnFileOpen()) then
    return false, "A spawn file is already open."
  end

  self.SpawnsFile = util.GetDatafile(filename)
  local txt = self.SpawnsFile:GetText()
  if (txt ~= "") then
    self.SpawnsData.Spawns = json.decode(txt)
    if (not self.SpawnsData.Spawns) then
      self.SpawnsFile = nil
      self.SpawnsData.Spawns = nil
      return false, "Error decoding the spawn file's JSON."
    end

    return true
  end

  self.SpawnsFile = nil
  return false, "Could not open the spawn file."
end

function PLUGIN:CloseSpawnFile()
  if (not self:IsSpawnFileOpen()) then
    return false, "A spawn file is not open."
  end

  local count = #self.SpawnsData.Spawns

  if (count > 0) then
    self:SaveOpenSpawnFile()
  end
  
  self.SpawnsFile = nil
  self.SpawnsData.Spawns = nil
  self.SpawnsData.NextID = 1

  if (count < 1) then
    return false, "Not enough valid spawn points.  File closed but not saved."
  end

  return true
end

function PLUGIN:AddSpawn(netuser)
  if (not self:IsSpawnFileOpen()) then
    return false, "No spawn file open.  Open a spawn file or create a new one before adding spawn points."
  end

  local coords = netuser.playerClient.lastKnownPosition

  -- Add new coordinate
  local spawnID = self.SpawnsData.NextID
  local spawnPoint = {SpawnID = spawnID, x = coords.x, y = (coords.y + 1), z = coords.z}
  table.insert(self.SpawnsData.Spawns, spawnPoint)

  self.SpawnsData.NextID = self.SpawnsData.NextID + 1
  return spawnID
end

function PLUGIN:RemoveSpawn(spawnid)
  if (not self:IsSpawnFileOpen()) then
    return false, "No spawn file open.  Open a spawn file or create a new one before remving spawn points."
  end

  for i = 1, #self.SpawnsData.Spawns do
    if (self.SpawnsData.Spawns[i] and (spawnid == self.SpawnsData.Spawns[i].SpawnID)) then
      table.remove(self.SpawnsData.Spawns, i)
      return true
    end
  end

  return false, "Invalid SpawnID."
end

-- *******************************************
-- HELPER FUNCTIONS
-- *******************************************
function PLUGIN:IsSpawnFileOpen()
  return self.SpawnsFile ~= nil
end

function PLUGIN:SaveOpenSpawnFile()
  if (self:IsSpawnFileOpen()) then
    self.SpawnsFile:SetText(json.encode(self.SpawnsData.Spawns))
    self.SpawnsFile:Save()
  end
end

function PLUGIN:LoadedSpawnExists(fileID)
  return self.SpawnsData.LoadedSpawns[fileID] ~= nil
end
