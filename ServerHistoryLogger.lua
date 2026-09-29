--[[
	Server History Logger
	Standalone Roblox Luau module for executor environments.

	Usage:
		local Logger = loadstring(game:HttpGet("YOUR_REAL_RAW_GITHUB_URL"))()
		Logger.Start()

		Logger.Stop() -- writes one final snapshot
]]

local Players = game:GetService("Players")

-- Re-running the same GitHub loader should return the already active logger
-- instead of registering a second set of event listeners.
local function getSharedEnvironment()
	local candidates = {}

	if type(getgenv) == "function" then
		local ok, environment = pcall(getgenv)

		if ok and type(environment) == "table" then
			table.insert(candidates, environment)
		end
	end

	if type(getfenv) == "function" then
		local ok, environment = pcall(getfenv)

		if ok and type(environment) == "table" then
			table.insert(candidates, environment)
		end
	end

	if type(_G) == "table" then
		table.insert(candidates, _G)
	end

	for _, environment in ipairs(candidates) do
		return environment
	end

	return nil
end

local sharedEnvironment = getSharedEnvironment()

if sharedEnvironment then
	local existingLogger = sharedEnvironment.__ServerHistoryLogger

	if type(existingLogger) == "table"
		and type(existingLogger.Start) == "function"
		and type(existingLogger.Stop) == "function" then
		return existingLogger
	end
end

local Logger = {}
Logger.VERSION = "1.0.0"

local DEFAULT_FOLDER_NAME = "ServerLogs"
local DEFAULT_WRITE_DEBOUNCE = 0.5
local RESPAWN_SCAN_DELAYS = { 0.05, 0.10, 0.20 }
local CHARACTER_ATTRIBUTE_NAMES = {
	"CustomCharacterName",
	"CustomCharacter",
	"CharacterName",
	"SelectedCharacter",
	"SelectedCharacterName",
}

local state = {
	running = false,
	generation = 0,
	startedAt = 0,
	startedDate = nil,
	startedAtText = "Unknown",
	folderName = DEFAULT_FOLDER_NAME,
	writeDebounce = DEFAULT_WRITE_DEBOUNCE,
	characterAttributeNames = {},
	historyByUserId = {},
	allSkills = {},
	playerBindings = {},
	globalConnections = {},
	dirty = false,
	flushQueued = false,
	fileLoggingEnabled = false,
	fileSystem = {},
	logPath = nil,
	logPathStyle = nil,
}

local flushLog

local function report(message)
	local text = "[ServerLogger] " .. tostring(message)

	if type(warn) == "function" then
		warn(text)
	else
		print(text)
	end
end

local function trim(value)
	if value == nil then
		return nil
	end

	local text = tostring(value)
	text = text:gsub("[\r\n\t]+", " ")
	text = text:match("^%s*(.-)%s*$")

	if text == "" then
		return nil
	end

	return text
end

local function getUnixTimestamp()
	local ok, timestamp = pcall(os.time)

	if ok and type(timestamp) == "number" then
		return math.floor(timestamp)
	end

	return 0
end

local function getLocalDate(timestamp)
	local ok, date = pcall(function()
		return os.date("*t", timestamp)
	end)

	if ok and type(date) == "table" then
		return date
	end

	return {
		year = 1970,
		month = 1,
		day = 1,
		hour = 0,
		min = 0,
		sec = 0,
	}
end

local function formatStartTime(date)
	return string.format(
		"%04d-%02d-%02d %02d:%02d:%02d",
		tonumber(date.year) or 1970,
		tonumber(date.month) or 1,
		tonumber(date.day) or 1,
		tonumber(date.hour) or 0,
		tonumber(date.min) or 0,
		tonumber(date.sec) or 0
	)
end

local function formatRuntime()
	local elapsed = math.max(0, getUnixTimestamp() - state.startedAt)
	local hours = math.floor(elapsed / 3600)
	local minutes = math.floor((elapsed % 3600) / 60)
	local seconds = elapsed % 60

	return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

