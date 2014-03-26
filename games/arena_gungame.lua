PLUGIN.Title = "Arena: GunGame"
PLUGIN.Description = "Arena minigame where players have to kill eachother using all weapons to win"
PLUGIN.Author = "eDeloa"
PLUGIN.Version = "1.0.0"

print(PLUGIN.Title .. " (" .. PLUGIN.Version .. ") plugin loaded")

--[[
TODO:
Save stats on winners
bleeding out is sometimes suicide? doesnt count as a kill, either
]]--

function PLUGIN:Init()
  arena_plugin = plugins.Find("arena")
  if (not arena_plugin) then
    error("You do not have the Arena plugin installed! Check here: http://forum.rustoxide.com/resources/arena.237")
    return
  end

  arena_gungame_loaded = true

  -- Load the config file
  local b, res = config.Read("arena_gungame")
  self.Config = res or {}
  if (not b) then
    self:LoadDefaultConfig()
    if (res) then
      config.Save("arena_gungame")
    end
  end

  self.GunGameData = {}
  self.GunGameData.Users = {}
  self.GunGameData.IsChosen = false
  self.GunGameData.HasStarted = false
  self.GunGameData.maxlevel = #self.Config.Levels

  -- Register with the Arena system
  self.GunGameData.GameID = arena_plugin:RegisterArenaGame("GunGame")
end

-- *******************************************
-- ARENA HOOK FUNCTIONS
-- *******************************************
function PLUGIN:CanSelectArenaGame(gameid)
  if (gameid == self.GunGameData.GameID) then
    -- No conditions need to be met in order to select GunGame
    return true
  end
end

function PLUGIN:OnSelectArenaGamePost(gameid)
  -- Keep track of whether GunGame was chosen or not
  if (gameid == self.GunGameData.GameID) then
    self.GunGameData.IsChosen = true
  else
    self.GunGameData.IsChosen = false
  end
end

function PLUGIN:CanArenaOpen()
  if (self.GunGameData.IsChosen) then
    -- No conditions need to be met in order to open the Arena for GunGame
    return true
  end
end

function PLUGIN:OnArenaOpenPost()
  if (self.GunGameData.IsChosen) then
    -- Let players know about inventory clearing
    rust.BroadcastChat("GunGame", "In GunGame, your inventory WILL be lost!  Do not join until you have put away your items!")
  end
end

function PLUGIN:CanArenaClose()
  if (self.GunGameData.IsChosen) then
    -- No conditions need to be met in order to close the Arena for GunGame
    return true
  end
end

function PLUGIN:OnArenaClosePost()
  -- We don't need to do anything when the Arena closes
end

function PLUGIN:CanArenaStart()
  if (self.GunGameData.IsChosen) then
    -- No conditions need to be met in order to start GunGame
    return true
  end
end

function PLUGIN:OnArenaStartPre()
  -- We don't need to do anything before the Arena starts
end

-- *******************************************
-- Called after everyone has been teleported into the Arena
-- *******************************************
function PLUGIN:OnArenaStartPost()
  if (self.GunGameData.IsChosen) then
    self.GunGameData.HasStarted = true
    self.GunGameData.HighestLevel = 0
    self:EquipAllPlayers()
  end
end

function PLUGIN:CanArenaEnd()
  if (self.GunGameData.IsChosen) then
    -- No conditions need to be met in order to end GunGame
    return true
  end
end

function PLUGIN:OnArenaEndPre()
  if (self.GunGameData.IsChosen) then
    -- End GunGame
    self.GunGameData.HasStarted = false
  end
end

-- *******************************************
-- Called after everyone has already been kicked out of the Arena.
-- OnArenaLeavePost() is called for each user before OnArenaEndPost() is called
-- *******************************************
function PLUGIN:OnArenaEndPost()
  if (self.GunGameData.IsChosen) then
    -- We don't need to do anything after the Arena closes
  end
end

function PLUGIN:CanArenaJoin(netuser)
  if (self.GunGameData.IsChosen) then
    -- No conditions need to be met in order for someone to join GunGame
    return true
  end
end

