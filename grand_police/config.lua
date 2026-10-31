-- ─────────────────────────────────────────────────────────────
--  resources/[grand_systems]/grand_police/config.lua
--  Everything tunable: stations, offences, prison, wanted,
--  traffic, fines, MDT, blips, commands, permissions.
-- ─────────────────────────────────────────────────────────────

Config = {}

Config.Debug = false
Config.Prefix = 'grand_police'

-- ─── Factions / jobs ─────────────────────────────────────────
Config.Jobs = {
    police = { 'lspd', 'sahp', 'fib' },
    ems    = { 'ambulance', 'paramedic', 'doctors', 'pilotmedic' },
}

Config.Grades = {
    ['lspd']      = { 'Cadet', 'Trooper', 'Senior Trooper', 'Sergeant', 'Lieutenant', 'Captain', 'Chief' },
    ['sahp']      = { 'Cadet', 'Trooper', 'Senior Trooper', 'Sergeant', 'Lieutenant', 'Captain', 'Chief' },
    ['fib']       = { 'Probationary Agent', 'Agent', 'Special Agent', 'Supervisor', 'Assistant Director', 'Deputy Director', 'Director' },
    ['ambulance'] = { 'EMT', 'Senior EMT', 'Paramedic', 'Shift Supervisor', 'EMS Chief' },
    ['paramedic'] = { 'EMT', 'Senior EMT', 'Paramedic', 'Shift Supervisor', 'EMS Chief' },
}

--- Minimum grade that may use supervisor commands (warrants, records).
Config.SupervisorGrade = 2

-- ─── Stations ────────────────────────────────────────────────
--- `services` decides which faction may toggle duty there.
--- `station` coords are the duty point; `spawn` is where a duty
--- teleport puts the ped; `garage` is the fleet point.
Config.Stations = {
    {
        id = 'missionrow', label = 'Mission Row Police Department', short = 'MRPD',
        services = { police = true, ems = false },
        station = vector3(425.1, -979.5, 30.7),
        spawn = vector4(441.0, -982.0, 30.7, 90.0),
        garage = vector3(438.4, -1018.3, 28.1),
        armory = vector3(452.6, -980.0, 30.7),
        blip = { sprite = 60, colour = 38, scale = 0.9 },
        phone = '555-0100',
    },
    {
        id = 'davis', label = 'Davis Police Station', short = 'DAVIS',
        services = { police = true, ems = false },
        station = vector3(361.9, -1589.7, 29.3),
        spawn = vector4(372.0, -1605.0, 29.3, 180.0),
        garage = vector3(386.0, -1626.0, 29.3),
        armory = vector3(358.0, -1596.0, 29.3),
        blip = { sprite = 60, colour = 38, scale = 0.85 },
        phone = '555-0101',
    },
    {
        id = 'paleto', label = 'Paleto Bay Sheriff', short = 'PALETO',
        services = { police = true, ems = false },
        station = vector3(-447.6, 6011.9, 31.7),
        spawn = vector4(-441.0, 6012.0, 31.7, 45.0),
        garage = vector3(-475.0, 6025.0, 31.3),
        armory = vector3(-449.0, 6004.0, 31.7),
        blip = { sprite = 60, colour = 38, scale = 0.85 },
        phone = '555-0102',
    },
    {
        id = 'pillbox', label = 'Pillbox Hill Medical Center', short = 'PILLBOX',
        services = { police = false, ems = true },
        station = vector3(306.0, -586.4, 43.28),
        spawn = vector4(306.0, -586.4, 43.28, 73.0),
        garage = vector3(294.0, -574.0, 43.2),
        armory = vector3(311.0, -596.0, 43.3),
        blip = { sprite = 61, colour = 1, scale = 0.9 },
        phone = '555-0200',
    },
    {
        id = 'sandyhospital', label = 'Sandy Shores Medical', short = 'SANDY',
        services = { police = false, ems = true },
        station = vector3(1839.9, 475.0, 34.9),
        spawn = vector4(1839.9, 475.0, 34.9, 284.0),
        garage = vector3(1845.0, 470.0, 34.8),
        armory = vector3(1832.0, 480.0, 34.9),
        blip = { sprite = 61, colour = 1, scale = 0.85 },
        phone = '555-0201',
    },
    {
        id = 'bolingbroke', label = 'Bolingbroke Penitentiary', short = 'PRISON',
        services = { police = true, ems = false },
        station = vector3(1690.0, 2524.0, 45.5),
        spawn = vector4(1690.0, 2524.0, 45.5, 180.0),
        garage = vector3(1710.0, 2545.0, 45.5),
        armory = vector3(1684.0, 2519.0, 45.5),
        blip = { sprite = 188, colour = 4, scale = 0.9 },
        phone = '555-0300',
        prison = true,
    },
}

