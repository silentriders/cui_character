-- TODO: DELETE THIS ONCE WE ARE DONE
function dump(o)
    if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. dump(v) .. ','
    end
    return s .. '} '
    else
    return tostring(o)
    end
end

function dumpToChat(arg)
    local argVals
    if type(arg) == 'table' then
        argVals = {'Me', dump(arg)}
    else
        argVals = {'Me', arg}
    end 
    TriggerEvent('chat:addMessage', {
        color = { 255, 0, 0},
        multiline = true,
        args = argVals
    })
end
--------------------------------------

ESX = nil
local initialized = false

local isVisible = false
local playerLoaded = false
local firstSpawn = true
local identityLoaded = false

local currentChar = {}
local oldChar = {}

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

function setVisible(visible)
    SetNuiFocus(visible, visible)
    SendNUIMessage({
        action = 'setVisible',
        show = visible
    })
    isVisible = visible
end

AddEventHandler('cui_character:close', function(save)
    -- Saving and discarding changes
    if save then
        for k, v in pairs(oldChar) do
            oldChar[k] = currentChar[k]
        end
        TriggerServerEvent('cui_character:save', currentChar)
    else
        LoadCharacter(oldChar)
    end

    -- Release textures
    SetStreamedTextureDictAsNoLongerNeeded('mparrow')
    SetStreamedTextureDictAsNoLongerNeeded('mpleaderboard')
    if identityLoaded == true then
        SetStreamedTextureDictAsNoLongerNeeded('pause_menu_pages_char_mom_dad')
        SetStreamedTextureDictAsNoLongerNeeded('char_creator_portraits')
        identityLoaded = false
    end

    Camera.Deactivate()
    setVisible(false)
end)

RegisterNetEvent('cui_character:open')
AddEventHandler('cui_character:open', function(tabs)
    -- Request textures
    RequestStreamedTextureDict('mparrow')
    RequestStreamedTextureDict('mpleaderboard')
    while not HasStreamedTextureDictLoaded('mparrow') or not HasStreamedTextureDictLoaded('mpleaderboard') do
        Wait(100)
    end

    SendNUIMessage({
        action = 'clearAllTabs'
    })

    local firstTabName = ''
    local clothes = nil
    for k, v in pairs(tabs) do
        if k == 1 then
            firstTabName = v
        end

        local tabName = tabs[k]
        if tabName == 'identity' then
            if not identityLoaded then
                RequestStreamedTextureDict('pause_menu_pages_char_mom_dad')
                RequestStreamedTextureDict('char_creator_portraits')
                while not HasStreamedTextureDictLoaded('pause_menu_pages_char_mom_dad') or not HasStreamedTextureDictLoaded('char_creator_portraits') do
                    Wait(100)
                end
                identityLoaded = true
            end
        elseif tabName == 'apparel' then
            -- load clothes data from natives here
            clothes = GetClothesData()
        end
    end

    SendNUIMessage({
        action = 'enableTabs',
        tabs = tabs,
        character = currentChar,
        clothes = clothes
    })

    SendNUIMessage({
        action = 'activateTab',
        tab = firstTabName
    })

    Camera.Activate()

    SendNUIMessage({
        action = 'refreshViewButtons',
        view = Camera.currentView
    })

    setVisible(true)
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    playerLoaded = true
end)

AddEventHandler('esx:onPlayerSpawn', function()
    Citizen.CreateThread(function()
        while not playerLoaded do
            Citizen.Wait(100)
        end

        if firstSpawn then
            ESX.TriggerServerCallback('cui_character:getPlayerSkin', function(skin)
                if skin ~= nil then
                    print('character found, loading...')
                    oldChar = skin
                    LoadCharacter(skin)
                else
                    print('character not found, loading default...')
                    oldChar = GetDefaultCharacter(true)
                    LoadCharacter(oldChar)
                end
            end)
            firstSpawn = false
        end
    end)

    Citizen.CreateThread(function()
        while not initialized do
            SendNUIMessage({
                action = 'loadColorData',
                hair = GetColorData(GetHairColors(), true),
                lipstick = GetColorData(GetLipstickColors(), false),
                facepaint = GetColorData(GetFacepaintColors(), false),
                blusher = GetColorData(GetBlusherColors(), false)
            })
            initialized = true
            Citizen.Wait(100)
        end
    end)
end)