local function getEnvironmentValue(environment, name)
	if type(environment) ~= "table" then
		return nil
	end

	local ok, value = pcall(function()
		return environment[name]
	end)

	if ok then
		return value
	end

	return nil
end

local function getExecutorFunction(name)
	local value = getEnvironmentValue(sharedEnvironment, name)

	if type(value) == "function" then
		return value
	end

	if type(getfenv) == "function" then
		local ok, environment = pcall(getfenv)

		if ok then
			value = getEnvironmentValue(environment, name)

			if type(value) == "function" then
				return value
			end
		end
	end

	value = getEnvironmentValue(_G, name)

	if type(value) == "function" then
		return value
	end

	return nil
end

local function getPlayerUserId(player)
	local ok, userId = pcall(function()
		return player.UserId
	end)

	if not ok or type(userId) ~= "number" then
		return nil
	end

	return userId
end

local function getPlayerIdentity(player)
	local displayName = nil
	local username = nil

	local displayOk, displayValue = pcall(function()
		return player.DisplayName
	end)

	if displayOk then
		displayName = trim(displayValue)
	end

	local usernameOk, usernameValue = pcall(function()
		return player.Name
	end)

	if usernameOk then
		username = trim(usernameValue)
	end

	displayName = displayName or username or "Unknown"
	username = username and ("@" .. username) or "@Unknown"

	return displayName, username
end

local function disconnectConnections(connections)
	for index = #connections, 1, -1 do
		local connection = connections[index]
		connections[index] = nil

		if connection then
			pcall(function()
				connection:Disconnect()
			end)
		end
	end
end

local function addConnection(connections, signal, callback)
	if not signal then
		return
	end

	local ok, connection = pcall(function()
		return signal:Connect(callback)
	end)

	if ok and connection then
		table.insert(connections, connection)
	end
end

local function getSignal(instance, signalName)
	local ok, signal = pcall(function()
		return instance[signalName]
	end)

	if ok then
		return signal
	end

	return nil
end

local function getPropertySignal(instance, propertyName)
	local ok, signal = pcall(function()
		return instance:GetPropertyChangedSignal(propertyName)
	end)

	if ok then
		return signal
	end

	return nil
end

local function markDirty()
	state.dirty = true

	if not state.running or state.flushQueued then
		return
	end

	state.flushQueued = true

	local generation = state.generation
	task.delay(state.writeDebounce, function()
		if state.generation ~= generation then
			return
		end

		state.flushQueued = false

		if state.running then
			flushLog(false)
		end
	end)
end

local function upsertPlayer(player)
	local userId = getPlayerUserId(player)

	if not userId then
		return nil
	end

	local record = state.historyByUserId[userId]
	local changed = false

	if not record then
		record = {
			UserId = userId,
			DisplayName = "Unknown",
			Username = "@Unknown",
			Characters = {},
			Skills = {},
		}

		state.historyByUserId[userId] = record
		changed = true
	end

	local displayName, username = getPlayerIdentity(player)

	if record.DisplayName ~= displayName then
		record.DisplayName = displayName
		changed = true
	end

	if record.Username ~= username then
		record.Username = username
		changed = true
	end

	if changed then
		markDirty()
	end

	return record
end

local function recordCharacter(player, characterName)
	local record = upsertPlayer(player)
	local normalizedName = trim(characterName)

	if not record or not normalizedName or record.Characters[normalizedName] then
		return false
	end

	record.Characters[normalizedName] = true
	markDirty()

	return true
end

local function recordSkill(player, skillName)
	local record = upsertPlayer(player)
	local normalizedName = trim(skillName)

	if not record or not normalizedName then
		return false
	end

	local changed = false

	if not record.Skills[normalizedName] then
		record.Skills[normalizedName] = true
		changed = true
	end

	if not state.allSkills[normalizedName] then
		state.allSkills[normalizedName] = true
		changed = true
	end

	if changed then
		markDirty()
	end

	return changed
end

local function sortedSetValues(set)
	local values = {}

	for value in pairs(set) do
		table.insert(values, value)
	end

	table.sort(values, function(left, right)
		local leftLower = string.lower(left)
		local rightLower = string.lower(right)

		if leftLower == rightLower then
			return left < right
		end

		return leftLower < rightLower
	end)

	return values
