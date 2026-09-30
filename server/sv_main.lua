local FrameworkCore = nil
local FrameworkType = 'standalone'
local ActiveTrips = {}

Citizen.CreateThread(function()
    if Config.Framework == 'autodetect' or Config.Framework == 'qb' then
        if GetResourceState('qb-core') == 'started' then
            FrameworkType = 'qb'
            FrameworkCore = exports['qb-core']:GetCoreObject()
            print('[DepAITaxi] Server: QBCore Loaded.')
            return
        end
    end

    if Config.Framework == 'autodetect' or Config.Framework == 'qbx' then
        if GetResourceState('qbx_core') == 'started' then
            FrameworkType = 'qbx'
            FrameworkCore = exports['qbx_core']
            print('[DepAITaxi] Server: QBX Core Loaded.')
            return
        end
    end

    if Config.Framework == 'autodetect' or Config.Framework == 'esx' then
        if GetResourceState('es_extended') == 'started' then
            FrameworkType = 'esx'
            FrameworkCore = exports['es_extended']:getSharedObject()
            print('[DepAITaxi] Server: ESX Loaded.')
            return
        end
    end

    FrameworkType = 'standalone'
    print('[DepAITaxi] Server: Running Standalone mode.')
end)

RegisterNetEvent('DepAITaxi:server:startTrip', function()
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    ActiveTrips[src] = {
        startTime = os.time(),
        startCoords = coords,
        baseFare = Config.BaseFare or 20.0,
        pricePerKM = Config.PricePerKM or 12.5
    }
end)

local function ProcessPayment(src, amount)
    local currency = Config.CurrencySymbol or '$'
    local account = Config.PaymentAccount or 'cash'
    local fareMsg = _L('fare_paid', currency, amount)

    if FrameworkType == 'qb' and FrameworkCore then
        local Player = FrameworkCore.Functions.GetPlayer(src)
        if Player then
            if Player.Functions.RemoveMoney(account, amount, "ai-taxi-fare") then
                if Config.EnableNotifications ~= false then
                    TriggerClientEvent('QBCore:Notify', src, fareMsg, 'success')
                end
            else
                if Player.Functions.RemoveMoney('bank', amount, "ai-taxi-fare") then
                    if Config.EnableNotifications ~= false then
                        TriggerClientEvent('QBCore:Notify', src, fareMsg, 'success')
                    end
                end
            end
        end
    elseif FrameworkType == 'esx' and FrameworkCore then
        local xPlayer = FrameworkCore.GetPlayerFromId(src)
        if xPlayer then
            if account == 'cash' then
                xPlayer.removeMoney(amount)
            else
                xPlayer.removeAccountMoney('bank', amount)
            end
            if Config.EnableNotifications ~= false then
                TriggerClientEvent('esx:showNotification', src, fareMsg)
            end
        end
    else
        print(string.format("[DepAITaxi] Player %s paid %s%s AI Taxi Fare (Standalone).", src, currency, amount))
    end
end

RegisterNetEvent('DepAITaxi:server:payFare', function(clientReportedFare)
    local src = source
    local trip = ActiveTrips[src]
    local finalAmount = tonumber(clientReportedFare) or 0

    if trip then
        local currentCoords = GetEntityCoords(GetPlayerPed(src))
        local distKM = #(currentCoords - trip.startCoords) / 1000.0
        local calculatedMin = math.floor(trip.baseFare + (distKM * trip.pricePerKM))
        if finalAmount < calculatedMin then
            finalAmount = calculatedMin
        end
        ActiveTrips[src] = nil
    end

    if finalAmount <= 0 then
        finalAmount = math.ceil(Config.BaseFare or 20.0)
    end

    ProcessPayment(src, finalAmount)
end)

RegisterNetEvent('DepAITaxi:server:cancelTrip', function()
    local src = source
    ActiveTrips[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    ActiveTrips[src] = nil
end)
