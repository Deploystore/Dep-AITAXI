local isUIOpen = false
local stationPedEntity = nil
local stationBlipEntity = nil

if Config.EnableCommand then
    RegisterCommand(Config.Command, function()
        ToggleTaxiUI()
    end, false)
end

RegisterCommand('canceltaxi', function()
    CancelAITaxiTrip()
end, false)

if Config.EnableKeybind then
    RegisterKeyMapping(Config.Command, 'AI Taksi Menusunu Ac (Vivanite2)', 'keyboard', Config.Keybind)
end

function ToggleTaxiUI()
    isUIOpen = not isUIOpen
    SetNuiFocus(isUIOpen, isUIOpen)
    
    if isUIOpen then
        TriggerScreenblurFadeIn(200)
    else
        TriggerScreenblurFadeOut(200)
    end
    
    local isWaypointSet = Framework.HasWaypoint()
    local waypointCoords = isWaypointSet and Framework.GetWaypointCoords() or nil

    SendNUIMessage({
        action = 'OPEN_TAXI_UI',
        data = {
            visible = isUIOpen,
            config = {
                language = Config.Language or 'en',
                locales = Locales[Config.Language or 'en'] or Locales['en'],
                baseFare = Config.BaseFare,
                pricePerKM = Config.PricePerKM,
                currency = Config.CurrencySymbol,
                driverName = Config.DriverName,
                driverRating = Config.DriverRating,
                vehicleModel = Config.VehicleModel,
                destinations = Config.PresetDestinations,
                drivingStyles = Config.DrivingStyles,
                defaultStyle = Config.DefaultDrivingStyle,
                AIAssistantRules = Config.AIAssistantRules,
                DriverDialogue = Config.DriverDialogue
            },
            hasWaypoint = isWaypointSet,
            waypointCoords = waypointCoords,
            activeTrip = (type(IsTaxiActive) == 'function' and IsTaxiActive()) or false
        }
    })
end

