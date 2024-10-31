local core = require('openmw.core')
local time = require('openmw_aux.time')
local types = require('openmw.types')
local util = require('openmw.util')
local world = require('openmw.world')

local procGenData = require('Scripts.s3.rogue.procGenData')
local szudzik = require('Scripts.s3.rogue.szudzik')

local NUM_CHUNKS = 500
local BATCH_MAX = 25

local SPAWN_DELAY = 1 * time.second

local DELETE_CHUNKS = 300
local DELETE_DELAY = 0.25 * time.second

local MAP_OR_BARRIER_PCT = 60
local EDGE_SPAWN_CHANCE = 75

local CursorPosition = util.vector3(0, 0, 0)

local totalChunks
local UsedChunkPositions = {}

local visitedChunks = {}

local numChunksVisited = 0
local prevChunkCoords

--- Generates a new cell based on the data from an existing cell.
--- Stores the used chunk position in a table so it can't be reused.
-- @param cellData Table containing information about the source and target cells.
-- @param cellData.cellId The ID of the source cell to copy from.
-- @param cellData.targetCell The target cell to teleport objects to.
-- @param cellData.cursorPosition The offset position for teleported objects.
local function generateCell(cellData)
      local cell = world.getCellById(cellData.cellId)

      for _, object in pairs(cell:getAll()) do
        world.createObject(object.recordId)
          :teleport(cellData.targetCell, object.position + cellData.cursorPosition, object.rotation)
      end
end