RegisterNUICallback('setCameraView', function(data, cb)
    Camera.SetView(data['view'])
end)

RegisterNUICallback('updateCameraRotation', function(data, cb)
    Camera.mouseX = tonumber(data['x'])
    Camera.mouseY = tonumber(data['y'])
    Camera.updateRot = true
end)

RegisterNUICallback('updateCameraZoom', function(data, cb)
    Camera.radius = Camera.radius + (tonumber(data['zoom']))
    Camera.updateZoom = true
end)

RegisterNUICallback('playSound', function(data, cb)
    local sound = data['sound']
    if sound == 'tabchange' then
        PlaySoundFrontend(-1, 'Continue_Appears', 'DLC_HEIST_PLANNING_BOARD_SOUNDS', 1)
    elseif sound == 'mouseover' then
        PlaySoundFrontend(-1, 'Faster_Click', 'RESPAWN_ONLINE_SOUNDSET', 1)
    elseif sound == 'buttonclick' then
        PlaySoundFrontend(-1, 'Reset_Prop_Position', 'DLC_Dmod_Prop_Editor_Sounds', 0)
    end
end)

RegisterNUICallback('close', function(data, cb)
    TriggerEvent('cui_character:close', data['save'])
end)

RegisterNUICallback('updateMakeupType', function(data, cb)
    --[[
            NOTE:   This is a pure control variable that does not call any natives.
                    It only modifies which options are going to be visible in the ui.

                    Since face paint replaces blusher and eye makeup,
                    we need to save in the database which type the player selected:

                    0 - 'None',
                    1 - 'Eye Makeup',
                    2 - 'Face Paint'
    ]]--
    local type = tonumber(data['type'])
    currentChar['makeup_type'] = type

    SendNUIMessage({
        action = 'refreshMakeup',
        character = currentChar
    })
end)

RegisterNUICallback('syncFacepaintOpacity', function(data, cb)
    local prevtype = data['prevtype']
    local currenttype = data['currenttype']
    local prevopacity = prevtype .. '_2'
    local currentopacity = currenttype .. '_2'
    currentChar[currentopacity] = currentChar[prevopacity]
end)

RegisterNUICallback('clearMakeup', function(data, cb)
    if data['clearopacity'] then
        currentChar['makeup_2'] = 100
        if data['clearblusher'] then
            currentChar['blush_2'] = 100
        end
    end

    currentChar['makeup_1'] = 255
    currentChar['makeup_3'] = 255
    currentChar['makeup_4'] = 255

    local playerPed = PlayerPedId()
    SetPedHeadOverlay(playerPed, 4, currentChar.makeup_1, currentChar.makeup_2 / 100 + 0.0) -- Eye Makeup
    SetPedHeadOverlayColor(playerPed, 4, 0, currentChar.makeup_3, currentChar.makeup_4)     -- Eye Makeup Color

    if data['clearblusher'] then
        currentChar['blush_1'] = 255
        currentChar['blush_3'] = 0
        SetPedHeadOverlay(playerPed, 5, currentChar.blush_1, currentChar.blush_2 / 100 + 0.0)   -- Blusher
        SetPedHeadOverlayColor(playerPed, 5, 2, currentChar.blush_3, 255)                       -- Blusher Color
    end
end)

RegisterNUICallback('updateGender', function(data, cb)
    local value = tonumber(data['value'])
    --[[
             NOTE: bring this back if we decide on not doing
             a complete customization reset here.

            --currentChar['sex'] = value
    ]]--
    LoadCharacter(GetDefaultCharacter(value == 0))
    SendNUIMessage({
        action = 'reloadTab',
        tab = 'style',
        character = currentChar,
        clothes = nil
    })
end)

RegisterNUICallback('updateHeadBlend', function(data, cb)
    local key = data['key']
    local value = tonumber(data['value'])
    currentChar[key] = value

    local weightFace = currentChar.face_md_weight / 100 + 0.0
    local weightSkin = currentChar.skin_md_weight / 100 + 0.0

    local playerPed = PlayerPedId()
    SetPedHeadBlendData(playerPed, currentChar.mom, currentChar.dad, 0, currentChar.mom, currentChar.dad, 0, weightFace, weightSkin, 0.0, false)
end)

