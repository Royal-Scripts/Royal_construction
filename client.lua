local QBCore = exports['qb-core']:GetCoreObject()

-- State variables
local isWorking = false
local isOnQuest = false
local questProgress = 0
local currentCheckpoint = nil
local currentCheckpointIndex = nil -- Track which checkpoint is active
local currentMarker = nil
local dropoffMarker = nil
local isCarrying = false
local lastCheckpointCoords = nil
local currentProp = nil
local checkpointCooldowns = {} -- Track cooldown for each checkpoint (40 sec)
local jobBlip = nil

-- Helper to remove job blip
local function removeJobBlip()
    if jobBlip and DoesBlipExist(jobBlip) then
        RemoveBlip(jobBlip)
    end
    jobBlip = nil
end

-- Initialize ped and blip
CreateThread(function()
    -- Spawn job ped
    local pedModel = Config.Ped.model
    if lib.requestModel(pedModel) then
        local ped = CreatePed(4, joaat(pedModel), Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z - 1.0, Config.Ped.coords.w, false, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)

        -- Add ox_target interaction
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'construction_job_menu',
                icon = 'fa-solid fa-hammer',
                label = 'სამშენებლო სამუშაო',
                onSelect = function()
                    openJobMenu()
                end
            }
        })
    end

    -- Create blip
    local blip = AddBlipForCoord(Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Blip.label)
    EndTextCommandSetBlipName(blip)
end)

-- Draw persistent markers at all checkpoint locations
CreateThread(function()
    while true do
        local sleep = 500
        local playerPos = GetEntityCoords(PlayerPedId())
        
        -- Draw marker at job ped location (marker 1)
        local pedDist = #(playerPos - vector3(Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z))
        if pedDist < 50.0 then
            sleep = 0
            DrawMarker(
                1, -- Cylinder with flat top
                Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z - 1.5,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                1.0, 1.0, 1.0,
                Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
                false, true, 2, false, nil, nil, false
            )
        end
        
        for _, checkpoint in ipairs(Config.Checkpoints) do
            local dist = #(playerPos - vector3(checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z))
            
            -- Only draw if within 100 meters for performance
            if dist < 200.0 then
                sleep = 0
                
                -- Draw checkpoint marker (orange) - lowered
                DrawMarker(
                    Config.Marker.type,
                    checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z - 0.5,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    Config.Marker.size.x, Config.Marker.size.y, Config.Marker.size.z,
                    Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
                    false, true, 2, false, nil, nil, false
                )
                
                -- Draw dropoff marker if checkpoint has one (green)
                if checkpoint.dropoff then
                    local dropDist = #(playerPos - vector3(checkpoint.dropoff.x, checkpoint.dropoff.y, checkpoint.dropoff.z))
                    if dropDist < 200.0 then
                        DrawMarker(
                            Config.Marker.type,
                            checkpoint.dropoff.x, checkpoint.dropoff.y, checkpoint.dropoff.z - 0.5,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            Config.Marker.size.x, Config.Marker.size.y, Config.Marker.size.z,
                            0, 255, 0, 150, -- Green for dropoff
                            false, true, 2, false, nil, nil, false
                        )
                    end
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- Open job menu with custom NUI
function openJobMenu()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openMenu',
        questProgress = questProgress
    })
end

-- NUI Callbacks
RegisterNUICallback('startWork', function(data, cb)
    SetNuiFocus(false, false)
    startWork(true) -- Always quest mode (progress always shown)
    cb('ok')
end)

