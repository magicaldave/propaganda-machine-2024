local ambient = require('openmw.ambient')
local postprocessing = require('openmw.postprocessing')
local self = require('openmw.self')

local musicStop = true
local musicStopped = false
local musicFileName = "Sound\\PD\\Music\\5-minutes-of-silence.mp3"

local shaderOn = false
local shaderDataFog
local shaderDataFade
local uStrength = 1.0            -- Start fully enabled
local lerpSpeed = 0.2            -- Adjust this value for the fade-out speed
local shaderFadeComplete = false -- Track if fade-out is complete

local isInModSpace = false

local function enableFadeShader()
    shaderOn = true
    shaderDataFade = postprocessing.load("PD_Fade")
    shaderDataFade:enable()
    shaderDataFade:setFloat("uStrength", uStrength)
end
local function enableFogShader()
    shaderOn = true
    shaderDataFog = postprocessing.load("PD_Fog")
    shaderDataFog:enable(2)
    shaderDataFog:setFloat("uFogHeight",10000)
    shaderDataFog:setFloat("uFogDensity",0.001)
end
local function disableFogShader()
    if shaderDataFog then
        shaderDataFog:disable()
        shaderDataFog = nil
    end
end
local function disableFadeShader()
    if shaderDataFade then
        shaderDataFade:disable()
        shaderDataFade = nil
    end
    --shaderOn = false
    shaderFadeComplete = true -- Mark fade-out as complete
   -- enableFogShader()
end
local cellNamespace = "Fields of Regret"
local function startsWith(str, prefix) --Checks if a string starts with another string
    return string.sub(str, 1, string.len(prefix)) == prefix
end
local function onCellChange(newCell)
    if startsWith(newCell.name, cellNamespace) then
        isInModSpace = true
        --entered TFOR

        -- Enable shader only if it hasn’t been faded out yet
        if not shaderOn and not shaderFadeComplete then
            enableFadeShader()
            enableFogShader()
        end
    else
        isInModSpace = false
        disableFogShader()
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
    if isInModSpace then
        if musicStop and ambient.isMusicPlaying() and not ambient.isSoundPlaying(musicFileName) then
            ambient.streamMusic(musicFileName)
        end
    end
    -- Gradually decrease uStrength down to 0.0, then disable the shader
    if shaderOn and shaderDataFade then
        uStrength = math.max(0.0, uStrength - dt * lerpSpeed) -- Lerp down to 0.0
        shaderDataFade:setFloat("uStrength", uStrength)

        if uStrength <= 0.0 then
            disableFadeShader() -- Disable shader once uStrength reaches 0.0
        end
    end
end

return {
    engineHandlers = {
        onFrame = onFrame,
        onUpdate = onUpdate,
        onSave = function ()
            return {
                isInModSpace = isInModSpace,
                shaderFadeComplete = shaderFadeComplete,
            }
        end,
        onLoad = function (data)
            if data then
                isInModSpace = data.isInModSpace
                shaderFadeComplete = data.shaderFadeComplete
            end
        end
    }
}