RegisterNUICallback('updateFaceFeature', function(data, cb)
    local key = data['key']
    local value = tonumber(data['value'])
    local index = tonumber(data['index'])
    currentChar[key] = value

    local playerPed = PlayerPedId()
    SetPedFaceFeature(playerPed, index, (currentChar[key] / 100) + 0.0)
end)

RegisterNUICallback('updateEyeColor', function(data, cb)
    local value = tonumber(data['value'])
    currentChar['eye_color'] = value

    local playerPed = PlayerPedId()
    SetPedEyeColor(playerPed, currentChar.eye_color)
end)

RegisterNUICallback('updateHairColor', function(data, cb)
    local key = data['key']
    local value = tonumber(data['value'])
    local highlight = data['highlight']
    currentChar[key] = value

    local playerPed = PlayerPedId()
    if highlight then
        SetPedHairColor(playerPed, currentChar['hair_color_1'], currentChar[key])
    else
        SetPedHairColor(playerPed, currentChar[key], currentChar['hair_color_2'])
    end
end)

RegisterNUICallback('updateHeadOverlay', function(data, cb)
    local key = data['key']
    local keyPaired = data['keyPaired']
    local value = tonumber(data['value'])
    local index = tonumber(data['index'])
    local isOpacity = (data['isOpacity'])
    currentChar[key] = value

    local playerPed = PlayerPedId()
    if isOpacity then
        SetPedHeadOverlay(playerPed, index, currentChar[keyPaired], currentChar[key] / 100 + 0.0)
    else
        SetPedHeadOverlay(playerPed, index, currentChar[key], currentChar[keyPaired] / 100 + 0.0)
    end
end)

RegisterNUICallback('updateHeadOverlayExtra', function(data, cb)
    local key = data['key']
    local keyPaired = data['keyPaired']
    local value = tonumber(data['value'])
    local index = tonumber(data['index'])
    local keyExtra = data['keyExtra']
    local valueExtra = tonumber(data['valueExtra'])
    local indexExtra = tonumber(data['indexExtra'])
    local isOpacity = (data['isOpacity'])

    currentChar[key] = value

    local playerPed = PlayerPedId()
    if isOpacity then
        currentChar[keyExtra] = value
        SetPedHeadOverlay(playerPed, index, currentChar[keyPaired], currentChar[key] / 100 + 0.0)
        SetPedHeadOverlay(playerPed, indexExtra, valueExtra, currentChar[key] / 100 + 0.0)
    else
        currentChar[keyExtra] = valueExtra
        SetPedHeadOverlay(playerPed, index, currentChar[key], currentChar[keyPaired] / 100 + 0.0)
        SetPedHeadOverlay(playerPed, indexExtra, currentChar[keyExtra], currentChar[keyPaired] / 100 + 0.0)
    end
end)

RegisterNUICallback('updateOverlayColor', function(data, cb)
    local key = data['key']
    local value = tonumber(data['value'])
    local index = tonumber(data['index'])
    local colortype = tonumber(data['colortype'])
    currentChar[key] = value

    local playerPed = PlayerPedId()
    SetPedHeadOverlayColor(playerPed, index, colortype, currentChar[key])
end)

RegisterNUICallback('updateComponent', function(data, cb)
    local drawableKey = data['drawable']
    local drawableValue = tonumber(data['dvalue'])
    local textureKey = data['texture']
    local textureValue = tonumber(data['tvalue'])
    local index = tonumber(data['index'])
    currentChar[drawableKey] = drawableValue
    currentChar[textureKey] = textureValue

    local playerPed = PlayerPedId()
    SetPedComponentVariation(playerPed, index, currentChar[drawableKey], currentChar[textureKey], 2)
end)

