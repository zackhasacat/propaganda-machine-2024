local util = require('openmw.util')
local world = require('openmw.world')

local cells = {
  "PD_Twisty",
  "PD_Twisty_Alt",
  "Claustro",
}

local AXIS_LENGTH = 6240
-- local CHUNK_SIZE = util.vector2(AXIS_LENGTH, AXIS_LENGTH)

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

      table.insert(UsedChunkPositions, cellData.cursorPosition)
end

--- Determines the cardinal direction for the next chunk.
-- @return string The cardinal direction: "north", "south", "east", or "west".
local function getNextChunkDirection()
  local directions = {"north", "south", "east", "west"}
  return directions[math.random(#directions)]
end

--- Calculates the new cursor position based on the given direction.
-- @param direction string The cardinal direction: "north", "south", "east", or "west".
-- @return util.vector3 The new cursor position.
local function getNextChunkPosition(direction)

  assert(direction == "north" or direction == "south" or direction == "east" or direction == "west", "Invalid direction provided: " .. direction)

  if direction == "north" then
    return util.vector3(CursorPosition.x, CursorPosition.y + AXIS_LENGTH, CursorPosition.z)
  elseif direction == "south" then
    return util.vector3(CursorPosition.x, CursorPosition.y - AXIS_LENGTH, CursorPosition.z)
  elseif direction == "east" then
    return util.vector3(CursorPosition.x + AXIS_LENGTH, CursorPosition.y, CursorPosition.z)
  elseif direction == "west" then
    return util.vector3(CursorPosition.x - AXIS_LENGTH, CursorPosition.y, CursorPosition.z)
  end
end

--- Finds the next available chunk position that hasn't been used.
-- @return util.vector3 The position of the next available chunk.
local function getNextAvailableChunkPosition()

  local function isPositionUsed(position)
    for _, usedPosition in ipairs(UsedChunkPositions) do
      if position.x == usedPosition.x and position.y == usedPosition.y then
        return true
      end
    end
    return false
  end

  while true do
    local direction = getNextChunkDirection()
    local newPosition = getNextChunkPosition(direction)

    if not isPositionUsed(newPosition) then
      table.insert(UsedChunkPositions, newPosition)
      return newPosition
    end
  end
end

local function generateDungeon(cellId)
  assert(type(cellId) == "string", "First argument must be a string!")
  local targetCell = world.players[1].cell.name

  for _=1, 7 do

    generateCell{ cellId = cellId, targetCell = targetCell, cursorPosition = CursorPosition }

    local nextPos = getNextAvailableChunkPosition()

    print("Next position will be: ", nextPos.x, nextPos.y)

    CursorPosition = nextPos

  end

end

return {
  interfaceName = "s3_Rogue",
  interface = {
    generateDungeon = generateDungeon,
  },
}