function PLUGIN:OnArenaJoinPost(netuser)
  if (self.GunGameData.IsChosen) then
    -- Prepare a user's starting stats
    local userID = tonumber( rust.GetUserID(netuser) )
    self.GunGameData.Users[userID] = {}
    self.GunGameData.Users[userID].level = 1
    self.GunGameData.Users[userID].kills = 0
    self.GunGameData.Users[userID].spawnTime = -1

    -- If we have already started, teleport the player in immediately
    if (self.GunGameData.HasStarted) then
      arena_plugin:TeleportPlayerToArena(netuser)
      self:EquipPlayer(netuser)
    end
  end
end

-- *******************************************
-- Called after a player has left the Arena.
-- *******************************************
function PLUGIN:OnArenaLeavePost(netuser)
  if (self.GunGameData.IsChosen) then
    self:ClearInventory(netuser)
    local userID = tonumber( rust.GetUserID(netuser) )
    self.GunGameData.Users[userID] = nil
  end
end

function PLUGIN:OnArenaSpawnPost(playerclient, usecamp, avatar)
  if (self.GunGameData.IsChosen and self.GunGameData.HasStarted) then
    self:ShowPlayerScore(playerclient.netUser)
    self:GivePlayerImmunity(playerclient.netUser)
    self:EquipPlayer(playerclient.netUser)
  end
end

-- *******************************************
-- HOOK FUNCTIONS
-- *******************************************
function PLUGIN:ModifyDamage(takedamage, damage)
  if (not arena_gungame_loaded) then
    error("This plugin requires the Arena plugin to be installed!")
    return
  end

  if (self.GunGameData.IsChosen and self.GunGameData.HasStarted) then
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
  if (not arena_gungame_loaded) then
    error("This plugin requires the Arena plugin to be installed!")
    return
  end

  if (self.GunGameData.IsChosen and self.GunGameData.HasStarted) then
    if (takedamage:GetComponent("HumanController")) then
      if (damage.attacker and damage.attacker.client and damage.victim and damage.victim.client) then
        local attacker = damage.attacker.client.netUser
        local victim = damage.victim.client.netUser

        if (attacker and victim and arena_plugin:IsPlaying(victim)) then
          if (attacker == victim) then
            self:ProcessSuicide(victim)
          elseif (not arena_plugin:IsPlaying(attacker)) then
            -- Handle this
          elseif (damage.extraData and damage.extraData.dataBlock) then
            local weapon = damage.extraData.dataBlock.name
            local userData = self:GetUserData(attacker)
            if (weapon and weapon == self.Config.Levels[userData.level].weapon) then
              self:AwardKill(attacker)
            elseif (self.GunGameData.MeleeKillSteal and self:IsMeleeWeapon(weapon)) then
              self:StoleLevel(attacker, victim)
            else
              -- Killed with the wrong gun
              rust.Notice(attacker, "Killed with the wrong weapon!", 2)
            end
          end
          timer.Once(0, function() arena_plugin:RemoveBag(victim) end)
        end
      end
    end
  end
end

-- *******************************************
-- MAIN FUNCTIONS
-- *******************************************
function PLUGIN:ProcessSuicide(netuser)
  if (self.Config.LoseLevelForSuicide) then
    local userData = self:GetUserData(netuser)
    userData.kills = 0
    if (userData.level > 1) then
      userData.level = userData.level - 1
    end
    arena_plugin:BroadcastToPlayers(netuser.displayName .. " has lost a level for suiciding!")
  end
end

function PLUGIN:IsMeleeWeapon(weapon)
  return (weapon and (weapon == "Rock" or weapon == "Hatchet" or weapon == "Stone Hatchet" or weapon == "Pick Axe"))
end

function PLUGIN:StoleLevel(killer, victim)
  local victimData = self:GetUserData(victim)
  victimData.level = victimData.level - 1
  victimData.kills = 0

  local str = killer.displayName .. " has stolen a level from " .. victim.displayName .. "!"
  arena_plugin:BroadcastToPlayers(str)
  self:AwardLevel(killer)
end

function PLUGIN:AwardKill(netuser)
  local userData = self:GetUserData(netuser)
  userData.kills = userData.kills + 1
  self:DisplayKillMessage(netuser)

  if (userData.kills >= self.Config.Levels[userData.level].requiredkills) then
    self:AwardLevel(netuser)
  else
    self:ShowPlayerScore(netuser)
  end
end