end

local function appendSet(lines, set)
	for _, value in ipairs(sortedSetValues(set)) do
		table.insert(lines, "- " .. value)
	end
end

local function buildLogText()
	local lines = {
		"==================================================",
		"SERVER HISTORY LOGGER",
		"==================================================",
		"",
		"Server Start:",
		state.startedAtText,
		"",
		"Total Runtime:",
		formatRuntime(),
		"",
		"",
		"==================================================",
		"ALL SKILLS",
		"==================================================",
		"",
	}

	appendSet(lines, state.allSkills)

	table.insert(lines, "")
	table.insert(lines, "")
	table.insert(lines, "==================================================")
	table.insert(lines, "PLAYERS")
	table.insert(lines, "==================================================")
	table.insert(lines, "")

	local records = {}

	for _, record in pairs(state.historyByUserId) do
		table.insert(records, record)
	end

	table.sort(records, function(left, right)
		return left.UserId < right.UserId
	end)

	for index, record in ipairs(records) do
		table.insert(lines, "[Player]")
		table.insert(lines, "DisplayName: " .. record.DisplayName)
		table.insert(lines, "Username: " .. record.Username)
		table.insert(lines, "UserId: " .. tostring(record.UserId))
		table.insert(lines, "")
		table.insert(lines, "Characters/")
		appendSet(lines, record.Characters)
		table.insert(lines, "")
		table.insert(lines, "Skills/")
		appendSet(lines, record.Skills)

		if index < #records then
			table.insert(lines, "")
			table.insert(lines, "")
		end
	end

	table.insert(lines, "")

	return table.concat(lines, "\n")
end

local function buildLogPath(separator, sequence)
	local date = state.startedDate
	local suffix = sequence > 1 and ("_" .. tostring(sequence)) or ""
	local fileName = string.format(
		"%04d_%02d_%02d_%02d%s%02d_Host_server%s.txt",
		tonumber(date.year) or 1970,
		tonumber(date.month) or 1,
		tonumber(date.day) or 1,
		tonumber(date.hour) or 0,
		separator,
		tonumber(date.min) or 0,
		suffix
	)

	return state.folderName .. "/" .. fileName
end

local function tryWrite(path, text)
	local ok, writeError = pcall(function()
		state.fileSystem.writeFile(path, text)
	end)

	if ok then
		return true
	end

	return false, tostring(writeError)
end

local function writeNewLogFile(separator, text)
	for sequence = 1, 10000 do
		local path = buildLogPath(separator, sequence)
		local checked, existsOrError = pcall(function()
			return state.fileSystem.isFile(path)
		end)

		if not checked then
			return nil, "isfile failed for " .. path .. ": " .. tostring(existsOrError)
		end

		if not existsOrError then
			local written, writeError = tryWrite(path, text)

			if written then
				return path
			end

			return nil, writeError
		end
	end

	return nil, "Could not find an unused log filename."
end

local function ensureLogFolder()
	local makeFolder = state.fileSystem.makeFolder
	local isFolder = state.fileSystem.isFolder

	if isFolder then
		local checked, existsOrError = pcall(function()
			return isFolder(state.folderName)
		end)

		if not checked then
			return false, "isfolder failed: " .. tostring(existsOrError)
		end

		if existsOrError then
			return true
		end

		local made, makeError = pcall(function()
			makeFolder(state.folderName)
		end)

		if not made then
			return false, "makefolder failed: " .. tostring(makeError)
		end

		return true
	end

	-- Some executors do not expose isfolder.  makefolder may report that the
	-- directory already exists; either outcome is safe to continue from.
	pcall(function()
		makeFolder(state.folderName)
	end)

	return true
end

