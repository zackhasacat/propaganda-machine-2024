local core = require('openmw.core')
local time = require('openmw_aux.time')
local types = require('openmw.types')
local util = require('openmw.util')
local world = require('openmw.world')

local cells = {
  "pd_twisty",
  "pd_twisty_alt",
  "pd_zen",
  "pd_shaft",
  "pd_labyrinth",
  "claustro",
}

local CHUNK_SIZE = 6144
local NUM_CHUNKS = 500
local BATCH_MAX = 25

local SPAWN_DELAY = 1 * time.second

local DELETE_CHUNKS = 300
local DELETE_DELAY = 0.25 * time.second

local CursorPosition = util.vector3(0, 0, 0)

local UsedChunkPositions = {}

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
    return util.vector3(position.x, position.y + CHUNK_SIZE, position.z)
  elseif direction == "south" then
    return util.vector3(position.x, position.y - CHUNK_SIZE, position.z)
  elseif direction == "east" then
    return util.vector3(position.x + CHUNK_SIZE, position.y, position.z)
  elseif direction == "west" then
    return util.vector3(position.x - CHUNK_SIZE, position.y, position.z)
  end
end

--- Finds the next available chunk position that hasn't been used.
-- @return string, util.vector3 The direction and position of the next available chunk.
local function getNextAvailableChunkPosition()

  if #UsedChunkPositions == 0 then
    local direction = getNextChunkDirection()
    local newPosition = getNextChunkPosition(direction, util.vector3(0, 0, 0))
    table.insert(UsedChunkPositions, newPosition)
    return direction, newPosition
  end

  local positionsCopy = {}
  for _, pos in ipairs(UsedChunkPositions) do
    table.insert(positionsCopy, pos)
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
      for _, checkPosition in ipairs(UsedChunkPositions) do
        if newPosition.x == checkPosition.x and newPosition.y == checkPosition.y then
          isUsed = true
          break
        end
      end

      if not isUsed then
        table.insert(UsedChunkPositions, newPosition)
        return direction, newPosition
      end
    end
  end

  error("No available positions found. This should never happen!")
end

local clearStopFn
local function clearDungeon(createNew, chunksToGenerate)
  local cellObjects = world.players[1].cell:getAll()
  local numObjects = #cellObjects

  local chunkData = {
    chunksToGenerate = chunksToGenerate or NUM_CHUNKS,
  }

  if numObjects == 0 then
    if createNew == true then core.sendGlobalEvent('generateDungeon', chunkData) end
    return
  end

  local numDeleted = 0

  print("Cell currently has: ", numObjects, " objects.")

  clearStopFn = time.runRepeatedly(function()
      if numDeleted <= numObjects then

        local deleteThisIteration = math.min(DELETE_CHUNKS, numObjects - numDeleted)

        print("Deleting", deleteThisIteration, " objects this iteration")

        for index=numDeleted, numDeleted + deleteThisIteration do
          local target = cellObjects[index + 1]
          if target and target.type ~= types.Player then target:remove() end
        end

        numDeleted = numDeleted + deleteThisIteration + 1

      else
        print("All objects deleted, cell is clear for paving", numDeleted, numObjects)
        clearStopFn()
        CursorPosition = util.vector3(0, 0, 0)
        UsedChunkPositions = {}

        print("Chunk Data is: ", chunkData)

        if createNew == true then core.sendGlobalEvent('generateDungeon', chunkData) end
      end
  end,
    DELETE_DELAY)
end

local function spawnChunk()

  local templateCell = cells[math.random(#cells)]

  local targetCell = world.players[1].cell.name

  generateCell{ cellId = templateCell, targetCell = targetCell, cursorPosition = CursorPosition }

  local direction, nextPos = getNextAvailableChunkPosition()

  -- print("Next position will be: ", nextPos.x, nextPos.y, ", used direction was: ", direction)

  CursorPosition = nextPos
end

local GenerateStopFn

local function generateDungeon(chunkData)

  print(chunkData)

  table.insert(UsedChunkPositions, util.vector3(0, 0, 0))

  local chunksRemaining = chunkData.chunksToGenerate

  GenerateStopFn = time.runRepeatedly(function()

      if chunksRemaining <= 0 then
        GenerateStopFn()
      end

      local chunksThisBatch = math.min(chunksRemaining, BATCH_MAX)

      for _=1, math.min(chunksRemaining, BATCH_MAX) do
        spawnChunk()
      end

      chunksRemaining = chunksRemaining - chunksThisBatch
  end,
    SPAWN_DELAY)
end

return {
  interfaceName = "s3_Rogue",
  interface = {
    clearDungeon = clearDungeon,
  },
  eventHandlers = {
    generateDungeon = generateDungeon,
  }
}