RegisterNUICallback('updateApparelComponent', function(data, cb)
    local drawableKey = data['drwkey']
    local textureKey = data['texkey']
    local component = tonumber(data['cmpid'])
    currentChar[drawableKey] = tonumber(data['drwval'])
    currentChar[textureKey] = tonumber(data['texval'])

    local playerPed = PlayerPedId()
    SetPedComponentVariation(playerPed, component, currentChar[drawableKey], currentChar[textureKey], 2)

    -- Some clothes have 'forced components' that change torso and other parts.
    -- adapted from: https://gist.github.com/root-cause/3b80234367b0c856d60bf5cb4b826f86
    local hash = GetHashNameForComponent(playerPed, component, currentChar[drawableKey], currentChar[textureKey])
    --print('main component hash ' .. hash)
    local fcDrawable, fcTexture, fcType = -1, -1, -1
    local fcCount = GetShopPedApparelForcedComponentCount(hash) - 1
    --print('found ' .. fcCount + 1 .. ' forced components')
    for fcId = 0, fcCount do
        local fcNameHash, fcEnumVal, f5, f7, f8 = -1, -1, -1, -1, -1
        fcNameHash, fcEnumVal, fcType = GetForcedComponent(hash, fcId)
        --print('forced component [' .. fcId .. ']: nameHash: ' .. fcNameHash .. ', enumVal: ' .. fcEnumVal .. ', type: ' .. fcType--[[.. ', field5: ' .. f5 .. ', field7: ' .. f7 .. ', field8: ' .. f8 --]])

        -- only set torsos, using other types here seems to glitch out
        if fcType == 3 then
            if (fcNameHash == 0) or (fcNameHash == GetHashKey('0')) then
                fcDrawable = fcEnumVal
                fcTexture = 0
            else
                fcType, fcDrawable, fcTexture = GetComponentDataFromHash(fcNameHash)
            end

            -- Apply component to ped, save it in current character data
            if IsPedComponentVariationValid(playerPed, fcType, fcDrawable, fcTexture) then
                currentChar['arms'] = fcDrawable
                currentChar['arms_2'] = fcTexture
                SetPedComponentVariation(playerPed, fcType, fcDrawable, fcTexture, 2)
            end
        end
    end

    -- Forced components do not pick proper torso for female character's 'None' variant, need manual correction
    if GetEntityModel(playerPed) == GetHashKey('mp_f_freemode_01') then
        if (GetPedDrawableVariation(playerPed, 11) == 15) and (GetPedTextureVariation(playerPed, 11) == 16) then
            currentChar['arms'] = 15
            currentChar['arms_2'] = 0
            SetPedComponentVariation(playerPed, 3, 15, 0, 2);
        end
    end

end)

RegisterNUICallback('updateApparelProp', function(data, cb)
    local drawableKey = data['drwkey']
    local textureKey = data['texkey']
    local prop = tonumber(data['propid'])
    currentChar[drawableKey] = tonumber(data['drwval'])
    currentChar[textureKey] = tonumber(data['texval'])

    local playerPed = PlayerPedId()

    if currentChar[drawableKey] == -1 then
        ClearPedProp(playerPed, prop)
    else
        SetPedPropIndex(playerPed, prop, currentChar[drawableKey], currentChar[textureKey], false)
    end
end)

function GetHairColors()
    local result = {}
    local i = 0

    if Config.UseNaturalHairColors then
        for i = 0, 18 do
            table.insert(result, i)
        end
        table.insert(result, 24)
        table.insert(result, 26)
        table.insert(result, 27)
        table.insert(result, 28)
        for i = 55, 60 do
            table.insert(result, i)
        end
    else
        for i = 0, 60 do
            table.insert(result, i)
        end
    end

    return result
end

function GetLipstickColors()
    local result = {}
    local i = 0

    for i = 0, 31 do
        table.insert(result, i)
    end
    table.insert(result, 48)
    table.insert(result, 49)
    table.insert(result, 55)
    table.insert(result, 56)
    table.insert(result, 62)
    table.insert(result, 63)

    return result
end

function GetFacepaintColors()
    local result = {}
    local i = 0

    for i = 0, 63 do
        table.insert(result, i)
    end

    return result
end

function GetBlusherColors()
    local result = {}
    local i = 0

    for i = 0, 22 do
        table.insert(result, i)
    end
    table.insert(result, 25)
    table.insert(result, 26)
    table.insert(result, 51)
    table.insert(result, 60)

    return result
end

function RGBToHexCode(r, g, b)
    local result = string.format('#%x', ((r << 16) | (g << 8) | b))
    return result
end

function GetColorData(indexes, isHair)
    local result = {}
    local GetRgbColor = nil

    if isHair then
        GetRgbColor = function(index)
            return GetPedHairRgbColor(index)
        end
    else
        GetRgbColor = function(index)
            return GetPedMakeupRgbColor(index)
        end
    end

    for i, index in ipairs(indexes) do
        local r, g, b = GetRgbColor(index)
        local hex = RGBToHexCode(r, g, b)
        table.insert(result, { index = index, hex = hex })
    end

    return result