RegisterNUICallback('endWork', function(data, cb)
    SetNuiFocus(false, false)
    endWork()
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Start working
function startWork(questMode)
    if isWorking then
        lib.notify({ type = 'error', description = 'თქვენ უკვე მუშაობთ!' })
        return
    end

    isWorking = true
    isOnQuest = questMode
    currentCheckpointIndex = 1
    lastCheckpointCoords = GetEntityCoords(PlayerPedId())

    if questMode then
        lib.notify({ 
            title = 'დავალება დაიწყო', 
            description = 'დაასრულეთ ' .. Config.Quest.totalCheckpoints .. ' წერტილი 10% ბონუსისთვის!',
            type = 'success' 
        })
    else
        lib.notify({ 
            title = 'მუშაობა დაიწყო', 
            description = 'მიდით მონიშნულ ადგილას სამუშაოდ.',
            type = 'success' 
        })
    end

    -- Start checkpoint loop
    setNextCheckpoint()
end

-- End working
function endWork()
    if not isWorking then
        lib.notify({ type = 'error', description = 'თქვენ არ მუშაობთ!' })
        return
    end

    isWorking = false
    isOnQuest = false
    isCarrying = false
    currentCheckpoint = nil
    
    -- Clear any active marker threads
    currentMarker = nil
    dropoffMarker = nil
    
    -- Delete any active prop
    if currentProp and DoesEntityExist(currentProp) then
        DeleteEntity(currentProp)
        currentProp = nil
    end

    -- Stop any animation
    ClearPedTasks(PlayerPedId())
    removeJobBlip() -- Remove map blip

    lib.notify({ 
        title = 'მუშაობა დასრულდა', 
        description = 'თქვენ შეწყვიტეთ მუშაობა.',
        type = 'info' 
    })
end

-- Set next checkpoint (random selection, avoiding cooldowns)
function setNextCheckpoint()
    if not isWorking then return end

    -- Get current time
    local currentTime = GetGameTimer()
    
    -- Filter out checkpoints that are on cooldown
    local availableCheckpoints = {}
    for i, checkpoint in ipairs(Config.Checkpoints) do
        local cooldownEnd = checkpointCooldowns[i] or 0
        if currentTime >= cooldownEnd then
            table.insert(availableCheckpoints, { index = i, checkpoint = checkpoint })
        end
    end
    
    -- If all checkpoints are on cooldown, wait and retry
    if #availableCheckpoints == 0 then
        lib.notify({ description = 'ყველა წერტილი დროებით შეჩერებულია, გთხოვთ დაელოდოთ...', type = 'info' })
        SetTimeout(5000, function()
            if isWorking then
                setNextCheckpoint()
            end
        end)
        return
    end
    
    -- Randomly select from available checkpoints
    local selected = availableCheckpoints[math.random(1, #availableCheckpoints)]
    local checkpoint = selected.checkpoint
    currentCheckpoint = checkpoint
    currentCheckpointIndex = selected.index -- Store index separately for cooldown
    currentMarker = checkpoint.coords

    -- Store current position for reward calculation
    lastCheckpointCoords = GetEntityCoords(PlayerPedId())

    -- Set GPS waypoint and Blip
    SetNewWaypoint(checkpoint.coords.x, checkpoint.coords.y)
    
    removeJobBlip()
    jobBlip = AddBlipForCoord(checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z)
    SetBlipSprite(jobBlip, 1) -- Standard blip
    SetBlipColour(jobBlip, 5) -- Yellow color (or change as needed)
    SetBlipScale(jobBlip, 0.8)
    SetBlipRoute(jobBlip, true) -- Draw route to blip
    SetBlipRouteColour(jobBlip, 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("სამუშაო ადგილი")
    EndTextCommandSetBlipName(jobBlip)

    lib.notify({ 
        description = 'მიდით: ' .. checkpoint.label,
        type = 'info' 
    })

    -- Start marker drawing thread
    CreateThread(function()
        local markerCoords = currentMarker
        while isWorking and currentMarker == markerCoords do
            Wait(0)
            local plyPos = GetEntityCoords(PlayerPedId())
            local dist = #(plyPos - vector3(markerCoords.x, markerCoords.y, markerCoords.z))

            -- Draw marker
            DrawMarker(
                Config.Marker.type,
                markerCoords.x, markerCoords.y, markerCoords.z - 1.0,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                Config.Marker.size.x, Config.Marker.size.y, Config.Marker.size.z,
                Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
                false, true, 2, false, nil, nil, false
            )

            -- Check if player is at checkpoint
            if dist < 2.0 then
                lib.showTextUI('[E] ' .. checkpoint.label, { position = 'left-center' })
                
                if IsControlJustPressed(0, 38) then -- E key
                    lib.hideTextUI()
                    doWork(checkpoint)
                    break
                end
            else
                lib.hideTextUI()
            end
        end
    end)
end

-- Spawn and attach prop to player
function attachProp(checkpoint)
    if not checkpoint.prop then return nil end
    
    local ped = PlayerPedId()
    local propModel = checkpoint.prop.model
    
    if not lib.requestModel(propModel) then return nil end
    
    local prop = CreateObject(joaat(propModel), 0.0, 0.0, 0.0, true, true, true)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, checkpoint.prop.bone),
        checkpoint.prop.offset.x, checkpoint.prop.offset.y, checkpoint.prop.offset.z,
        checkpoint.prop.rotation.x, checkpoint.prop.rotation.y, checkpoint.prop.rotation.z,
        true, true, false, true, 1, true)
    
    return prop
end

-- Delete current prop
function deleteProp()
    if currentProp and DoesEntityExist(currentProp) then
        DeleteEntity(currentProp)
        currentProp = nil
    end
end

-- Perform work at checkpoint
function doWork(checkpoint)
    if not isWorking then return end

    local ped = PlayerPedId()

    -- Load animation
    lib.requestAnimDict(checkpoint.anim.dict)

    -- Set player heading
    SetEntityHeading(ped, checkpoint.coords.w)

    if checkpoint.type == 'carry' then
        -- Request pickup animation
        lib.requestAnimDict('random@domestic')
        
        -- Play pickup animation
        TaskPlayAnim(ped, 'random@domestic', 'pickup_low', 8.0, -8.0, 1200, 0, 0, false, false, false)
        Wait(1000) -- Wait for hand to reach ground
        
        -- Attach box prop
        currentProp = attachProp(checkpoint)
        
        -- Start carry animation
        TaskPlayAnim(ped, checkpoint.anim.dict, checkpoint.anim.name, 8.0, -8.0, -1, 49, 0, false, false, false)
        isCarrying = true
        currentMarker = nil

        lib.notify({ description = 'მიიტანეთ მასალები დანიშნულების ადგილზე!', type = 'info' })

        -- Set dropoff marker
        dropoffMarker = checkpoint.dropoff
        SetNewWaypoint(checkpoint.dropoff.x, checkpoint.dropoff.y)

        -- Draw dropoff marker and wait for player
        CreateThread(function()
            local dropoff = checkpoint.dropoff
            while isWorking and isCarrying do
                Wait(0)
                local plyPos = GetEntityCoords(PlayerPedId())
                local dist = #(plyPos - vector3(dropoff.x, dropoff.y, dropoff.z))

                -- Draw dropoff marker
                DrawMarker(
                    Config.Marker.type,
                    dropoff.x, dropoff.y, dropoff.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    Config.Marker.size.x, Config.Marker.size.y, Config.Marker.size.z,
                    0, 255, 0, 150, -- Green for dropoff
                    false, true, 2, false, nil, nil, false
                )

                if dist < 2.0 then
                    lib.showTextUI('[E] მასალების დატოვება', { position = 'left-center' })
                    
                    if IsControlJustPressed(0, 38) then
                        lib.hideTextUI()
                        
                        -- Play putdown animation
                        lib.requestAnimDict('random@domestic')
                        TaskPlayAnim(ped, 'random@domestic', 'pickup_low', 8.0, -8.0, 1200, 0, 0, false, false, false)
                        Wait(1000) -- Wait for hand to reach ground
                        
                        isCarrying = false
                        dropoffMarker = nil
                        deleteProp() -- Remove box prop
                        ClearPedTasks(ped)
                        
                        -- Complete checkpoint
                        completeCheckpoint(checkpoint)
                        break
                    end
                else
                    lib.hideTextUI()
                end
            end
        end)
    else
        -- Attach prop for work animation
        currentProp = attachProp(checkpoint)
        
        -- Normal work animation with progress bar
        if lib.progressCircle({
            duration = checkpoint.anim.duration or Config.Progress.duration,
            label = checkpoint.label,
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = {
                dict = checkpoint.anim.dict,
                clip = checkpoint.anim.name
            }
        }) then
            ClearPedTasks(ped)
            deleteProp() -- Remove work prop
            completeCheckpoint(checkpoint)
        else
            ClearPedTasks(ped)
            deleteProp() -- Remove prop on cancel
            lib.notify({ type = 'error', description = 'მუშაობა გაუქმდა!' })
            setNextCheckpoint() -- Allow retry
        end
    end
end

-- Complete checkpoint and get reward
function completeCheckpoint(checkpoint)
    if not isWorking then return end

    -- Calculate distance-based reward
    local playerPos = GetEntityCoords(PlayerPedId())
    local distance = #(lastCheckpointCoords - vector3(checkpoint.coords.x, checkpoint.coords.y, checkpoint.coords.z))
    
    -- Scale reward based on distance (1-4 dollars)
    local rewardRange = Config.Rewards.maxReward - Config.Rewards.minReward
    local distanceRatio = math.min(distance / Config.Rewards.baseDistance, 1.0)
    local reward = math.floor(Config.Rewards.minReward + (rewardRange * distanceRatio))
    reward = math.max(Config.Rewards.minReward, math.min(Config.Rewards.maxReward, reward))

    -- Update quest progress
    if isOnQuest then
        questProgress = questProgress + 1
        
        if questProgress >= Config.Quest.totalCheckpoints then
            lib.notify({ 
                title = 'დავალება შესრულებულია!', 
                description = 'თქვენ შეასრულეთ ყველა ' .. Config.Quest.totalCheckpoints .. ' საკონტროლო წერტილი!',
                type = 'success' 
            })
        end
    end

    -- Request payment from server
    TriggerServerEvent('royal_constraction:requestPayment', reward, isOnQuest)

    -- Set 40 second cooldown for this checkpoint
    if currentCheckpointIndex then
        checkpointCooldowns[currentCheckpointIndex] = GetGameTimer() + 40000 -- 40 seconds
    end

    -- Clear checkpoint reference (next one will be randomly selected)
    currentCheckpoint = nil
    currentCheckpointIndex = nil
    removeJobBlip()

    lastCheckpointCoords = playerPos

    -- Show progress if on quest
    if isOnQuest then
        lib.notify({ 
            description = 'პროგრესი: ' .. questProgress .. '/' .. Config.Quest.totalCheckpoints,
            type = 'info' 
        })
    end

    -- Set next checkpoint after short delay
    SetTimeout(500, function()
        if isWorking then
            setNextCheckpoint()
        end
    end)
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    ClearPedTasks(PlayerPedId())
    lib.hideTextUI()
    deleteProp()
end)