local function prepareFileLogging()
	state.fileSystem = {
		writeFile = getExecutorFunction("writefile"),
		isFile = getExecutorFunction("isfile"),
		makeFolder = getExecutorFunction("makefolder"),
		isFolder = getExecutorFunction("isfolder"),
	}

	local missing = {}

	if type(state.fileSystem.writeFile) ~= "function" then
		table.insert(missing, "writefile")
	end

	if type(state.fileSystem.isFile) ~= "function" then
		table.insert(missing, "isfile")
	end

	if type(state.fileSystem.makeFolder) ~= "function" then
		table.insert(missing, "makefolder")
	end

	if #missing > 0 then
		report(table.concat(missing, ", ") .. " is unavailable. File logging disabled.")
		state.fileLoggingEnabled = false
		return
	end

	local ready, folderError = ensureLogFolder()

	if not ready then
		report(folderError .. " File logging disabled.")
		state.fileLoggingEnabled = false
		return
	end

	state.fileLoggingEnabled = true
end

flushLog = function(force)
	if not state.fileLoggingEnabled then
		return false
	end

	if not force and not state.dirty then
		return true
	end

	local text = buildLogText()

	if state.logPath then
		local written, writeError = tryWrite(state.logPath, text)

		if written then
			state.dirty = false
			return true
		end

		report("Failed to update log file: " .. tostring(writeError))
		return false
	end

	local path, primaryError = writeNewLogFile(":", text)

	if path then
		state.logPath = path
		state.logPathStyle = ":"
		state.dirty = false
		print("[ServerLogger] Writing to " .. path)
		return true
	end

	local fallbackPath, fallbackError = writeNewLogFile("-", text)

	if fallbackPath then
		state.logPath = fallbackPath
		state.logPathStyle = "-"
		state.dirty = false
		print("[ServerLogger] Writing to " .. fallbackPath)
		return true
	end

	report(
		"Could not create a log file. Primary error: "
			.. tostring(primaryError)
			.. " | Fallback error: "
			.. tostring(fallbackError)
	)
	state.fileLoggingEnabled = false

	return false
end

local function isTool(instance)
	local ok, result = pcall(function()
		return instance:IsA("Tool")
	end)

	return ok and result
end

local function isBackpack(instance)
	local ok, result = pcall(function()
		return instance:IsA("Backpack")
	end)

	return ok and result
end

local function getInstanceName(instance)
	local ok, name = pcall(function()
		return instance.Name
	end)

	if ok then
		return trim(name)
	end

	return nil
end

local function getAttribute(instance, attributeName)
	local ok, value = pcall(function()
		return instance:GetAttribute(attributeName)
	end)

	if ok then
		return value
	end

	return nil
end

local function scanCharacterAttributes(player, character)
	upsertPlayer(player)

	for attributeName in pairs(state.characterAttributeNames) do
		recordCharacter(player, getAttribute(player, attributeName))

		if character then
			recordCharacter(player, getAttribute(character, attributeName))
		end
	end
end

local function scanContainerForTools(player, container)
	if not container then
		return
	end

	local ok, children = pcall(function()
		return container:GetChildren()
	end)

	if not ok then
		return
	end

	for _, child in ipairs(children) do
		if isTool(child) then
			recordSkill(player, getInstanceName(child))
		end
	end
end

local function getCurrentBackpack(player)
	local ok, backpack = pcall(function()
		return player:FindFirstChildOfClass("Backpack")
	end)

	if ok then
		return backpack
	end

	return nil
end

local function bindingIsCurrent(binding)
	return state.running and state.playerBindings[binding.player] == binding
end

local function detachCharacter(binding)
	disconnectConnections(binding.characterConnections)
	binding.character = nil
	binding.characterToken = binding.characterToken + 1
end

local function detachBackpack(binding)
	disconnectConnections(binding.backpackConnections)
	binding.backpack = nil
end