end

function GetComponentDataFromHash(hash)
    local blob = string.rep('\0\0\0\0\0\0\0\0', 9 + 16)
    if not Citizen.InvokeNative(0x74C0E2A57EC66760, hash, blob) then
        return nil
    end

    -- adapted from: https://gist.github.com/root-cause/3b80234367b0c856d60bf5cb4b826f86
    local lockHash = string.unpack('<i4', blob, 1)
    local hash = string.unpack('<i4', blob, 9)
    local locate = string.unpack('<i4', blob, 17)
    local drawable = string.unpack('<i4', blob, 25)
    local texture = string.unpack('<i4', blob, 33)
    local field5 = string.unpack('<i4', blob, 41)
    local component = string.unpack('<i4', blob, 49)
    local field7 = string.unpack('<i4', blob, 57)
    local field8 = string.unpack('<i4', blob, 65)
    local gxt = string.unpack('c64', blob, 73)

    return component, drawable, texture, gxt, field5, field7, field8
end

function GetPropDataFromHash(hash)
    local blob = string.rep('\0\0\0\0\0\0\0\0', 9 + 16)
    if not Citizen.InvokeNative(0x5D5CAFF661DDF6FC, hash, blob) then
        return nil
    end

    -- adapted from: https://gist.github.com/root-cause/3b80234367b0c856d60bf5cb4b826f86
    local lockHash = string.unpack('<i4', blob, 1)
    local hash = string.unpack('<i4', blob, 9)
    local locate = string.unpack('<i4', blob, 17)
    local drawable = string.unpack('<i4', blob, 25)
    local texture = string.unpack('<i4', blob, 33)
    local field5 = string.unpack('<i4', blob, 41)
    local prop = string.unpack('<i4', blob, 49)
    local field7 = string.unpack('<i4', blob, 57)
    local field8 = string.unpack('<i4', blob, 65)
    local gxt = string.unpack('c64', blob, 73)

    return prop, drawable, texture, gxt, field5, field7, field8
end

function GetComponentsData(id)
    local result = {}

    local playerPed = PlayerPedId()
    local drawableCount = GetNumberOfPedDrawableVariations(playerPed, id) - 1

    for drawable = 0, drawableCount do
        local textureCount = GetNumberOfPedTextureVariations(playerPed, id, drawable) - 1

        for texture = 0, textureCount do
            local hash = GetHashNameForComponent(playerPed, id, drawable, texture)

            if hash ~= 0 then
                local component, drawable, texture, gxt = GetComponentDataFromHash(hash)

                -- only named components
                if gxt ~= '' then
                    label = GetLabelText(gxt)
                    if label ~= 'NULL' then
                        table.insert(result, {
                            name = label,
                            component = component,
                            drawable = drawable,
                            texture = texture
                        })
                    end
                end
            end
        end
    end

    return result
end

function GetPropsData(id)
    local result = {}

    local playerPed = PlayerPedId()
    local drawableCount = GetNumberOfPedPropDrawableVariations(playerPed, id) - 1

    for drawable = 0, drawableCount do
        local textureCount = GetNumberOfPedPropTextureVariations(playerPed, id, drawable) - 1

        for texture = 0, textureCount do
            local hash = GetHashNameForProp(playerPed, id, drawable, texture)

            if hash ~= 0 then
                local prop, drawable, texture, gxt = GetPropDataFromHash(hash)

                -- only named props
                if gxt ~= '' then
                    label = GetLabelText(gxt)
                    if label ~= 'NULL' then
                        table.insert(result, {
                            name = label,
                            prop = prop,
                            drawable = drawable,
                            texture = texture
                        })
                    end
                end
            end
        end
    end

    return result
end

function GetClothesData()
    local result = {
        topsover = {},
        topsunder = {},
        pants = {},
        shoes = {},
        hats = {},
        ears = {},
        glasses = {},
        lefthands = {},
        righthands = {},
    }

    result.topsover = GetComponentsData(11)
    result.topsunder = GetComponentsData(8)
    result.pants = GetComponentsData(4)
    result.shoes = GetComponentsData(6)

    result.hats = GetPropsData(0)
    result.ears = GetPropsData(2)
    result.glasses = GetPropsData(1)
    result.lefthands = GetPropsData(6)
    result.righthands = GetPropsData(7)

    return result
