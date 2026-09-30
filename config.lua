Config = {}

Config.Language = 'en'
Config.Framework = 'autodetect'
Config.EnableNotifications = false

-- Fuel Settings
Config.FuelSystem = 'autodetect' -- Options: 'autodetect', 'cdn-fuel', 'LegacyFuel', 'ps-fuel', 'ox_fuel', 'qb-fuel', 'ti_fuel', 'okokGasStation', 'standalone'
Config.SetFullFuel = true -- Keep taxi fuel always at 100% to prevent stalls and breakdowns

Config.VehicleModel = 'vivanite2'
Config.FallbackModel = 'taxi'

Config.DriverPed = 's_m_y_taxi_01'
Config.DriverName = 'Niko Bellic'
Config.DriverRating = 4.9

Config.EnablePed = true
Config.PedModel = 's_m_y_taxi_01'
Config.PedCoords = vector3(-1030.68, -2730.95, 13.76)
Config.PedHeading = 320.0
Config.PedScenario = 'WORLD_HUMAN_CLIPBOARD'

Config.TaxiSpawnCoords = vector4(-1042.02, -2718.46, 13.67, 240.0)

Config.EnableStationBlip = true
Config.StationBlipCoords = vector3(-1030.68, -2730.95, 13.76)
Config.StationBlipSprite = 198
Config.StationBlipColor = 5
Config.StationBlipName = 'AI Taxi Station (Vivanite2)'

Config.EnableCommand = false
Config.EnableKeybind = false
Config.Command = 'aitaxi'
Config.Keybind = 'F9'

Config.SpawnDistance = 80.0

Config.BaseFare = 20.0
Config.PricePerKM = 12.5
Config.PricePerMinute = 5.0
Config.CurrencySymbol = '$'
Config.PaymentAccount = 'cash'

Config.DrivingStyles = {
    ['cautious'] = { label = 'Smooth & Safe', speed = 14.0, style = 447 },
    ['normal']   = { label = 'Normal Driving', speed = 22.0, style = 786603 },
    ['fast']     = { label = 'Fast & Aggressive', speed = 33.0, style = 2883621 },
    ['sport']    = { label = 'Sport & Performance', speed = 38.0, style = 2883621 }
}

Config.DefaultDrivingStyle = 'normal'

Config.PresetDestinations = {
    {
        id = 'waypoint',
        name = 'Map Waypoint (GPS Destination)',
        desc = 'Purple GPS waypoint set on your map',
        icon = 'map-pin',
        coords = nil
    },
    {
        id = 'legion',
        name = 'Legion Square (Downtown)',
        desc = 'City center, social gathering area',
        icon = 'building',
        coords = vector3(215.34, -810.12, 30.73)
    },
    {
        id = 'airport',
        name = 'Los Santos International Airport',
        desc = 'Flights & vehicle pickup point',
        icon = 'plane',
        coords = vector3(-1037.64, -2737.94, 20.16)
    },
    {
        id = 'pillsbury',
        name = 'Pillbox Hill Hospital',
        desc = 'Main city hospital & medical center',
        icon = 'heart-pulse',
        coords = vector3(298.54, -584.45, 43.26)
    },
    {
        id = 'mrpd',
        name = 'Mission Row Police Station (LSPD)',
        desc = 'Police department & courthouse',
        icon = 'shield-alert',
        coords = vector3(425.13, -979.55, 30.71)
    },
    {
        id = 'pier',
        name = 'Del Perro Pier & Beach',
        desc = 'Ferris wheel, beach & leisure area',
        icon = 'sun',
        coords = vector3(-1672.45, -1004.12, 13.02)
    },
    {
        id = 'sandy',
        name = 'Sandy Shores (Desert)',
        desc = 'Northern desert county & Trevor area',
        icon = 'compass',
        coords = vector3(1848.12, 3689.45, 33.87)
    },
    {
        id = 'paleto',
        name = 'Paleto Bay (North Town)',
        desc = 'Northernmost town on the map',
        icon = 'tree',
        coords = vector3(-125.45, 6451.12, 31.43)
    }
}

Config.DriverDialogue = {
    greetings = {
        "Hello sir, welcome! I am your AI driving assistant Niko. Have a safe ride.",
        "Good day! Welcome to the AI Taxi. We will head out as soon as the waypoint is set.",
        "Greetings! Our vehicle is equipped with state of the art autonomous driving."
    },
    inTrip = {
        "Los Santos traffic looks quite smooth today. We will reach our target right on time.",
        "Our smart LIDAR and radar system is constantly scanning for pedestrians and obstacles.",
        "Did you know this vehicle can perform autonomous lane changes and overtaking even at high speeds?",
        "The city view is fantastic at this hour. Please relax and enjoy the ride.",
        "The rear climate control is running at optimal temperature. Let me know if you get cold.",
        "Our navigation system calculated the safest and most comfortable route for us.",
        "Your destination area is quite popular recently. Hope you have a great day.",
        "Autonomous sensors analyze the road surface a hundred times per second for a smooth ride.",
        "We should be arriving near our destination in a couple of minutes.",
        "Feel free to adjust the cabin lighting or music anytime from the control console."
    },
    arrival = {
        "We have safely reached our destination, sir! Thank you for choosing AI Taxi and have a great day!",
        "We have arrived at your target location! Door locks are opened, please do not forget your belongings.",
        "Our journey has concluded successfully. Have a wonderful day ahead, goodbye!"
    }
}

Config.AIAssistantRules = {
    EnableVoiceInput = true,
    VoiceKey = 'N',

    CustomDialogues = {
        ["windows_open"] = {
            keywords = { "open window", "roll down window", "open windows", "fresh air", "cam", "camı aç", "camları aç" },
            response = "Rolling down the windows right away sir, enjoy the fresh air.",
            action = "windows_open"
        },
        ["windows_close"] = {
            keywords = { "close window", "roll up window", "close windows", "camı kapat", "camları kapat" },
            response = "Closing the windows for your comfort, sir.",
            action = "windows_close"
        },
        ["light_open"] = {
            keywords = { "turn on light", "interior light", "light on", "cabin light", "ışığı aç", "iç ışık" },
            response = "Turning on the cabin interior lighting sir.",
            action = "light_open"
        },
        ["light_close"] = {
            keywords = { "turn off light", "light off", "dark cabin", "ışığı kapat" },
            response = "Turning off the interior light sir.",
            action = "light_close"
        },
        ["drive_fast"] = {
            keywords = { "drive fast", "hurry up", "faster", "speed up", "overtake", "hızlı sür", "gaza bas", "hızlan" },
            response = "Stepping on the gas sir! Switching to aggressive overtaking mode.",
            action = "drive_fast"
        },
        ["drive_cautious"] = {
            keywords = { "slow down", "drive slow", "drive safe", "cautious", "yavaş sür", "sakin sür" },
            response = "Understood sir, switching to smooth and cautious driving.",
            action = "drive_cautious"
        },
        ["cancel_trip"] = {
            keywords = { "stop here", "cancel trip", "pull over", "stop vehicle", "dur", "sağa çek", "yolculuğu bitir" },
            response = "Pulling over and stopping the vehicle right away sir.",
            action = "cancel_trip"
        }
    }
}