local function attachCharacter(binding, character)
	detachCharacter(binding)

	if not character or not bindingIsCurrent(binding) then
		return
	end

	binding.character = character
	local characterToken = binding.characterToken

	scanCharacterAttributes(binding.player, character)
	scanContainerForTools(binding.player, character)

	addConnection(
		binding.characterConnections,
		getSignal(character, "ChildAdded"),
		function(child)
			if bindingIsCurrent(binding)
				and binding.character == character
				and binding.characterToken == characterToken
				and isTool(child) then
				recordSkill(binding.player, getInstanceName(child))
			end
		end
	)

	-- Removed tools deliberately do not alter historical data.
	addConnection(binding.characterConnections, getSignal(character, "ChildRemoved"), function()
		-- History is append-only.
	end)

	addConnection(
		binding.characterConnections,
		getSignal(character, "AttributeChanged"),
		function(attributeName)
			if bindingIsCurrent(binding)
				and binding.character == character
				and binding.characterToken == characterToken
				and state.characterAttributeNames[attributeName] then
				scanCharacterAttributes(binding.player, character)
			end
		end
	)

	for _, delaySeconds in ipairs(RESPAWN_SCAN_DELAYS) do
		local generation = state.generation

		task.delay(delaySeconds, function()
			if state.generation ~= generation
				or not bindingIsCurrent(binding)
				or binding.character ~= character
				or binding.characterToken ~= characterToken then
				return
			end

			scanCharacterAttributes(binding.player, character)
			scanContainerForTools(binding.player, character)
		end)
	end
end

local function attachBackpack(binding, backpack)
	detachBackpack(binding)

	if not backpack or not bindingIsCurrent(binding) then
		return
	end

	binding.backpack = backpack
	scanContainerForTools(binding.player, backpack)

	addConnection(
		binding.backpackConnections,
		getSignal(backpack, "ChildAdded"),
		function(child)
			if bindingIsCurrent(binding)
				and binding.backpack == backpack
				and isTool(child) then
				recordSkill(binding.player, getInstanceName(child))
			end
		end
	)

	-- A Tool moving to Character is caught there; removal never erases history.
	addConnection(binding.backpackConnections, getSignal(backpack, "ChildRemoved"), function()
		-- History is append-only.
	end)
end

local function scanBinding(binding)
	if not bindingIsCurrent(binding) then
		return
	end

	upsertPlayer(binding.player)
	scanCharacterAttributes(binding.player, binding.character)
	scanContainerForTools(binding.player, binding.character)
	scanContainerForTools(binding.player, binding.backpack)
end

local function unwatchPlayer(player, scanBeforeDisconnect)
	local binding = state.playerBindings[player]

	if not binding then
		return
	end

	if scanBeforeDisconnect then
		scanBinding(binding)
	end

	disconnectConnections(binding.baseConnections)
	detachCharacter(binding)
	detachBackpack(binding)

	state.playerBindings[player] = nil
end

local function watchPlayer(player)
	if state.playerBindings[player] then
		return
	end

	local binding = {
		player = player,
		baseConnections = {},
		characterConnections = {},
		backpackConnections = {},
		character = nil,
		backpack = nil,
		characterToken = 0,
	}

	state.playerBindings[player] = binding
	upsertPlayer(player)

	addConnection(
		binding.baseConnections,
		getSignal(player, "CharacterAdded"),
		function(character)
			if bindingIsCurrent(binding) then
				attachCharacter(binding, character)
			end
		end
	)

	addConnection(
		binding.baseConnections,
		getSignal(player, "CharacterRemoving"),
		function(character)
			if bindingIsCurrent(binding) and binding.character == character then
				detachCharacter(binding)
			end
		end
	)

	addConnection(
		binding.baseConnections,
		getSignal(player, "ChildAdded"),
		function(child)
			if bindingIsCurrent(binding) and isBackpack(child) then
				attachBackpack(binding, child)
			end
		end
	)

	addConnection(
		binding.baseConnections,
		getSignal(player, "ChildRemoved"),
		function(child)
			if bindingIsCurrent(binding) and binding.backpack == child then
				detachBackpack(binding)
			end
		end
	)

	addConnection(
		binding.baseConnections,
		getSignal(player, "AttributeChanged"),
		function(attributeName)
			if bindingIsCurrent(binding) and state.characterAttributeNames[attributeName] then
				scanCharacterAttributes(binding.player, binding.character)
			end
		end
	)

	addConnection(
		binding.baseConnections,
		getPropertySignal(player, "DisplayName"),
		function()
			if bindingIsCurrent(binding) then
				upsertPlayer(binding.player)
			end
		end
	)

	addConnection(
		binding.baseConnections,
		getPropertySignal(player, "Name"),
		function()
			if bindingIsCurrent(binding) then
				upsertPlayer(binding.player)
			end
		end
	)

	local currentCharacter = nil
	local characterOk, characterOrError = pcall(function()
		return player.Character
	end)

	if characterOk then
		currentCharacter = characterOrError
	end

	if currentCharacter then
		attachCharacter(binding, currentCharacter)
	end

	local currentBackpack = getCurrentBackpack(player)

	if currentBackpack then
		attachBackpack(binding, currentBackpack)
	end
