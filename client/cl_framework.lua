Framework = {}
Framework.Type = 'standalone'
Framework.Core = nil

Citizen.CreateThread(function()
    if Config.Framework == 'autodetect' or Config.Framework == 'qb' then
        if GetResourceState('qb-core') == 'started' then
            Framework.Type = 'qb'
            Framework.Core = exports['qb-core']:GetCoreObject()
            print('[DepAITaxi] QBCore Framework detected and initialized.')
            return
        end
    end

    if Config.Framework == 'autodetect' or Config.Framework == 'qbx' then
        if GetResourceState('qbx_core') == 'started' then
            Framework.Type = 'qbx'
            Framework.Core = exports['qbx_core']
            print('[DepAITaxi] QBX Core Framework detected and initialized.')
            return
        end
    end

    if Config.Framework == 'autodetect' or Config.Framework == 'esx' then
        if GetResourceState('es_extended') == 'started' then
            Framework.Type = 'esx'
            Framework.Core = exports['es_extended']:getSharedObject()
            print('[DepAITaxi] ESX Framework detected and initialized.')
            return
        end
    end

    Framework.Type = 'standalone'
    print('[DepAITaxi] Running in Standalone Mode.')
end)

function Framework.Notify(msg, msgType)
    if Config and Config.EnableNotifications == false then return end
    msgType = msgType or 'primary'
    if msgType == 'info' then
        msgType = 'primary'
    end
    if Framework.Type == 'qb' and Framework.Core then
        Framework.Core.Functions.Notify(msg, msgType)
    elseif Framework.Type == 'esx' and Framework.Core then
        Framework.Core.ShowNotification(msg)
    else
        SetNotificationTextEntry('STRING')
        AddTextComponentString(msg)
        DrawNotification(false, false)
    end
end

function Framework.HasWaypoint()
    return IsWaypointActive()
end

function Framework.GetWaypointCoords()
    if not IsWaypointActive() then return nil end
    local waypoint = GetFirstBlipInfoId(8)
    if DoesBlipExist(waypoint) then
        local coords = GetBlipInfoIdCoord(waypoint)
        local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, 100.0, 0)
        if not foundGround then
            groundZ = coords.z
        end
        return vector3(coords.x, coords.y, groundZ)
    end
    return nil
end

function Framework.SetFuel(vehicle, amount)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    amount = amount or 100.0

    -- Native GTA / FiveM Fuel
    SetVehicleFuelLevel(vehicle, amount + 0.0)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fPetrolTankVolume', 100.0)

    -- Universal State Bag (used by cdn-fuel, ox_fuel, ps-fuel, qb-core modern)
    pcall(function()
        Entity(vehicle).state:set('fuel', amount + 0.0, true)
    end)

    -- Universal Decorator (LegacyFuel, cdn-fuel, standard FiveM decorators)
    pcall(function()
        if not DecorIsRegisteredAsType('_FUEL_LEVEL', 1) then
            DecorRegister('_FUEL_LEVEL', 1)
        end
        DecorSetFloat(vehicle, '_FUEL_LEVEL', amount + 0.0)
    end)

    local fuelSystem = Config.FuelSystem or 'autodetect'

    -- Explicit or Autodetected script exports
    if fuelSystem == 'cdn-fuel' or (fuelSystem == 'autodetect' and GetResourceState('cdn-fuel') == 'started') then
        pcall(function()
            exports['cdn-fuel']:SetFuel(vehicle, amount)
        end)
    end

    if fuelSystem == 'LegacyFuel' or (fuelSystem == 'autodetect' and GetResourceState('LegacyFuel') == 'started') then
        pcall(function()
            exports['LegacyFuel']:SetFuel(vehicle, amount)
        end)
    end

    if fuelSystem == 'ps-fuel' or (fuelSystem == 'autodetect' and GetResourceState('ps-fuel') == 'started') then
        pcall(function()
            exports['ps-fuel']:SetFuel(vehicle, amount)
        end)
    end

    if fuelSystem == 'ox_fuel' or (fuelSystem == 'autodetect' and GetResourceState('ox_fuel') == 'started') then
        pcall(function()
            exports['ox_fuel']:setFuel(vehicle, amount)
        end)
    end

    if fuelSystem == 'qb-fuel' or (fuelSystem == 'autodetect' and GetResourceState('qb-fuel') == 'started') then
        pcall(function()
            exports['qb-fuel']:SetFuel(vehicle, amount)
        end)
    end

    if fuelSystem == 'ti_fuel' or (fuelSystem == 'autodetect' and GetResourceState('ti_fuel') == 'started') then
        pcall(function()
            exports['ti_fuel']:setFuel(vehicle, amount)
        end)
    end

    if fuelSystem == 'okokGasStation' or (fuelSystem == 'autodetect' and GetResourceState('okokGasStation') == 'started') then
        pcall(function()
            exports['okokGasStation']:SetFuel(vehicle, amount)
        end)
    end
end