Config.StationIndex = {}
for _, station in ipairs(Config.Stations) do
    Config.StationIndex[station.id] = station
end

-- ─── Map / POI (fed to grand_mechanic's GrandBlips) ──────────
Config.Poi = {
    { id = 'courthouse', label = 'Los Santos County Courthouse', sprite = 419, colour = 'blue',
      coords = vector3(236.6, -411.0, 48.0), scale = 0.8 },
    { id = 'prison', label = 'Bolingbroke Penitentiary', sprite = 188, colour = 'grey',
      coords = vector3(1680.0, 2513.0, 45.5), scale = 1.0 },
    { id = 'impound', label = 'Police Impound', sprite = 68, colour = 'blue',
      coords = vector3(409.5, -1622.0, 29.3), scale = 0.8 },
}

Config.Blips = {
    enabled = true,
    prefix = 'police_',
    drawDistance = 900.0,
    promptDistance = 90.0,
    showPoi = true,
    wantedUpdateMs = 5000,
    wantedMaxBlipDistance = 1500.0,
    panicDuration = 240,
    callDuration = 180,
}

-- ─── Wanted ──────────────────────────────────────────────────
Config.Wanted = {
    maxStars = 5,
    decayMinutes = 8,          -- no new crime for this long = -1 star
    decayIntervalSeconds = 120,
    broadcastSeconds = 30,
    policeKeywords = { 'police', 'lspd', 'sahp', 'fib' },
    starsPerMinute = 8,        -- sentence minutes per star on arrest
    finePerStar = 500,
    weaponsLockedAt = 3,       -- 3+ stars cannot use holstered long guns
}

-- ─── Offences ────────────────────────────────────────────────
--- stars = wanted stars applied, fine = default fine, minutes = jail.
Config.Offences = {
    { id = 'speeding',            label = 'Speeding',                     stars = 1, fine = 250,   minutes = 0,   class = 'traffic' },
    { id = 'reckless_driving',    label = 'Reckless Driving',             stars = 2, fine = 750,   minutes = 5,   class = 'traffic' },
    { id = 'illegal_parking',     label = 'Illegal Parking',              stars = 0, fine = 150,   minutes = 0,   class = 'traffic' },
    { id = 'red_light',           label = 'Running a Red Light',          stars = 1, fine = 300,   minutes = 0,   class = 'traffic' },
    { id = 'dui',                 label = 'Driving Under the Influence',  stars = 2, fine = 1000,  minutes = 10,  class = 'traffic' },
    { id = 'street_racing',       label = 'Street Racing',                stars = 2, fine = 1500,  minutes = 15,  class = 'traffic' },
    { id = 'no_licence',          label = 'Driving Without a Licence',    stars = 1, fine = 500,   minutes = 0,   class = 'traffic' },
    { id = 'fail_to_stop',        label = 'Failing to Stop for Police',   stars = 2, fine = 1200,  minutes = 10,  class = 'traffic' },
    { id = 'assault',             label = 'Assault',                      stars = 2, fine = 1200,  minutes = 10,  class = 'violent' },
    { id = 'aggravated_assault',  label = 'Aggravated Assault',           stars = 3, fine = 2500,  minutes = 25,  class = 'violent' },
    { id = 'officer_assault',     label = 'Battery on an Officer',        stars = 3, fine = 3000,  minutes = 30,  class = 'violent' },
    { id = 'resisting_arrest',    label = 'Resisting Arrest',             stars = 2, fine = 1000,  minutes = 10,  class = 'violent' },
    { id = 'disorderly',          label = 'Disorderly Conduct',           stars = 1, fine = 500,   minutes = 0,   class = 'public' },
    { id = 'public_intox',        label = 'Public Intoxication',          stars = 1, fine = 350,   minutes = 0,   class = 'public' },
    { id = 'vandalism',           label = 'Vandalism',                    stars = 1, fine = 800,   minutes = 0,   class = 'public' },
    { id = 'graffiti',            label = 'Criminal Defacement',          stars = 1, fine = 500,   minutes = 0,   class = 'public' },
    { id = 'trespassing',         label = 'Trespassing',                  stars = 1, fine = 400,   minutes = 0,   class = 'public' },
    { id = 'domestic',            label = 'Domestic Disturbance',         stars = 2, fine = 1000,  minutes = 10,  class = 'public' },
    { id = 'stalking',            label = 'Stalking',                     stars = 2, fine = 1500,  minutes = 15,  class = 'public' },
    { id = 'burglary',            label = 'Burglary',                     stars = 3, fine = 3500,  minutes = 30,  class = 'property' },
    { id = 'robbery',             label = 'Robbery',                      stars = 4, fine = 5000,  minutes = 45,  class = 'property' },
    { id = 'armed_robbery',       label = 'Armed Robbery',                stars = 5, fine = 10000, minutes = 90,  class = 'property' },
    { id = 'grand_theft_auto',    label = 'Grand Theft Auto',             stars = 3, fine = 4000,  minutes = 35,  class = 'property' },
    { id = 'stolen_property',     label = 'Possession of Stolen Property', stars = 2, fine = 1500, minutes = 10,  class = 'property' },
    { id = 'arson',               label = 'Arson',                        stars = 4, fine = 6000,  minutes = 50,  class = 'property' },
    { id = 'drug_possession',     label = 'Drug Possession',              stars = 2, fine = 1500,  minutes = 15,  class = 'drugs' },
    { id = 'drug_trafficking',    label = 'Drug Trafficking',             stars = 4, fine = 7500,  minutes = 60,  class = 'drugs' },
    { id = 'drug_manufacturing',  label = 'Manufacturing Narcotics',      stars = 5, fine = 10000, minutes = 90,  class = 'drugs' },
    { id = 'weapon_possession',   label = 'Illegal Weapon Possession',    stars = 3, fine = 3000,  minutes = 25,  class = 'weapons' },
    { id = 'weapon_trafficking',  label = 'Weapon Trafficking',           stars = 5, fine = 12000, minutes = 90,  class = 'weapons' },
    { id = 'murder',              label = 'Murder',                       stars = 5, fine = 15000, minutes = 120, class = 'violent' },
    { id = 'attempted_murder',    label = 'Attempted Murder',             stars = 4, fine = 8000,  minutes = 60,  class = 'violent' },
    { id = 'kidnapping',          label = 'Kidnapping',                   stars = 4, fine = 8000,  minutes = 60,  class = 'violent' },
    { id = 'fraud',               label = 'Fraud',                        stars = 2, fine = 2000,  minutes = 10,  class = 'financial' },
    { id = 'money_laundering',    label = 'Money Laundering',             stars = 4, fine = 7000,  minutes = 50,  class = 'financial' },
    { id = 'bribery',             label = 'Bribery',                      stars = 3, fine = 5000,  minutes = 30,  class = 'financial' },
    { id = 'extortion',           label = 'Extortion',                    stars = 4, fine = 6000,  minutes = 45,  class = 'financial' },
    { id = 'racketeering',        label = 'Racketeering',                 stars = 5, fine = 12000, minutes = 90,  class = 'financial' },
    { id = 'obstruction',         label = 'Obstruction of Justice',       stars = 2, fine = 1500,  minutes = 10,  class = 'justice' },
    { id = 'escape',              label = 'Escape from Custody',          stars = 5, fine = 10000, minutes = 90,  class = 'justice' },
    { id = 'contraband',          label = 'Contraband in Prison',         stars = 3, fine = 3000,  minutes = 30,  class = 'justice' },
    { id = 'reckless_endanger',   label = 'Reckless Endangerment',        stars = 3, fine = 2500,  minutes = 20,  class = 'violent' },
    { id = 'terrorism',           label = 'Terrorism',                    stars = 5, fine = 25000, minutes = 180, class = 'justice' },
    { id = 'treason',             label = 'Treason',                      stars = 5, fine = 25000, minutes = 180, class = 'justice' },
}

Config.OffenceIndex = {}
for _, offence in ipairs(Config.Offences) do
    Config.OffenceIndex[offence.id] = offence
end

--- Offences grouped for MDT listing.
Config.OffenceClasses = {
    traffic = 'Traffic', violent = 'Violent', property = 'Property',
    drugs = 'Narcotics', weapons = 'Weapons', public = 'Public Order',
    financial = 'Financial', justice = 'Justice',
}

-- ─── Fines ───────────────────────────────────────────────────
Config.Fines = {
    min = 100,
    max = 25000,
    defaultDueHours = 72,
    unpaidInterest = 0.05,       -- 5% added when overdue
    maxUnpaid = 10,              -- auto-suspend licence at this count
    acceptCash = true,
    acceptBank = true,
}

-- ─── Traffic stops ───────────────────────────────────────────
Config.Traffic = {
    maxDistance = 12.0,
    stopDurationSeconds = 900,
    breathalyzerCooldown = 30,
    impoundFee = 2500,
    impoundDays = 7,
    maxStopsPerHour = 30,
}

-- ─── Prison ──────────────────────────────────────────────────
Config.Prison = {
    label = 'Bolingbroke Penitentiary',
    spawn = vector4(1641.1, 2567.8, 45.5, 270.0),
    release = vector4(1850.0, 2605.0, 45.8, 270.0),
    visitor = vector3(1791.0, 2593.0, 45.9),
    yard = vector3(1608.0, 2549.0, 45.5),
    canteen = vector3(1651.0, 2550.0, 45.5),
    maxMinutes = 180,
    defaultMinutes = 15,
    bailPerMinute = 250,
    bailEnabled = true,
    lockdownMinutes = 10,
    lockdownCooldown = 1800,
    releaseRadius = 180.0,
    sentenceCheckSeconds = 30,
    keepInventory = false,
    fineOnEscape = 10000,
    escapeExtraMinutes = 60,
}

-- ─── MDT ─────────────────────────────────────────────────────
Config.Mdt = {
    pageSize = 8,
    recordNameMax = 64,
    noteMax = 480,
    warrantHours = 72,
    boloHours = 48,
    evidenceMax = 500,
    searchLimit = 20,
    requireDuty = true,
    supervisorOnlyExpunge = true,
}

-- ─── Calls / dispatch ────────────────────────────────────────
Config.Calls = {
    cooldownSeconds = 20,
    panicCooldownSeconds = 60,
    maxActive = 40,
    defaultPriority = 2,
    priorities = { [1] = 'Low', [2] = 'Medium', [3] = 'High', [4] = 'Critical' },
    messageMax = 190,
    anonymiseCivilian = false,
}

-- ─── Duty ────────────────────────────────────────────────────
Config.Duty = {
    requireOnDutyForActions = true,
    autoOffDutyOnQuit = true,
    autoOffDutyOnDeath = false,
    stationRadius = 22.0,
    dutyBlipColour = 2,
    offDutyBlipColour = 4,
    rosterRefreshSeconds = 60,
}

-- ─── Command names ───────────────────────────────────────────
Config.Commands = {
    duty = 'duty',
    mdt = 'mdt',
    wanted = 'wanted',
    clearwanted = 'clearwanted',
    arrest = 'arrest',
    jail = 'jail',
    unjail = 'unjail',
    bail = 'bail',
    fine = 'fine',
    fines = 'fines',
    payfine = 'payfine',
    warrant = 'warrant',
    bolo = 'bolo',
    evidence = 'evidence',
    record = 'record',
    trafficstop = 'trafficstop',
    breathalyzer = 'breathalyzer',
    impound = 'impound',
    calls = 'calls',
    panic = 'panic',
    revive = 'revive',
    heal = 'heal',
    license = 'license',
    policeadmin = 'policeadmin',
    radio = 'radio',
}

-- ─── Permissions ─────────────────────────────────────────────
Config.Permissions = {
    admin = 'grand.police.admin',
    supervisor = 'grand.police.supervisor',
    mdt = 'grand.police.mdt',
    prison = 'grand.police.prison',
    aceGroups = { 'group.admin', 'group.mod' },
}

-- ─── Text ────────────────────────────────────────────────────
Config.Text = {
    noDuty = 'You must be on duty.',
    noFaction = 'You are not a police officer or paramedic.',
    noStation = 'You must be at a station to toggle duty.',
    noTarget = 'Player not found.',
    tooFar = 'That player is too far away.',
    notWanted = 'That player is not wanted.',
    noReason = 'A reason is required.',
    rateLimited = 'Slow down.',
    jailed = '%s was sentenced to %d minutes.',
    released = '%s has been released.',
    fineIssued = 'Fine of %s issued to %s.',
    finePaid = 'Fine paid: %s.',
    noFines = 'No unpaid fines.',
    wantedSet = '%s is now %d star wanted.',
    wantedCleared = 'Wanted level cleared for %s.',
    cuffed = 'Suspect detained.',
    revived = 'You revived %s.',
}
