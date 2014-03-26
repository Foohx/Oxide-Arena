PLUGIN.Title = "Arena: Last Man Standing"
PLUGIN.Description = "Start with a certain number of lives and do not die!"
PLUGIN.Author = "eDeloa"
PLUGIN.Version = "1.0.0"

print(PLUGIN.Title .. " (" .. PLUGIN.Version .. ") plugin loaded")

function PLUGIN:Init()
  flags_plugin = plugins.Find("flags")
  if (not flags_plugin) then
    error("You do not have the Flags plugin installed! Check here: http://forum.rustoxide.com/resources/flags.155")
    return
  end

  arena_plugin = plugins.Find("arena")
  if (not arena_plugin) then
    error("You do not have the Arena plugin installed! Check here: http://forum.rustoxide.com/resources/arena.237")
    return
  end

  -- Load the config file
  local b, res = config.Read("arena_lastmanstanding")
  self.Config = res or {}
  if (not b) then
    self:LoadDefaultConfig()
    if (res) then
      config.Save("arena_lastmanstanding")
    end
  end

  self.LastManStandingData = {}
  self.LastManStandingData.Users = {}
  self.LastManStandingData.IsChosen = false
  self.LastManStandingData.HasStarted = false
  self.LastManStandingData.CustomPack = 0
  self.LastManStandingData.TotalPlayers = 0

  flags_plugin:AddFlagsChatCommand(self, "lastmanstanding_pack", {"arena_admin"}, self.cmdLastManStandingPack)
end

function PLUGIN:PostInit()
  if (not arena_plugin) then
    error("This plugin requires the Flags and Arena plugins to be installed!")
    return
  end
  
  -- Register with the Arena system
  self.LastManStandingData.GameID = arena_plugin:RegisterArenaGame("Last Man Standing")
end