end

local function disconnectAllPlayerBindings()
	local players = {}

	for player in pairs(state.playerBindings) do
		table.insert(players, player)
	end

	for _, player in ipairs(players) do
		unwatchPlayer(player, false)
	end
end

local function resetSessionState()
	state.historyByUserId = {}
	state.allSkills = {}
	state.playerBindings = {}
	state.globalConnections = {}
	state.dirty = false
	state.flushQueued = false
	state.fileLoggingEnabled = false
	state.fileSystem = {}
	state.logPath = nil
	state.logPathStyle = nil
end

local function resetCharacterAttributeNames()
	state.characterAttributeNames = {}

	for _, attributeName in ipairs(CHARACTER_ATTRIBUTE_NAMES) do
		state.characterAttributeNames[attributeName] = true
	end
end

function Logger.Start()
	if state.running then
		return true
	end

	disconnectConnections(state.globalConnections)
	disconnectAllPlayerBindings()

	state.generation = state.generation + 1
	resetSessionState()
	resetCharacterAttributeNames()

	state.startedAt = getUnixTimestamp()
	state.startedDate = getLocalDate(state.startedAt)
	state.startedAtText = formatStartTime(state.startedDate)
	state.running = true

	prepareFileLogging()

	addConnection(
		state.globalConnections,
		getSignal(Players, "PlayerAdded"),
		function(player)
			if state.running then
				watchPlayer(player)
			end
		end
	)

	addConnection(
		state.globalConnections,
		getSignal(Players, "PlayerRemoving"),
		function(player)
			if state.running then
				-- Take one final event-driven snapshot of this player, then
				-- discard only live connections, never their history record.
				unwatchPlayer(player, true)
			end
		end
	)

	local ok, players = pcall(function()
		return Players:GetPlayers()
	end)

	if ok then
		for _, player in ipairs(players) do
			watchPlayer(player)
		end
	end

	-- Create the session log immediately.  Later updates rewrite only this
	-- logger's own unique file rather than creating one file per tool event.
	flushLog(true)

	if state.fileLoggingEnabled then
		print("[ServerLogger] Started.")
	else
		report("Started in memory-only mode.")
	end

	return true
end

function Logger.Stop()
	if not state.running then
		return false
	end

	state.running = false
	state.generation = state.generation + 1
	state.flushQueued = false

	disconnectConnections(state.globalConnections)
	disconnectAllPlayerBindings()

	-- force = true updates Total Runtime even if no recent data changed.
	local flushed = flushLog(true)

	if flushed then
		print("[ServerLogger] Stopped. Final log flush completed.")
	elseif state.fileLoggingEnabled then
		report("Stopped, but the final log flush failed.")
	else
		report("Stopped. File logging was disabled.")
	end

	return flushed
end

function Logger.RecordCharacter(player, characterName)
	if not state.running then
		return false
	end

	return recordCharacter(player, characterName)
end

function Logger.RecordSkill(player, skillName)
	if not state.running then
		return false
	end

	return recordSkill(player, skillName)
end

function Logger.IsRunning()
	return state.running
end

function Logger.GetLogPath()
	return state.logPath
end

if sharedEnvironment then
	pcall(function()
		sharedEnvironment.__ServerHistoryLogger = Logger
	end)
end

return Logger
