local ambient = require('openmw.ambient')
local postprocessing = require('openmw.postprocessing')
local self = require('openmw.self')

local musicFileName = "Sound\\PD\\Music\\5-minutes-of-silence.mp3"

local prevCellId

local shaderDataFade
local shaderDataFog
local shaderOn = false

local lerpSpeed = 0.2
local uStrength = 1.0

local saveData = {
    isInModSpace = false
}

local shaderConfig = {
    ['Fields of Regret'] = {
        fade = {
            uStrength = 1.0
        },
        fog = {
            uFogHeight = 10000,
            uFogDensity = .001
        },
    },
    ['The Vile Playground'] = {
        fade = {
            uStrength = 1.0
        },
        fog = {
            uFogHeight = 1300,
            uFogDensity = .012
        },
    },
}

local function enableShader(isFog, clavCell)
    assert(isFog ~= nil, "Cannot enable shader without specifying shader type!")
    assert(clavCell ~= nil, "Cannot enable shader without specifying the associated PD Cell!")

    shaderOn = true

    if isFog then
        shaderDataFog = postprocessing.load("PD_Fog")
        shaderDataFog:enable(2)

        for attr, value in pairs(shaderConfig[clavCell].fog) do
            shaderDataFade:setFloat(attr, value)
        end
    else
        uStrength = shaderConfig[clavCell].fade.uStrength
        shaderDataFade = postprocessing.load("PD_Fade")
        shaderDataFade:enable()

        for attr, value in pairs(shaderConfig[clavCell].fade) do
            shaderDataFade:setFloat(attr, value)
        end
    end
end

local function enableShaders(clavCell)
    assert(shaderConfig[clavCell] ~= nil, "Cannot enable PD shaders for a non-PD or unspecified cell!")
    enableShader(false, clavCell)
    enableShader(true, clavCell)
end

local function disableShader(isFog)
    assert(shaderOn == true, "Cannot disable shaders as they are already off!")
    assert((isFog and shaderDataFog) or (not isFog and shaderDataFade)
        , "Cannot disable", (isFog and 'fog' or 'fade'), "shader, it is already off!")

    if isFog and shaderDataFog then
        shaderDataFog:disable()
        shaderDataFog = nil
    elseif not isFog and shaderDataFade then
        shaderDataFade:disable()
        shaderDataFade = nil
    end

    if not shaderDataFade and not shaderDataFog then shaderOn = false end
end

local function disableShaders()
    assert(shaderOn == true, "Cannot disable shaders if they are already off!")
    if shaderDataFog then disableShader(true) end
    if shaderDataFade then disableShader(false) end
end

local function inModSpace(cellName)
    for pdCell, _ in pairs(shaderConfig) do
        if string.find(cellName, pdCell) then return pdCell end
    end
end

local function onCellChange(cellName)
    local clavRealmCell = inModSpace(cellName)

    if clavRealmCell then
        enableShaders(clavRealmCell)
        if ambient.isMusicPlaying() then ambient.streamMusic(musicFileName) end
        saveData.isInModSpace = true
    else
        if saveData.isInModSpace and ambient.isMusicPlaying then
            ambient.stopMusic()
            saveData.isInModSpace = false
        end
        if shaderOn then disableShaders() end
    end
end

local function onUpdate()
    if self.cell.id ~= prevCellId then
        onCellChange(self.cell.name)
    end
    prevCellId = self.cell.id
end

local function fadeIn(dt)
    if not shaderOn or not shaderDataFade then return end

    uStrength = math.max(0.0, uStrength - dt * lerpSpeed)

    if uStrength > 0.0 then
        shaderDataFade:setFloat("uStrength", uStrength)
    else
        disableShader(false)
    end
end

local function onFrame(dt)
    fadeIn(dt)
end

return {
    engineHandlers = {
        onFrame = onFrame,
        onUpdate = onUpdate,
        onSave = function () return saveData end,
        onLoad = function (data)
            if not data then return end

            saveData.isInModSpace = data.isInModSpace or false
        end,
    }
}