-- *******************************************
-- CHAT FUNCTIONS
-- *******************************************
function PLUGIN:cmdLastManStandingPack(netuser, cmd, args)
  local pack = tonumber(args[1])
  if (not pack) then
    rust.Notice(netuser, "Syntax: /lastmanstanding_pack {packNumber (0 = default)}")
    return
  end

  if (pack == 0) then
    self.LastManStandingData.CustomPack = 0
    rust.Notice(netuser, "Default pack settings loaded.")
  elseif (pack > 0 and pack <= #self.Config.Packs) then
    self.LastManStandingData.CustomPack = pack
    rust.Notice(netuser, "Custom Last Man Standing pack selected.")
  else
    rust.Notice(netuser, "Specified pack number out of bounds.")
  end
end

-- *******************************************
-- ARENA HOOK FUNCTIONS
-- *******************************************
function PLUGIN:CanSelectArenaGame(gameid)
  if (gameid == self.LastManStandingData.GameID) then
    -- No conditions need to be met in order to select Last Man Standing
    return true
  end
end

function PLUGIN:OnSelectArenaGamePost(gameid)
  -- Keep track of whether Last Man Standing was chosen or not
  if (gameid == self.LastManStandingData.GameID) then
    self.LastManStandingData.IsChosen = true
  else
    self.LastManStandingData.IsChosen = false
  end
end

function PLUGIN:CanArenaOpen()
  if (self.LastManStandingData.IsChosen) then
    -- Can not open Arena once the game has started
    if (self.LastManStandingData.HasStarted) then
      return false, "The Arena may not be opened in the middle of Last Man Standing."
    end
    return true
  end
end

function PLUGIN:OnArenaOpenPost()
  if (self.LastManStandingData.IsChosen) then
    -- Let players know about inventory clearing
    rust.BroadcastChat("LastManStanding", "In Last Man Standing, your inventory WILL be lost!  Do not join until you have put away your items!")
  end
end

function PLUGIN:CanArenaClose()
  if (self.LastManStandingData.IsChosen) then
    -- No conditions need to be met in order to close the Arena for Last Man Standing
    return true
  end
end

function PLUGIN:OnArenaClosePost()
  -- We don't need to do anything when the Arena closes
end

function PLUGIN:CanArenaStart()
  if (self.LastManStandingData.IsChosen) then
    if (self.LastManStandingData.TotalPlayers < 2) then
      return false, "Must have at least 2 players signed up to play Last Man Standing."
    end
    return true
  end
end

-- *******************************************
-- Called after everyone has been teleported into the Arena
-- *******************************************
function PLUGIN:OnArenaStartPost()
  if (self.LastManStandingData.IsChosen) then
    arena_plugin:CloseArena()
    self.LastManStandingData.HasStarted = true
    self:EquipAllPlayers()
  end
end

function PLUGIN:CanArenaEnd()
  if (self.LastManStandingData.IsChosen) then
    -- No conditions need to be met in order to prematurely end Last Man Standing
    return true
  end
end

-- *******************************************
-- Called after everyone has already been kicked out of the Arena.
-- OnArenaLeavePost() is called for each user before OnArenaEndPost() is called
-- *******************************************
function PLUGIN:OnArenaEndPost()
  if (self.LastManStandingData.IsChosen) then
    -- End Last Man Standing
    self.LastManStandingData.HasStarted = false
  end
end

function PLUGIN:CanArenaJoin(netuser)
  if (self.LastManStandingData.IsChosen) then
    -- No conditions need to be met in order for someone to join Last Man Standing
    return true
  end
end

function PLUGIN:OnArenaJoinPost(netuser)
  if (self.LastManStandingData.IsChosen) then
    local userID = rust.GetUserID(netuser)
    self.LastManStandingData.Users[userID] = {}
    self.LastManStandingData.Users[userID].livesLeft = self.Config.Lives
    self.LastManStandingData.Users[userID].spawnTime = -1
    self.LastManStandingData.TotalPlayers = self.LastManStandingData.TotalPlayers + 1
  end
end

-- *******************************************
-- Called after a player has left the Arena.
-- *******************************************
function PLUGIN:OnArenaLeavePost(netuser)
  if (self.LastManStandingData.IsChosen) then
    self:ClearInventory(netuser)
    local userID = rust.GetUserID(netuser)
    self.LastManStandingData.Users[userID] = nil
    self.LastManStandingData.TotalPlayers = self.LastManStandingData.TotalPlayers - 1

    if (self.LastManStandingData.TotalPlayers == 1) then
      self:FindWinner()
    end
  end
end

function PLUGIN:OnArenaSpawnPost(playerclient, usecamp, avatar)
  if (self.LastManStandingData.IsChosen) then
    local userData = self:GetUserData(playerclient.netUser)
    if (userData.livesLeft > 0) then
      self:ShowPlayerScore(playerclient.netUser)
      self:EquipPlayer(playerclient.netUser)
      self:GivePlayerImmunity(playerclient.netUser)
    else
      local str = playerclient.netUser.displayName .. " has no lives left!  Get out of here!"
      arena_plugin:BroadcastToPlayers(str)
      arena_plugin:LeaveArena(playerclient.netUser)
    end
  end
end

-- *******************************************
-- HOOK FUNCTIONS
-- *******************************************
function PLUGIN:ModifyDamage(takedamage, damage)
  if (not arena_plugin) then
    error("This plugin requires the Flags and Arena plugins to be installed!")
    return
  end

  if (self.LastManStandingData.IsChosen and self.LastManStandingData.HasStarted) then
    if (damage and damage.attacker and damage.attacker.client) then
      -- Check to see what type of entity is being damaged
      if (takedamage:GetComponent("DeployableObject")) then
        if(damage.attacker.idMain and damage.attacker.idMain.client) then
          local deployable = takedamage:GetComponent("DeployableObject")
          local attacker = damage.attacker.client.netUser
          -- Bug where this was called without damaging anything, checking for creatorID and client catches those cases
          if (deployable and attacker and deployable.creatorID ~= "creatorID" and damage.attacker.idMain.client == "client") then
            if (arena_plugin:IsPlaying(attacker)) then
              damage.amount = 0
              return damage
            end
          end
        end
      elseif (takedamage:GetComponent("StructureComponent")) then
        local attacker = damage.attacker.client.netUser
        if(attacker and arena_plugin:IsPlaying(attacker)) then
          damage.amount = 0
          return damage
        end
      elseif (takedamage:GetComponent("HumanController")) then
        if (damage.attacker and damage.victim) then
          if (damage.attacker.client and damage.victim.client and (damage.victim.client ~= damage.attacker.client)) then
            local attacker = damage.attacker.client.netUser
            local victim = damage.victim.client.netUser
            if (attacker and victim) then
              -- If the victim is protected, deal no damage
              if (arena_plugin:IsPlaying(victim) and self:IsImmune(victim)) then
                rust.Notice(attacker, "New spawns have immunity!", 2)
                damage.amount = 0
                return damage
              end
            end
          end
        end
      end
    end
  end
end

function PLUGIN:OnKilled(takedamage, damage)
  if (not arena_plugin) then
    error("This plugin requires the Flags and Arena plugins to be installed!")
    return
  end

  if (self.LastManStandingData.IsChosen and self.LastManStandingData.HasStarted) then
    if (takedamage:GetComponent("HumanController")) then
      if (damage.victim and damage.victim.client) then
        local victim = damage.victim.client.netUser
        if (victim and arena_plugin:IsPlaying(victim)) then
          self:AwardDeath(victim)
          timer.Once(0, function() arena_plugin:RemoveBag(victim) end)

          if (damage.attacker and damage.attacker.client) then
            local attacker = damage.attacker.client.netUser
            if (attacker and arena_plugin:IsPlaying(attacker)) then
              self:AwardKill(attacker)
            end
          end
        end
      end
    end
  end
end


function PLUGIN:SendHelpText(netuser)
  if (not arena_plugin) then
    error("This plugin requires the Flags and Arena plugins to be installed!")
    return
  end

  if (flags_plugin:HasFlag(netuser, "arena_admin")) then
    rust.SendChatToUser(netuser, "LastManStanding", "Use /lastmanstanding_pack {packNumber} to select a custom pack for Last Man Standing.")
  end
end

-- *******************************************
-- MAIN FUNCTIONS
-- *******************************************
function PLUGIN:EquipAllPlayers()
  local netusers = rust.GetAllNetUsers()
  for k,netuser in pairs(netusers) do
    if (arena_plugin:IsPlaying(netuser)) then
      self:EquipPlayer(netuser)
    end
  end
end

function PLUGIN:EquipPlayer(netuser)
  self:ClearInventory(netuser)

  local pref, inv, str, item
  local packNum = self.Config.DefaultPack
  if (self.LastManStandingData.CustomPack > 0) then
    packNum = self.LastManStandingData.CustomPack
  elseif (self.Config.RandomPack) then
    packNum = math.random(#self.Config.Packs)
  end

  local packData = self.Config.Packs[packNum]
  inv = rust.GetInventory(netuser)

  -- Equip player with armor
  if (packData.armor) then
    pref = rust.InventorySlotPreference(InventorySlotKind.Armor, false, InventorySlotKindFlags.Armor)
    for i = 1, #packData.armor do
      str = packData.armor[i]
      item = rust.GetDatablockByName(str)
      inv:AddItemAmount(item, 1, pref)
    end
  end

  -- Equip player with items in their backpack
  if (packData.backpack) then
    pref = rust.InventorySlotPreference(InventorySlotKind.Default, false, InventorySlotKindFlags.Belt)
    for i = 1, #packData.backpack do
      if (packData.backpack[i][2]) then
        item = rust.GetDatablockByName(packData.backpack[i][1])
        inv:AddItemAmount(item, packData.backpack[i][2], pref)
      else
        item = rust.GetDatablockByName(packData.backpack[i])
        inv:AddItemAmount(item, 1, pref)
      end
    end
  end

  -- Fill up the rest of the backpack
  pref = rust.InventorySlotPreference(InventorySlotKind.Default, false, InventorySlotKindFlags.Belt)
  item = rust.GetDatablockByName("Rock")
  for i = (#packData.backpack), 29 do
    inv:AddItemAmount(item, 1, pref)
  end

  -- Remove excess rocks
  for i = 30, 35 do
    inv:RemoveItem(i)
  end

  -- Equip player with specified weapons
  if (packData.weapons) then
    pref = rust.InventorySlotPreference(InventorySlotKind.Belt, false, InventorySlotKindFlags.Belt)
    for i = 1, #packData.weapons do
      self:GiveLoadedWeapon(netuser, packData.weapons[i])
    end
  end

  -- Equip player with items on their belt
  if (packData.belt) then
    pref = rust.InventorySlotPreference(InventorySlotKind.Belt, false, InventorySlotKindFlags.Belt)
    for i = 1, #packData.belt do
      if (packData.belt[i][2]) then
        item = rust.GetDatablockByName(packData.belt[i][1])
        inv:AddItemAmount(item, packData.belt[i][2], pref)
      else
        item = rust.GetDatablockByName(packData.belt[i])
        inv:AddItemAmount(item, 1, pref)
      end
    end
  end
end

function PLUGIN:AwardDeath(netuser)
  local userData = self:GetUserData(netuser)
  userData.livesLeft = userData.livesLeft - 1

  --rust.ServerManagement():SpawnPlayer(netuser.playerClient, false)
  timer.Once(4, function() rust.ServerManagement():SpawnPlayer(netuser.playerClient, false) end)
end

function PLUGIN:AwardKill(netuser)
  self:DisplayKillMessage(netuser)
end

function PLUGIN:FindWinner()
  local netusers = rust.GetAllNetUsers()
  for k,netuser in pairs(netusers) do
    if (arena_plugin:IsPlaying(netuser)) then
      -- Announce win
      rust.BroadcastChat("LastManStanding", "LAST MAN STANDING IS OVER!  " .. string.upper(netuser.displayName) .. " WINS!")

      -- Trigger the end of the arena
      timer.Once(5, function() arena_plugin:EndArena() end)
      return
    end
  end
end

-- *******************************************
-- HELPER FUNCTIONS
-- *******************************************
function PLUGIN:ClearInventory(netuser)
  local inv = rust.GetInventory(netuser)
  inv:Clear()
end

function PLUGIN:GiveLoadedWeapon(netuser, weapon)
  local ammoCount = 1
  if (weapon == "9mm Pistol") then
    ammoCount = 12
  elseif (weapon == "P250" or weapon == "Revolver") then
    ammoCount = 8
  elseif (weapon == "Shotgun") then
    ammoCount = 8
  elseif (weapon == "MP5A4") then
    ammoCount = 30
  elseif (weapon == "M4") then
    ammoCount = 24
  elseif (weapon == "Bolt Action Rifle") then
    ammoCount = 3
  end

  local command = "inv.giveplayer \"" .. netuser.displayName .. "\" \"" .. weapon .. "\" 1 " .. ammoCount
  rust.RunServerCommand(command)
end

-- *******************************************
-- PLUGIN:LoadDefaultConfig()
-- Loads the default configuration into the config table
-- *******************************************
function PLUGIN:LoadDefaultConfig()
  -- Set default configuration settings
  self.Config.SpawnImmunity = 4
  self.Config.RandomPack = true
  self.Config.DefaultPack = 1
  self.Config.Lives = 5
  self.Config.Packs =
  {
    {weapons = {"P250", "M4", "Shotgun"}, belt = {{"Large Medkit", 5}, {"Cooked Chicken Breast", 5}}, armor = {"Kevlar Helmet", "Kevlar Vest", "Kevlar Pants", "Kevlar Boots"}, backpack = {{"556 Ammo", 250}, {"9mm Ammo", 250}, {"Shotgun Shells", 250}}},
    {weapons = {"9mm Pistol", "MP5A4", "Bolt Action Rifle"}, belt = {{"Large Medkit", 5}, {"Cooked Chicken Breast", 5}}, armor = {"Kevlar Helmet", "Kevlar Vest", "Kevlar Pants", "Kevlar Boots"}, backpack = {{"556 Ammo", 250}, {"9mm Ammo", 250}, {"Shotgun Shells", 250}}}
    --{weapons = {"Uber Hatchet", "Uber Hunting Bow"}, belt = {{"Large Medkit", 10}}, armor = {"Kevlar Helmet", "Kevlar Vest", "Kevlar Pants", "Kevlar Boots"}, backpack = {{"Arrow", 300}}}
  }
  self.Config.KillMessages =
  {
    "Sweet Kill!",
    "+1 Kill!",
    "Nice Shot!",
    "Destruction!",
    "Like a boss!",
    "You Mex'd him!",
    "Boom!",
    "Ultrakill!",
    "Y0u 4R3 s0 1337!"
  }
end

function PLUGIN:GivePlayerImmunity(netuser)
  local userID = rust.GetUserID(netuser)
  local currentTime = UnityEngine.Time.realtimeSinceStartup
  self.LastManStandingData.Users[userID].spawnTime = currentTime
end

function PLUGIN:IsImmune(netuser)
  local userID = rust.GetUserID(netuser)
  local currentTime = UnityEngine.Time.realtimeSinceStartup
  return (not ((currentTime - self.LastManStandingData.Users[userID].spawnTime) > self.Config.SpawnImmunity))
end

function PLUGIN:ShowPlayerScore(netuser)
  local userData = self:GetUserData(netuser)
  arena_plugin:BroadcastToPlayers(netuser.displayName .. " has " .. (userData.livesLeft) .. " lives left!")
end

function PLUGIN:GetUserData(netuser)
  local userID = rust.GetUserID(netuser)
  return self.LastManStandingData.Users[userID]
end

local msgNumber = 1
function PLUGIN:DisplayKillMessage(netuser)
  rust.Notice(netuser, self.Config.KillMessages[msgNumber], 3)
  rust.InventoryNotice(netuser, self.Config.KillMessages[msgNumber])
  msgNumber = (msgNumber % #self.Config.KillMessages) + 1
end
