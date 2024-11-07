

local portalObjIds = {}--always shown
local dwemerObjIds = {}--only shown when dwemer is visible
local daedriObjIds = {}--only shown when daedric is visible


local world = require("openmw.world")
local util = require("openmw.util")
local types = require("openmw.types")
local activation = require('openmw.interfaces').Activation

local objectState = {portal = 0, dwemer = 1, daedric = 2}
local direction = {east = 1, west = 2, north = 3, south = 4}
local portalCell = "PortalTestCell"

local portalActive = false
local playerSide = objectState.dwemer

local portalThreshold = -842--if under, west, if over, east.

local function getEastWestObj(obj)
    if obj.position.x > portalThreshold then--east
        return  direction.east
    else
        return direction.west
    end
end
local function determineAreaFromZ(zPos)
    if zPos > 15296.000 then
        return objectState.portal--portal
    elseif zPos > 11712.000 then
        return objectState.dwemer--dwemer
    else
        return objectState.daedric--daedric
    end
end
local function getObjectState(obj)
    for index, value in ipairs(portalObjIds) do
        if value == obj.id then
            return objectState.portal
        end
    end
    for index, value in ipairs(dwemerObjIds) do
        if value == obj.id then
            return objectState.dwemer
        end
    end
    for index, value in ipairs(daedriObjIds) do
        if value == obj.id then
            return objectState.daedric
        end
    end
end
local function initPortalArea()
    if #dwemerObjIds > 0 then
        return
    end
    print("Init portal")
    local cellObjs = world.getCellById(portalCell):getAll()
    for index, obj in ipairs(cellObjs) do
        local zPos = obj.position.z
        local area = determineAreaFromZ(zPos)
        local zOffset = 0
        local newZPos = zPos
        if area == objectState.portal then--portal
            zOffset = 17074.574 - 13504.000
            newZPos = zPos - zOffset
            if #portalObjIds == 0 then
                print("portal",newZPos)
            end
            table.insert(portalObjIds,obj.id)

        elseif area == objectState.dwemer then
            if #dwemerObjIds == 0 then
                print("dwem",newZPos)
            end
            table.insert(dwemerObjIds,obj.id)
        elseif area == objectState.daedric then
            zOffset =8384.000 - 13504.000
            newZPos = zPos - zOffset
            if #daedriObjIds == 0 then
                print("dae",newZPos)
            end
            table.insert(daedriObjIds,obj.id)
            obj.enabled = false
        end
        if obj.recordId == ("BM_mazegate_02"):lower() then
            obj.enabled = false
        end
        if zOffset ~= 0 then
            local newPos = util.vector3(obj.position.x,obj.position.y,newZPos)
            obj:teleport(obj.cell,newPos)

        end
    end
end

local function updatePortalArea()
    local cellObjs = world.getCellById(portalCell):getAll()
    for index, obj in ipairs(cellObjs) do
        local state = getObjectState(obj)
        local eastWest = getEastWestObj(obj)
        if state == objectState.daedric and eastWest == direction.east then
            obj.enabled = true
        elseif state == objectState.dwemer and eastWest == direction.west then
            obj.enabled = true
        elseif state == objectState.portal then
            obj.enabled = true
        else
            obj.enabled = false
        end
        if obj.recordId == ("BM_mazegate_02"):lower() then
            obj.enabled = false
        end
    end
end

activation.addHandlerForType(types.Activator, function (obj)
    if obj.recordId == "zhac_portal_lever" then
        portalActive = not portalActive
        updatePortalArea()
    end
end)
return {
    engineHandlers = {
        onSave = function ()
            initPortalArea()
            return {
                portalObjIds = portalObjIds,
                dwemerObjIds = dwemerObjIds,
                daedriObjIds = daedriObjIds,
                portalActive = portalActive,
                playerSide = playerSide,
            }
        end,
        onLoad = function (data)
            if data then
                portalObjIds = data.portalObjIds
                dwemerObjIds = data.dwemerObjIds
                daedriObjIds = data.daedriObjIds
                portalActive = data.portalActive
                playerSide = data.playerSide
            end
        end,
        onInit = function ()
            initPortalArea()
        end
    }
}