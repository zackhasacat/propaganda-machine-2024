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

local CHUNK_SIZE = 6240
local NUM_CHUNKS = 5

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
  -- If UsedChunkPositions is empty, start at the origin
  if #UsedChunkPositions == 0 then
    local direction = getNextChunkDirection()
    local newPosition = getNextChunkPosition(direction, util.vector3(0, 0, 0))
    table.insert(UsedChunkPositions, newPosition)
    return direction, newPosition
  end

  -- Create a copy of UsedChunkPositions
  local positionsCopy = {}
  for _, pos in ipairs(UsedChunkPositions) do
    table.insert(positionsCopy, pos)
  end

  -- Randomly check positions around each used chunk
  while #positionsCopy > 0 do
    local posIndex = math.random(#positionsCopy)
    local usedPosition = table.remove(positionsCopy, posIndex)

    local directions = {"north", "south", "east", "west"}
    while #directions > 0 do
      local dirIndex = math.random(#directions)
      local direction = table.remove(directions, dirIndex)
      local newPosition = getNextChunkPosition(direction, usedPosition)

      -- Check if this new position is already used
      local isUsed = false
      for _, checkPosition in ipairs(UsedChunkPositions) do
        if newPosition.x == checkPosition.x and newPosition.y == checkPosition.y then
          isUsed = true
          break
        end
      end

      -- If not used, we've found our new position
      if not isUsed then
        table.insert(UsedChunkPositions, newPosition)
        return direction, newPosition
      end
    end
  end

  -- If we've checked all positions and found none, something's wrong
  error("No available positions found. This should never happen!")
end

local function clearDungeon()
      for _, object in pairs(world.players[1].cell:getAll()) do object:remove() end
      CursorPosition = util.vector3(0, 0, 0)
      UsedChunkPositions = {}
end

local function generateDungeon()
  clearDungeon()

  table.insert(UsedChunkPositions, util.vector3(0, 0, 0))

  local targetCell = world.players[1].cell.name

  for _=0, NUM_CHUNKS do

    local templateCell = cells[math.random(#cells)]

    generateCell{ cellId = templateCell, targetCell = targetCell, cursorPosition = CursorPosition }

    local direction, nextPos = getNextAvailableChunkPosition()

    print("Next position will be: ", nextPos.x, nextPos.y, ", used direction was: ", direction)

    CursorPosition = nextPos

  end

end

return {
  interfaceName = "s3_Rogue",
  interface = {
    clearDungeon = clearDungeon,
    generateDungeon = generateDungeon,
  },
}