RegisterNUICallback('closeUI', function(data, cb)
    isUIOpen = false
    TriggerScreenblurFadeOut(200)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('callTaxi', function(data, cb)
    local drivingStyle = data.style or Config.DefaultDrivingStyle
    local vehicleModel = data.vehicleModel or Config.VehicleModel
    local preferences = data.preferences or {}
    local subPreferences = data.subPreferences or {}
    local success, err = SpawnAndRequestAITaxi(nil, drivingStyle, vehicleModel, preferences, subPreferences)

    if success then
        isUIOpen = false
        TriggerScreenblurFadeOut(200)
        SetNuiFocus(false, false)
        cb({ success = true })
    else
        cb({ success = false, message = err })
    end
end)

RegisterNUICallback('setDrivingStyle', function(data, cb)
    if data.style then
        UpdateTaxiDrivingStyle(data.style)
    end
    cb('ok')
end)

RegisterNUICallback('cancelTrip', function(data, cb)
    CancelAITaxiTrip()
    isUIOpen = false
    TriggerScreenblurFadeOut(200)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('copyPos', function(data, cb)
    ExecuteCommand('taxipos')
    cb('ok')
end)

RegisterNetEvent('DepAITaxi:client:openUI', function()
    ToggleTaxiUI()
end)

RegisterCommand('taxipos', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local formattedVector = string.format("vector3(%.2f, %.2f, %.2f)", coords.x, coords.y, coords.z)
    local formattedConfigEntry = string.format("{ id = 'loc_%d', name = 'Yeni Konum', desc = 'Ozel Pozisyon', icon = 'map-pin', coords = vector3(%.2f, %.2f, %.2f) },", math.random(100, 999), coords.x, coords.y, coords.z)

    SendNUIMessage({
        action = 'COPY_TO_CLIPBOARD',
        text = formattedVector,
        configEntry = formattedConfigEntry
    })

    Framework.Notify('Koordinat Panoya Kopyalandi: ' .. formattedVector, 'success')
end, false)

function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function LoadPedModel(modelName)
    local hash = (type(modelName) == 'number' and modelName or GetHashKey(modelName))
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        return false
    end
    RequestModel(hash)
    local attempts = 0
    while not HasModelLoaded(hash) and attempts < 50 do
        Citizen.Wait(50)
        attempts = attempts + 1
    end
    return HasModelLoaded(hash)
end

Citizen.CreateThread(function()
    if not Config.EnablePed then return end

    if Config.EnableStationBlip then
        local blipCoords = Config.StationBlipCoords or Config.PedCoords
        stationBlipEntity = AddBlipForCoord(blipCoords.x, blipCoords.y, blipCoords.z)
        SetBlipSprite(stationBlipEntity, Config.StationBlipSprite or 198)
        SetBlipColour(stationBlipEntity, Config.StationBlipColor or 5)
        SetBlipScale(stationBlipEntity, 0.8)
        SetBlipAsShortRange(stationBlipEntity, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(_L('station_blip_name'))
        EndTextCommandSetBlipName(stationBlipEntity)
    end

    local function SpawnStationPed()
        local modelToLoad = Config.PedModel or 's_m_y_taxi_01'
        if not LoadPedModel(modelToLoad) then
            modelToLoad = 'a_m_y_business_01'
            LoadPedModel(modelToLoad)
        end

        local modelHash = GetHashKey(modelToLoad)

        if DoesEntityExist(stationPedEntity) then
            DeleteEntity(stationPedEntity)
        end

        local zGround = Config.PedCoords.z - 0.98
        stationPedEntity = CreatePed(4, modelHash, Config.PedCoords.x, Config.PedCoords.y, zGround, Config.PedHeading or 0.0, false, true)
        
        if DoesEntityExist(stationPedEntity) then
            SetEntityAsMissionEntity(stationPedEntity, true, true)
            SetEntityHeading(stationPedEntity, Config.PedHeading or 0.0)
            FreezeEntityPosition(stationPedEntity, true)
            SetEntityInvincible(stationPedEntity, true)
            SetBlockingOfNonTemporaryEvents(stationPedEntity, true)
            
            if Config.PedScenario then
                TaskStartScenarioInPlace(stationPedEntity, Config.PedScenario, 0, true)
            end

            local cleanTargetLabel = _L('ped_prompt') and _L('ped_prompt'):gsub('~%a~', ''):gsub('%[.-%]%s*', '') or 'AI Taksi Cagir'
            if cleanTargetLabel == '' then cleanTargetLabel = 'AI Taksi Cagir' end

            if GetResourceState('qb-target') == 'started' then
                exports['qb-target']:AddTargetEntity(stationPedEntity, {
                    options = {
                        {
                            type = "client",
                            action = function() ToggleTaxiUI() end,
                            icon = "fas fa-taxi",
                            label = cleanTargetLabel,
                        },
                    },
                    distance = 2.5
                })
            elseif GetResourceState('ox_target') == 'started' then
                exports.ox_target:addLocalEntity(stationPedEntity, {
                    {
                        name = 'dep_ai_taxi_station_ped',
                        icon = 'fas fa-taxi',
                        label = cleanTargetLabel,
                        onSelect = function() ToggleTaxiUI() end,
                        distance = 2.5
                    }
                })
            end
        end
    end

    SpawnStationPed()

    local hasTarget = (GetResourceState('qb-target') == 'started' or GetResourceState('ox_target') == 'started')
    while true do
        local sleep = 2000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local dist = #(playerCoords - Config.PedCoords)

        if dist < 40.0 then
            if not DoesEntityExist(stationPedEntity) then
                SpawnStationPed()
            end
        end

        if dist < 20.0 then
            sleep = 500
            if not hasTarget and dist < 6.0 then
                sleep = 0
                DrawMarker(1, Config.PedCoords.x, Config.PedCoords.y, Config.PedCoords.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 0.4, 255, 183, 3, 120, false, false, 2, false, nil, nil, false)

                if dist < 2.5 then
                    DrawText3D(Config.PedCoords.x, Config.PedCoords.y, Config.PedCoords.z + 0.9, _L('ped_prompt'))
                    
                    if IsControlJustReleased(0, 38) then
                        ToggleTaxiUI()
                        Citizen.Wait(500)
                    end
                end
            end
        end

        Citizen.Wait(sleep)
    end
end)

Citizen.CreateThread(function()
    while true do
        if isUIOpen then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)

            if DoesEntityExist(veh) and veh ~= 0 then
                local speedKMH = math.floor(GetEntitySpeed(veh) * 3.6)
                local isDriving = speedKMH > 2
                local steeringAngle = GetVehicleSteeringAngle(veh)

                local nearbyVehicles = {}
                local vehPool = GetGamePool('CVehicle')
                local myCoords = GetEntityCoords(veh)

                for i = 1, #vehPool do
                    local otherVeh = vehPool[i]
                    if otherVeh ~= veh and DoesEntityExist(otherVeh) then
                        local otherCoords = GetEntityCoords(otherVeh)
                        local dist = #(myCoords - otherCoords)
                        if dist < 45.0 then
                            local offset = GetOffsetFromEntityGivenWorldCoords(veh, otherCoords.x, otherCoords.y, otherCoords.z)
                            table.insert(nearbyVehicles, {
                                relX = math.floor(offset.x * 10) / 10,
                                relY = math.floor(offset.y * 10) / 10,
                                isAhead = offset.y > 0
                            })
                            if #nearbyVehicles >= 8 then break end
                        end
                    end
                end

                SendNUIMessage({
                    action = 'UPDATE_TELEMETRY',
                    data = {
                        speedKMH = speedKMH,
                        isDriving = isDriving,
                        steeringAngle = steeringAngle,
                        nearbyVehicles = nearbyVehicles
                    }
                })
            end
            Citizen.Wait(300)
        else
            Citizen.Wait(1500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if stationPedEntity and DoesEntityExist(stationPedEntity) then
        DeleteEntity(stationPedEntity)
        stationPedEntity = nil
    end
    if stationBlipEntity and DoesBlipExist(stationBlipEntity) then
        RemoveBlip(stationBlipEntity)
        stationBlipEntity = nil
    end
end)
