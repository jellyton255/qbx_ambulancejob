local GovernmentData = exports.ef_nexus:GetGovernmentData("EFEmergency")

return {
    reviveCost = GovernmentData.ReviveCost,        -- Price patient has to pay when they're revived
    checkInCost = GovernmentData.HospitalBillCost, -- Price for using the hospital check-in system
    minForCheckIn = 20,                            -- Minimum number of people with the ambulance job to prevent the check-in system from being used

    locations = {                                  -- Various interaction points
        duty = {
            vector3(-260.31, 6319.41, 32.45),      -- Paleto Medical

            vector3(1664.8, 3659.79, 35.27),       -- Sandy

            vector3(-432.69, -318.04, 35.13),      -- Mount Zonah Timeclock

            vector3(349.26, -1429.4, 32.43),       -- Central LS
            vector3(351.31, -1405.04, 32.53),      -- Central LS
        },
        armory = {
            {
                shopType = 'AmbulanceArmory',
                name = 'Armory',
                groups = { fire = 0 },
                inventory = {
                    { name = "radio",                   price = 0, count = 50, },
                    { name = "bandage",                 price = 0, count = 50, },
                    { name = "painkillers",             price = 0, count = 50, },
                    { name = "firstaid",                price = 0, count = 50, },
                    { name = "WEAPON_FLASHLIGHT",       price = 0, count = 50, },
                    { name = "WEAPON_FIREEXTINGUISHER", price = 0, count = 50, },
                    { name = "WEAPON_FLARE",            price = 0, },
                },
                locations = {
                    vector3(-262.46, 6323.93, 32.50), -- Paletovector3(-1881.27, -356.85, 41.25),
                    vector3(1660.77, 3659.96, 35.34), --Sandy
                    vector3(-453.65, -308.06, 35.32), -- Mount Zonah Closet
                    vector3(381.11, -1409.68, 33.21), -- Central LS
                }
            }
        },

        ---@class Bed
        ---@field coords vector4
        ---@field model number

        ---@type table<string, {coords: vector3, checkIn?: vector3, beds: Bed[]}>
        hospitals = {
            zonah = {
                coords = vector3(-435.73, -325.32, 34.81),
                checkIn = vector3(-435.73, -325.32, 34.81),
                beds = {
                    { coords = vector4(-459.01, -279.77, 34.84, 205.9),  model = 2117668672 },
                    { coords = vector4(-455.17, -278.05, 35.84, 205.65), model = 2117668672 },
                    { coords = vector4(-451.49, -285.19, 35.83, 27.95),  model = 2117668672 },
                    { coords = vector4(-448.35, -283.65, 35.83, 22.96),  model = 2117668672 },
                },
            },
            centralls = {
                coords = vector3(348.75, -1402.86, 32.64),
                checkIn = vector3(348.75, -1402.86, 32.64),
                beds = {
                    { coords = vector4(326.61, -1408.38, 33.13, 47.87),  model = -708683881 },
                    { coords = vector4(325.12, -1410.3, 33.15, 48.05),   model = -708683881 },
                    { coords = vector4(323.56, -1412.16, 33.15, 52.09),  model = -708683881 },
                    { coords = vector4(322.0, -1414.0, 33.13, 50.84),    model = -708683881 },
                    { coords = vector4(318.37, -1410.37, 33.13, 318.77), model = -708683881 },
                    { coords = vector4(316.37, -1408.87, 33.15, 317.32), model = -708683881 },
                    { coords = vector4(314.54, -1407.25, 33.15, 312.95), model = -708683881 },
                },
            },
            paleto = {
                coords = vector3(-250.97, 6336.20, 32.25),
                checkIn = vector3(-250.97, 6336.20, 32.25),
                beds = {
                    { coords = vector4(-255.21, 6307.02, 32.45, 45.73), model = 1004440924 },
                    { coords = vector4(-251.46, 6310.49, 33.45, 45.29), model = 1004440924 },
                    { coords = vector4(-247.79, 6314.32, 33.45, 46.13), model = 1004440924 },
                    { coords = vector4(-244.54, 6317.94, 33.45, 45.66), model = 1004440924 },
                },
            },
            sandy = {
                coords = vector3(1674.57, 3666.8, 35.14),
                checkIn = vector3(1674.57, 3666.8, 35.14),
                beds = {
                    { coords = vector4(1676.07, 3647.12, 35.34, 30), model = 1004440924 },
                    { coords = vector4(1671.83, 3644.67, 35.34, 30), model = 1004440924 },
                    { coords = vector4(1667.24, 3642.03, 35.34, 30), model = 1004440924 },
                    { coords = vector4(1662.83, 3639.48, 35.34, 30), model = 1004440924 },

                },
            },
            jail = {
                coords = vec3(1761, 2600, 46),
                beds = {
                    { coords = vector4(1761.96, 2597.74, 45.66, 270.14), model = 2117668672 },
                    { coords = vector4(1761.96, 2591.51, 45.66, 269.8),  model = 2117668672 },
                    { coords = vector4(1771.8, 2598.02, 45.66, 89.05),   model = 2117668672 },
                    { coords = vector4(1771.85, 2591.85, 45.66, 91.51),  model = 2117668672 },
                },
            },
        },
        stations = {
            { label = "Medical Center", coords = vector3(-251.03, 6321.97, 37.62) }, -- Paleto Medical
            { label = "Medical Center", coords = vector3(1664.8, 3659.79, 35.27) },  -- Sandy Medical
            { label = "Medical Center", coords = vector3(-447.11, -341.41, 34.5) },  -- Mount Zonah
            { label = "Medical Center", coords = vector3(361.88, -1410.51, 32.52) }, -- Central LS
        }
		
    },
    reviveDuration = { -- Correspond job grade numbers to their Duration of time it takes to revive someone
		default = 100000,
		[0] = 80000, --Candidate
		[1] = 60000, --Firefighter 1
		[2] = 50000, --Firefighter 2
		[3] = 40000, --Firefighter 3
		[4] = 30000, --Engineer
		[5] = 20000, --Paramedic
		[6] = 10000, --Lieutenant
		[7] = 8000, --Captain
		[8] = 5000,  --Battalion Chief
		[9] = 5000,  --Deputy District Chief
		[10] = 5000, --District Chief
		[11] = 5000, --High Command
		[12] = 5000, --Commissioner
	},  
}