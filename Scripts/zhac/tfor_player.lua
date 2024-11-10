local ambient = require('openmw.ambient')
local postprocessing = require('openmw.postprocessing')
local self = require('openmw.self')

local musicStop = true
local musicStopped = false
local musicFileName = "Sound\\PD\\Music\\5-minutes-of-silence.mp3"

local shaderOn = false
local shaderData
local uStrength = 1.0 -- Start fully enabled
local lerpSpeed = 0.2 -- Adjust this value for the fade-out speed
local shaderFadeComplete = false -- Track if fade-out is complete



local function enableShader()
    shaderOn = true
    shaderData = postprocessing.load("PD_Fade")
    shaderData:enable(self.position)
    shaderData:setFloat("uStrength", uStrength)
end

local function disableShader()
    if shaderData then
        shaderData:disable()
        shaderData = nil
    end
    shaderOn = false
    shaderFadeComplete = true -- Mark fade-out as complete
end
local cellNamespace = "Fields of Regret"
local function startsWith(str, prefix) --Checks if a string starts with another string
    return string.sub(str, 1, string.len(prefix)) == prefix
end
local function onCellChange(newCell)
    if startsWith(newCell.name,cellNamespace) then
        --entered TFOR
 
        -- Enable shader only if it hasn’t been faded out yet
        if not shaderOn and not shaderFadeComplete then
            enableShader()
        end
    
     
    end
end
local lastCellId
local function onUpdate(dt)
    if self.cell.id ~= lastCellId then
        onCellChange(self.cell)
    end
    lastCellId = self.cell.id
end

local function onFrame(dt)
    -- Check and handle music playback
    if musicStop and ambient.isMusicPlaying() and not ambient.isSoundPlaying(musicFileName) then
        ambient.streamMusic(musicFileName)
        musicStopped = true
    end
   -- Gradually decrease uStrength down to 0.0, then disable the shader
   if shaderOn then
    uStrength = math.max(0.0, uStrength - dt * lerpSpeed)  -- Lerp down to 0.0
    shaderData:setFloat("uStrength", uStrength)
    
    if uStrength <= 0.0 then
        disableShader()  -- Disable shader once uStrength reaches 0.0
    end
end
end

return {
    engineHandlers = {
        onFrame = onFrame,
        onUpdate = onUpdate,
    }
}