function PLUGIN:AwardLevel(netuser)
  local userData = self:GetUserData(netuser)
  userData.level = userData.level + 1
  userData.kills = 0

  if (userData.level > #(self.Config.Levels)) then
    self:GiveWin(netuser)
  else
    local str = netuser.displayName .. " has reached Level " .. userData.level .. "!"
    arena_plugin:BroadcastToPlayers(str)
    self:ShowPlayerScore(netuser)
    self:EquipPlayer(netuser)
    rust.Notice(netuser, "Level Up!", 2)
    rust.InventoryNotice(netuser, "Level Up!")

    if (userData.level > self.GunGameData.HighestLevel) then
      str = netuser.displayName .. " is in the lead!  Level (" .. userData.level .. "/" .. self.GunGameData.maxlevel .. ")"
      self.GunGameData.HighestLevel = userData.level
      arena_plugin:BroadcastToPlayers(str)
    elseif (userData.level == self.GunGameData.HighestLevel) then
      str = netuser.displayName .. " is tied for the lead!  Level (" .. userData.level .. "/" .. self.GunGameData.maxlevel .. ")"
      arena_plugin:BroadcastToPlayers(str)
    end
  end
end

function PLUGIN:GiveWin(netuser)
  -- Announce win
  local str = "GUNGAME IS OVER!  " .. string.upper(netuser.displayName) .. " WINS!"
  for i = 1, 10 do
    arena_plugin:BroadcastToPlayers(str)
  end

  -- Trigger the end of the arena
  --arena_plugin:EndArena()
  timer.Once(5, function() arena_plugin:EndArena() end)
end

function PLUGIN:EquipAllPlayers()
  local netusers = rust.GetAllNetUsers()
  if (netusers) then
    for k,netuser in pairs(netusers) do
      if (arena_plugin:IsPlaying(netuser)) then
        self:EquipPlayer(netuser)
      end
    end
  end
end

function PLUGIN:EquipPlayer(netuser)
  local userData = self:GetUserData(netuser)

  self:ClearInventory(netuser)

  local pref, inv
  local str, item
  local levelData = self.Config.Levels[userData.level]

  --inv = netuser.playerClient.rootControllable.idMain:GetComponent("Inventory")
  --inv = netuser.playerClient.controllable:GetComponent("PlayerInventory")
  inv = rust.GetInventory(netuser)

  -- Equip player with armor
  if (levelData.armor) then
    pref = rust.InventorySlotPreference(InventorySlotKind.Armor, false, InventorySlotKindFlags.Armor)

    for i = 1, #levelData.armor do
      str = levelData.armor[i]
      item = rust.GetDatablockByName(str)
      inv:AddItemAmount(item, 1, pref)
    end
  end

  -- Fill player's backpack with ammo and equip player with weapon
  if (levelData.weapon) then
    pref = rust.InventorySlotPreference(InventorySlotKind.Default, false, InventorySlotKindFlags.Belt)
    local stackSize
    if (levelData.weapon == "9mm Pistol" or levelData.weapon == "P250" or levelData.weapon == "Revolver" or levelData.weapon == "MP5A4") then
      str = "9mm Ammo"
      stackSize = 250
    elseif (levelData.weapon == "M4" or levelData.weapon == "Bolt Action Rifle") then
      str = "556 Ammo"
      stackSize = 250
    elseif (levelData.weapon == "Shotgun") then
      str = "Shotgun Shells"
      stackSize = 250
    elseif (levelData.weapon == "Pipe Shotgun" or levelData.weapon == "HandCannon") then
      str = "Handmade Shell"
      stackSize = 250
    elseif (levelData.weapon == "Hunting Bow") then
      str = "Arrow"
      stackSize = 10
    elseif (levelData.weapon == "F1 Grenade") then
      str = "F1 Grenade"
      stackSize = 5
    else
      str = nil
    end

    if (str) then
      item = rust.GetDatablockByName(str)
      inv:AddItemAmount(item, (stackSize * 30), pref)
    end

    --str = levelData.weapon
    --item = rust.GetDatablockByName(str)
    --inv:AddItemAmount(item, 1, pref)
    self:GiveLoadedWeapon(netuser, levelData.weapon)
  end

  -- Equip player with items
  pref = rust.InventorySlotPreference(InventorySlotKind.Belt, false, InventorySlotKindFlags.Belt)
  if (levelData.belt) then
    for i = 1, #levelData.belt do
      if (levelData.belt[i][2]) then
        item = rust.GetDatablockByName(levelData.belt[i][1])
        inv:AddItemAmount(item, levelData.belt[i][2], pref)
      else
        item = rust.GetDatablockByName(levelData.belt[i])
        inv:AddItemAmount(item, 1, pref)
      end
    end
  end
end

-- *******************************************
-- HELPER FUNCTIONS
-- *******************************************
function PLUGIN:ShowPlayerScore(netuser)
  local userData = self:GetUserData(netuser)
  local levelStr = "Level (" .. userData.level .. "/" .. self.GunGameData.maxlevel .. ")"
  local killsStr = "Kills (" .. userData.kills .. "/" .. self.Config.Levels[userData.level].requiredkills .. ")"
  local str = "You are:  " .. levelStr .. "  " .. killsStr
  rust.SendChatToUser(netuser, "GunGame", str)
end

function PLUGIN:ClearInventory(netuser)
  --local inv = netuser.playerClient.rootControllable.idMain:GetComponent("Inventory")
  --local inv = netuser.playerClient.controllable:GetComponent("PlayerInventory")
  local inv = rust.GetInventory(netuser)
  inv:Clear()
  --for i = 0, 39 do
  --  inv:RemoveItem(i)
  --end
end

function PLUGIN:GetUserData(netuser)
  local userID = tonumber( rust.GetUserID(netuser) )
  return self.GunGameData.Users[userID]
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
  self.Config.LoseLevelForSuicide = true
  self.Config.MeleeKillSteal = true
  self.Config.SpawnImmunity = 4
  self.Config.Levels =
  {
    --{weapon = "Revolver", armor = {"Kevlar Helmet", "Kevlar Vest", "Kevlar Pants", "Kevlar Boots"}, belt = {{"Large Medkit", 10}, {"Cooked Chicken Breast", 10}}, requiredkills = 3},
    {weapon = "9mm Pistol", armor = {"Kevlar Helmet", "Kevlar Vest", "Kevlar Pants", "Kevlar Boots"}, belt = {{"Large Medkit", 5}, {"Cooked Chicken Breast", 10}, {"F1 Grenade", 5}, "Hatchet"}, requiredkills = 2},
    {weapon = "P250", armor = {"Leather Helmet", "Leather Vest", "Leather Pants", "Leather Boots"}, belt = {{"Large Medkit", 4}, {"Cooked Chicken Breast", 5}, {"F1 Grenade", 5}, "Hatchet"}, requiredkills = 4},
    {weapon = "MP5A4", armor = {"Cloth Helmet", "Cloth Vest", "Cloth Pants", "Cloth Boots"}, belt = {{"Large Medkit", 2}, {"Cooked Chicken Breast", 5}, {"F1 Grenade", 5}, "Hatchet"}, requiredkills = 6},
    {weapon = "Shotgun", armor = {"Leather Helmet", "Leather Vest", "Leather Pants", "Leather Boots"}, belt = {{"Large Medkit", 3}, {"Cooked Chicken Breast", 5}, {"F1 Grenade", 5}, "Hatchet"}, requiredkills = 8},
    {weapon = "M4", armor = {}, belt = {{"Small Medkit", 1}, {"Cooked Chicken Breast", 5}, {"F1 Grenade", 5}, "Hatchet"}, requiredkills = 10},
    {weapon = "Bolt Action Rifle", armor = {}, belt = {{"Cooked Chicken Breast", 5}, "Hachet"}, requiredkills = 2},
    {weapon = "Uber Hatchet", armor = {}, belt = {{"Cooked Chicken Breast", 5}, "Hachet"}, requiredkills = 1}
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
  local currentTime = UnityEngine.Time.realtimeSinceStartup
  local userData = self:GetUserData(netuser)
  userData.spawnTime = currentTime
end

function PLUGIN:IsImmune(netuser)
  local currentTime = UnityEngine.Time.realtimeSinceStartup
  local userData = self:GetUserData(netuser)
  return (not ((currentTime - userData.spawnTime) > self.Config.SpawnImmunity))
end

local msgNumber = 1
function PLUGIN:DisplayKillMessage(netuser)
  rust.Notice(netuser, self.Config.KillMessages[msgNumber], 3)
  rust.InventoryNotice(netuser, self.Config.KillMessages[msgNumber])
  msgNumber = (msgNumber % #self.Config.KillMessages) + 1
end