--- Determines the cardinal direction for the next chunk.
-- @return string The cardinal direction: "north", "south", "east", or "west".
local function getNextChunkDirection()
  local directions = {"north", "south", "east", "west"}
  return directions[math.random(#directions)]
end

--- Calculates the new cursor position based on the given direction.
-- @param direction string The cardinal direction: "north", "south", "east", or "west".
-- @param position util.vector3 The reference position to move from
-- @return util.vector3 The new cursor position.
local function getNextChunkPosition(direction, position)
  assert(direction == "north" or direction == "south" or direction == "east" or direction == "west", "Invalid direction provided: " .. direction)

  if direction == "north" then
    return util.vector3(position.x, position.y + procGenData.CHUNK_SIZE, position.z)
  elseif direction == "south" then
    return util.vector3(position.x, position.y - procGenData.CHUNK_SIZE, position.z)
  elseif direction == "east" then
    return util.vector3(position.x + procGenData.CHUNK_SIZE, position.y, position.z)
  elseif direction == "west" then
    return util.vector3(position.x - procGenData.CHUNK_SIZE, position.y, position.z)
  end
end

--- Calculates the new cursor position based on the given direction.
-- @param direction string The cardinal direction: "north", "south", "east", or "west".
-- @param position util.vector3 The reference position to move from
-- @return util.vector3 Position of the transition room .
local function getTransitionRoomPosition(direction, position)
  assert(direction == "north" or direction == "south" or direction == "east" or direction == "west", "Invalid direction provided: " .. direction)

  if direction == "north" then
    return util.vector3(position.x, position.y - ( procGenData.CHUNK_SIZE / 2 ), position.z)
  elseif direction == "south" then
    return util.vector3(position.x, position.y + ( procGenData.CHUNK_SIZE  / 2 ), position.z)
  elseif direction == "east" then
    return util.vector3(position.x - ( procGenData.CHUNK_SIZE  / 2 ), position.y, position.z)
  elseif direction == "west" then
    return util.vector3(position.x + ( procGenData.CHUNK_SIZE / 2 ) , position.y, position.z)
  end
end

--- Finds the next available chunk position that hasn't been used.
-- @return string, util.vector3 The direction and position of the next available chunk.
local function getNextAvailableChunkPosition()

  if #UsedChunkPositions == 0 then
    local direction = getNextChunkDirection()
    local newPosition = getNextChunkPosition(direction, util.vector3(0, 0, 0))
    return direction, newPosition
  end

  local positionsCopy = {}
  for _, chunkObject in ipairs(UsedChunkPositions) do
    table.insert(positionsCopy, chunkObject.position)
  end

  while #positionsCopy > 0 do
    local posIndex = math.random(#positionsCopy)
    local usedPosition = table.remove(positionsCopy, posIndex)

    local directions = {"north", "south", "east", "west"}
    while #directions > 0 do
      local dirIndex = math.random(#directions)
      local direction = table.remove(directions, dirIndex)
      local newPosition = getNextChunkPosition(direction, usedPosition)

      local isUsed = false
      for _, chunkObject in ipairs(UsedChunkPositions) do
        local checkPosition = chunkObject.position
        if newPosition.x == checkPosition.x and newPosition.y == checkPosition.y then
          isUsed = true
          break
        end
      end

      if not isUsed then
        return direction, newPosition
      end
    end
  end

  error("No available positions found. This should never happen!")
end

local positionsWithTransitions = {}
local clearStopFn
local function clearDungeon(createNew, chunksToGenerate)
  local cellObjects = world.players[1].cell:getAll()
  local numObjects = #cellObjects

  local chunkData = {
    chunksToGenerate = chunksToGenerate or NUM_CHUNKS,
  }

  if numObjects == 0 then
    if createNew == true then core.sendGlobalEvent('s3_Rogue_generateDungeon', chunkData) end
    return
  end

  local numDeleted = 0

  clearStopFn = time.runRepeatedly(function()
      if numDeleted <= numObjects then

        local deleteThisIteration = math.min(DELETE_CHUNKS, numObjects - numDeleted)

        for index=numDeleted, numDeleted + deleteThisIteration do
          local target = cellObjects[index + 1]
          if target and target.type ~= types.Player then target:remove() end
        end

        numDeleted = numDeleted + deleteThisIteration + 1

      else
        clearStopFn()
        CursorPosition = util.vector3(0, 0, 0)
        positionsWithTransitions = {}
        UsedChunkPositions = {}
        visitedChunks = {}
        numChunksVisited = 0
        prevChunkCoords = nil

        if createNew == true then core.sendGlobalEvent('s3_Rogue_generateDungeon', chunkData) end
      end
  end,
    DELETE_DELAY)
end

local function randomTransitionCell(direction)
  local transitionCellTemplate
  local transitionCellIndex

  if direction == 'west' or direction == 'east' then
    transitionCellIndex = math.random(1, #procGenData.transitions.horizontal)
    transitionCellTemplate = procGenData.transitions.horizontal[transitionCellIndex]
  else
    transitionCellIndex = math.random(1, #procGenData.transitions.vertical)
    transitionCellTemplate = procGenData.transitions.vertical[transitionCellIndex]
  end

  return transitionCellTemplate
end

local function positionHasTransition(position)
  for _, usedPosition in pairs(positionsWithTransitions) do
    if position == usedPosition then return true end
  end

  return false
end

local function positionHasChunk(position)
  for _, chunkObject in pairs(UsedChunkPositions) do
    if position == chunkObject.position then return true end
  end

  return false
end

local function randomEdgeCell(direction)
  return procGenData.edges[direction][math.random(1, #procGenData.edges[direction])]
end

local function randomBarrierCell()
  return procGenData.edgeBarriers[math.random(1, #procGenData.edgeBarriers)]
end

local function getTemplateCell(cellId)
  for _, templateObject in ipairs(procGenData.templateCells) do
    if cellId == templateObject.cellId then return templateObject end
  end
  error("Requested a template cell which doesn't exist: ", cellId)
end

local function generateEdgeRooms()
  for _, chunkObject in ipairs(UsedChunkPositions) do

    local directions = { "north", "south", "east", "west" }

    for _, direction in pairs(directions) do
      if math.random(100) <= EDGE_SPAWN_CHANCE then
        local adjacentChunkPosition = getNextChunkPosition(direction, chunkObject.position)

        if not positionHasChunk(adjacentChunkPosition) then

          local spawnRoomOrBarrier = math.random(100) >= MAP_OR_BARRIER_PCT
          local targetCell = getTemplateCell(chunkObject.cellId)
          local transitionRoomPosition = getTransitionRoomPosition(direction, adjacentChunkPosition)

          if spawnRoomOrBarrier and targetCell.edges[direction] then
            generateCell { cellId = randomEdgeCell(direction),
              targetCell = world.players[1].cell.name, cursorPosition = transitionRoomPosition }
          elseif not spawnRoomOrBarrier and targetCell.barriers[direction] then
            generateCell { cellId = randomBarrierCell(),
              targetCell = world.players[1].cell.name, cursorPosition = transitionRoomPosition }
          end

        end
      end
    end
  end
end

local function generateTransitionRooms()
  positionsWithTransitions[#positionsWithTransitions] = util.vector3(0, 0, 0)
  for _, chunkObject in ipairs(UsedChunkPositions) do

    local directions = { "north", "south", "east", "west" }

    for _, direction in pairs(directions) do

      local adjacentChunkPosition = getNextChunkPosition(direction, chunkObject.position)

      for _, adjacentChunkObject in ipairs(UsedChunkPositions) do

        if adjacentChunkObject.position == adjacentChunkPosition then

          local transitionRoomPosition = getTransitionRoomPosition(direction, adjacentChunkObject.position)

          if not positionHasTransition(transitionRoomPosition) then

            generateCell{ cellId = randomTransitionCell(direction),
                          targetCell = world.players[1].cell.name, cursorPosition = transitionRoomPosition }

            positionsWithTransitions[#positionsWithTransitions + 1] = transitionRoomPosition

          end

        end

      end

    end
  end

  core.sendGlobalEvent('s3_Rogue_generateEdgeRooms')
end

local GenerateStopFn
local chunksRemaining

local function spawnChunk(isLastChunk)

  local templateCell = procGenData.templateCells[math.random(#procGenData.templateCells)].cellId

  local targetCell = world.players[1].cell.name

  generateCell{ cellId = templateCell, targetCell = targetCell, cursorPosition = CursorPosition }

  UsedChunkPositions[#UsedChunkPositions + 1] = { position = CursorPosition, cellId = templateCell }

  if isLastChunk then return end

  local _, nextPos = getNextAvailableChunkPosition()
  CursorPosition = nextPos
end

local function generateTimedChunk()
  local chunksThisBatch = math.min(chunksRemaining, BATCH_MAX)

  for chunkThisBatch = 1, math.min(chunksRemaining, BATCH_MAX) do
    spawnChunk(chunkThisBatch - chunksRemaining == 0)
  end

  chunksRemaining = chunksRemaining - chunksThisBatch

  if chunksRemaining <= 0 then
    GenerateStopFn()
    core.sendGlobalEvent('s3_Rogue_generateTransitionRooms')
  end
end

local function generateDungeon(chunkData)
  totalChunks = chunkData.chunksToGenerate or procGenData.NUM_CHUNKS
  chunksRemaining = totalChunks

  GenerateStopFn = time.runRepeatedly(generateTimedChunk, SPAWN_DELAY)
end

local function hasVisitedChunk(szudzikCoord)
  assert(szudzikCoord ~= nil, "Cannot check grid coordinates that do not exist!")
  return visitedChunks[szudzikCoord] ~= nil
end

local function markChunkAsVisited(szudzikCoord)
  assert(visitedChunks[szudzikCoord] == nil,
         "Chunk should never be marked as visited more than once")

  local originalX, originalY = szudzik.unpair(szudzikCoord)

  local chunkCoords = util.vector3(originalX, originalY, 0) * procGenData.CHUNK_SIZE

  visitedChunks[szudzikCoord] = true

  numChunksVisited = numChunksVisited + 1
end

local function getNearestChunkPosition(pos)
  local chunkPos = pos.xy / (procGenData.CHUNK_SIZE)
  return szudzik.getIndex(util.round(chunkPos.x), util.round(chunkPos.y))
end

return {
  interfaceName = "s3_Rogue_G",
  interface = {
    clearDungeon = clearDungeon,
    procGenData = procGenData,
  },
  engineHandlers = {
    onSave = function()
      return {
        totalChunks = totalChunks,
        visitedChunks = visitedChunks,
        numChunksVisited = numChunksVisited,
      }
    end,
    onLoad = function(state)
      totalChunks = state.totalChunks or procGenData.NUM_CHUNKS
      visitedChunks = state.visitedChunks or {}
      numChunksVisited = state.numChunksVisited or 0
    end,
    onUpdate = function(_dt)
      for index, player in ipairs(world.players) do

        local szudzikCoord = getNearestChunkPosition(player.position)
        if not hasVisitedChunk(szudzikCoord) then markChunkAsVisited(szudzikCoord) end

        if not prevChunkCoords then
          print(string.format("Player %d entered the dungeon at (Szudzik) %d", index, szudzikCoord))
        elseif prevChunkCoords ~= szudzikCoord then
          print(string.format("Player %d moved to (szudzik) chunk %d from %d, dungeon is %.02f%% complete", index,
                              szudzikCoord, prevChunkCoords, numChunksVisited / totalChunks))
        end

        prevChunkCoords = szudzikCoord

      end
    end,
  },
  eventHandlers = {
    s3_Rogue_generateDungeon = generateDungeon,
    s3_Rogue_generateEdgeRooms = generateEdgeRooms,
    s3_Rogue_generateTransitionRooms = generateTransitionRooms,
  }
}