end

function GetDefaultCharacter(isMale)
    local result = {
        sex = 1,
        mom = 21,
        dad = 0,
        face_md_weight = 50,
        skin_md_weight = 50,
        nose_1 = 0,
        nose_2 = 0,
        nose_3 = 0,
        nose_4 = 0,
        nose_5 = 0,
        nose_6 = 0,
        cheeks_1 = 0,
        cheeks_2 = 0,
        cheeks_3 = 0,
        lip_thickness = 0,
        jaw_1 = 0,
        jaw_2 = 0,
        chin_1 = 0,
        chin_2 = 0,
        chin_3 = 0,
        chin_4 = 0,
        neck_thickness = 0,
        hair_1 = 0,
        hair_2 = 0,
        hair_color_1 = 0,
        hair_color_2 = 0,
        tshirt_1 = 0,
        tshirt_2 = 0,
        torso_1 = 0,
        torso_2 = 0,
        decals_1 = 0,
        decals_2 = 0,
        arms = 15,
        arms_2 = 0,
        pants_1 = 0,
        pants_2 = 0,
        shoes_1 = 0,
        shoes_2 = 0,
        mask_1 = 0,
        mask_2 = 0,
        bproof_1 = 0,
        bproof_2 = 0,
        chain_1 = 0,
        chain_2 = 0,
        helmet_1 = -1,
        helmet_2 = 0,
        glasses_1 = -1,
        glasses_2 = 0,
        lefthand_1 = -1,
        lefthand_2 = 0,
        righthand_1 = -1,
        righthand_2 = 0,
        bags_1 = 0,
        bags_2 = 0,
        eye_color = 0,
        eye_squint = 0,
        eyebrows_2 = 0,
        eyebrows_1 = 0,
        eyebrows_3 = 0,
        eyebrows_4 = 0,
        eyebrows_5 = 0,
        eyebrows_6 = 0,
        makeup_type = 0,
        makeup_1 = 255,
        makeup_2 = 100,
        makeup_3 = 255,
        makeup_4 = 255,
        lipstick_1 = 255,
        lipstick_2 = 0,
        lipstick_3 = 0,
        lipstick_4 = 0,
        ears_1 = -1,
        ears_2 = 0,
        chest_1 = 255,
        chest_2 = 0,
        chest_3 = 0,
        chest_4 = 0,
        bodyb_1 = 255,
        bodyb_2 = 100,
        bodyb_3 = 255,
        bodyb_4 = 100,
        age_1 = 255,
        age_2 = 100,
        blemishes_1 = 255,
        blemishes_2 = 100,
        blush_1 = 255,
        blush_2 = 100,
        blush_3 = 0,
        complexion_1 = 255,
        complexion_2 = 100,
        sun_1 = 255,
        sun_2 = 100,
        moles_1 = 255,
        moles_2 = 100,
        beard_1 = 255,
        beard_2 = 0,
        beard_3 = 0,
        beard_4 = 0
    }

    if isMale then
        result['sex'] = 0
        result['torso_1'] = 15
        result['tshirt_1'] = 15
        result['pants_1'] = 61
        result['shoes_1'] = 34
    else
        result['torso_1'] = 18
        result['tshirt_1'] = 2
        result['pants_1'] = 19
        result['shoes_1'] = 35
    end

    return result
end

function LoadModel(isMale)
    local playerPed = PlayerPedId()
    local characterModel = GetHashKey('mp_f_freemode_01')
    if isMale then
        characterModel = GetHashKey('mp_m_freemode_01')
    end

    SetEntityInvincible(playerPed, true)
    if IsModelInCdimage(characterModel) and IsModelValid(characterModel) then
        RequestModel(characterModel)
        while not HasModelLoaded(characterModel) do
            Citizen.Wait(0)
        end
        SetPlayerModel(PlayerId(), characterModel)
        SetModelAsNoLongerNeeded(characterModel)
        FreezePedCameraRotation(playerPed, true)
    end
    SetEntityInvincible(playerPed, false)
end

-- Loading character data
function LoadCharacter(data)
    for k, v in pairs(data) do
        currentChar[k] = v
    end

    local isMale = false
    if data.sex ~= 1 then
        isMale = true
    end
    LoadModel(isMale)

    --TODO: Possibly pull these out to separate functions
    local playerPed = PlayerPedId()

    -- Face Blend
    local weightFace = data.face_md_weight / 100 + 0.0
    local weightSkin = data.skin_md_weight / 100 + 0.0
    SetPedHeadBlendData(playerPed, data.mom, data.dad, 0, data.mom, data.dad, 0, weightFace, weightSkin, 0.0, false)

    -- Facial Features
    SetPedFaceFeature(playerPed, 0,  (data.nose_1 / 100)         + 0.0)  -- Nose Width
    SetPedFaceFeature(playerPed, 1,  (data.nose_2 / 100)         + 0.0)  -- Nose Peak Height
    SetPedFaceFeature(playerPed, 2,  (data.nose_3 / 100)         + 0.0)  -- Nose Peak Length
    SetPedFaceFeature(playerPed, 3,  (data.nose_4 / 100)         + 0.0)  -- Nose Bone Height
    SetPedFaceFeature(playerPed, 4,  (data.nose_5 / 100)         + 0.0)  -- Nose Peak Lowering
    SetPedFaceFeature(playerPed, 5,  (data.nose_6 / 100)         + 0.0)  -- Nose Bone Twist
    SetPedFaceFeature(playerPed, 6,  (data.eyebrows_5 / 100)     + 0.0)  -- Eyebrow height
    SetPedFaceFeature(playerPed, 7,  (data.eyebrows_6 / 100)     + 0.0)  -- Eyebrow depth
    SetPedFaceFeature(playerPed, 8,  (data.cheeks_1 / 100)       + 0.0)  -- Cheekbones Height
    SetPedFaceFeature(playerPed, 9,  (data.cheeks_2 / 100)       + 0.0)  -- Cheekbones Width
    SetPedFaceFeature(playerPed, 10, (data.cheeks_3 / 100)       + 0.0)  -- Cheeks Width
    SetPedFaceFeature(playerPed, 11, (data.eye_squint / 100)     + 0.0)  -- Eyes squint
    SetPedFaceFeature(playerPed, 12, (data.lip_thickness / 100)  + 0.0)  -- Lip Fullness
    SetPedFaceFeature(playerPed, 13, (data.jaw_1 / 100)          + 0.0)  -- Jaw Bone Width
    SetPedFaceFeature(playerPed, 14, (data.jaw_2 / 100)          + 0.0)  -- Jaw Bone Length
    SetPedFaceFeature(playerPed, 15, (data.chin_1 / 100)         + 0.0)  -- Chin Height
    SetPedFaceFeature(playerPed, 16, (data.chin_2 / 100)         + 0.0)  -- Chin Length
    SetPedFaceFeature(playerPed, 17, (data.chin_3 / 100)         + 0.0)  -- Chin Width
    SetPedFaceFeature(playerPed, 18, (data.chin_4 / 100)         + 0.0)  -- Chin Hole Size
    SetPedFaceFeature(playerPed, 19, (data.neck_thickness / 100) + 0.0)  -- Neck Thickness

    -- Appearance
    SetPedComponentVariation(playerPed, 2, data.hair_1, data.hair_2, 2)                  -- Hair Style
    SetPedHairColor(playerPed, data.hair_color_1, data.hair_color_2)                     -- Hair Color
    SetPedHeadOverlay(playerPed, 2, data.eyebrows_1, data.eyebrows_2 / 100 + 0.0)        -- Eyebrow Style + Opacity
    SetPedHeadOverlayColor(playerPed, 2, 1, data.eyebrows_3, data.eyebrows_4)            -- Eyebrow Color
    SetPedHeadOverlay(playerPed, 1, data.beard_1, data.beard_2 / 100 + 0.0)              -- Beard Style + Opacity
    SetPedHeadOverlayColor(playerPed, 1, 1, data.beard_3, data.beard_4)                  -- Beard Color

    SetPedHeadOverlay(playerPed, 0, data.blemishes_1, data.blemishes_2 / 100 + 0.0)      -- Skin blemishes + Opacity
    SetPedHeadOverlay(playerPed, 12, data.bodyb_3, data.bodyb_4 / 100 + 0.0)             -- Skin blemishes body effect + Opacity

    SetPedHeadOverlay(playerPed, 11, data.bodyb_1, data.bodyb_2 / 100 + 0.0)             -- Body Blemishes + Opacity

    SetPedHeadOverlay(playerPed, 3, data.age_1, data.age_2 / 100 + 0.0)                  -- Age + opacity
    SetPedHeadOverlay(playerPed, 6, data.complexion_1, data.complexion_2 / 100 + 0.0)    -- Complexion + Opacity
    SetPedHeadOverlay(playerPed, 9, data.moles_1, data.moles_2 / 100 + 0.0)              -- Moles/Freckles + Opacity
    SetPedHeadOverlay(playerPed, 7, data.sun_1, data.sun_2 / 100 + 0.0)                  -- Sun Damage + Opacity
    SetPedEyeColor(playerPed, data.eye_color)                                            -- Eyes Color
    SetPedHeadOverlay(playerPed, 4, data.makeup_1, data.makeup_2 / 100 + 0.0)            -- Makeup + Opacity
    SetPedHeadOverlayColor(playerPed, 4, 0, data.makeup_3, data.makeup_4)                -- Makeup Color
    SetPedHeadOverlay(playerPed, 5, data.blush_1, data.blush_2 / 100 + 0.0)              -- Blush + Opacity
    SetPedHeadOverlayColor(playerPed, 5, 2,	data.blush_3)                                -- Blush Color
    SetPedHeadOverlay(playerPed, 8, data.lipstick_1, data.lipstick_2 / 100 + 0.0)        -- Lipstick + Opacity
    SetPedHeadOverlayColor(playerPed, 8, 2, data.lipstick_3, data.lipstick_4)            -- Lipstick Color
    SetPedHeadOverlay(playerPed, 10, data.chest_1, data.chest_2 / 100 + 0.0)             -- Chest Hair + Opacity
    SetPedHeadOverlayColor(playerPed, 10, 1, data.chest_3, data.chest_4)                 -- Chest Hair Color

    -- Clothing and Accessories
    SetPedComponentVariation(playerPed, 8,  data.tshirt_1, data.tshirt_2, 2)    -- Undershirts
    SetPedComponentVariation(playerPed, 11, data.torso_1,  data.torso_2,  2)    -- Jackets
    SetPedComponentVariation(playerPed, 3,  data.arms,     data.arms_2,   2)    -- Torsos
    SetPedComponentVariation(playerPed, 10, data.decals_1, data.decals_2, 2)    -- Decals
    SetPedComponentVariation(playerPed, 4,  data.pants_1,  data.pants_2,  2)    -- Legs
    SetPedComponentVariation(playerPed, 6,  data.shoes_1,  data.shoes_2,  2)    -- Shoes
    SetPedComponentVariation(playerPed, 1,  data.mask_1,   data.mask_2,   2)    -- Masks
    SetPedComponentVariation(playerPed, 9,  data.bproof_1, data.bproof_2, 2)    -- Vests
    SetPedComponentVariation(playerPed, 7,  data.chain_1,  data.chain_2,  2)    -- Necklaces/Chains
    SetPedComponentVariation(playerPed, 5,  data.bags_1,   data.bags_2,   2)    -- Bags

    if data.helmet_1 == -1 then
        ClearPedProp(playerPed, 0)
    else
        SetPedPropIndex(playerPed, 0, data.helmet_1, data.helmet_2, 2)          -- Hats
    end

    if data.glasses_1 == -1 then
        ClearPedProp(playerPed, 1)
    else
        SetPedPropIndex(playerPed, 1, data.glasses_1, data.glasses_2, 2)        -- Glasses
    end

    if data.lefthand_1 == -1 then
        ClearPedProp(playerPed, 6)
    else
        SetPedPropIndex(playerPed, 6, data.lefthand_1, data.lefthand_2, 2)        -- Left Hand Accessory
    end

    if data.righthand_1 == -1 then
        ClearPedProp(playerPed,	7)
    else
        SetPedPropIndex(playerPed, 7, data.righthand_1, data.righthand_2, 2)      -- Right Hand Accessory
    end

    if data.ears_1 == -1 then
        ClearPedProp(playerPed, 2)
    else
        SetPedPropIndex (playerPed, 2, data.ears_1, data.ears_2, 2)               -- Ear Accessory
    end
end