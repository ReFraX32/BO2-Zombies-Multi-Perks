#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_stats;
#include maps\mp\zombies\_zm_perks;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_score;
#include maps\mp\zombies\_zm_laststand;
#include maps\mp\zombies\_zm_spawner;

init()
{
    level._effect["poltergeist"] = loadfx( "misc/fx_zombie_couch_effect" );
    // Winter's Wail: white mist cloud + blue glow, both ship with every map
    level._effect["winters_wail"] = loadfx( "weapon/thunder_gun/fx_thundergun_smoke_cloud" );
    level._effect["winters_wail_eyes"] = loadfx( "maps/zombie/fx_zombie_eye_returned_blue" );
    level._effect["vigor_rush_impact"] = loadfx("impacts/fx_large_woodhit");
    
    level.multi_mule_kick_machine = getEnt("vending_additionalprimaryweapon", "targetname");
    level.multi_juggernog_machine = getEnt("vending_jugg", "targetname");
    level.multi_staminup_machine = getEnt("vending_marathon", "targetname");
    level.multi_speedcola_machine = getEnt("vending_sleight", "targetname");
    level.multi_quickrevive_machine = getEnt("vending_revive", "targetname");
    level.multi_doubletap_machine = getEnt("vending_doubletap", "targetname");
    
    if(isDefined(level.multi_mule_kick_machine))
        level.multi_mule_kick_origin = level.multi_mule_kick_machine.origin;
    if(isDefined(level.multi_juggernog_machine))
        level.multi_juggernog_origin = level.multi_juggernog_machine.origin;
    if(isDefined(level.multi_staminup_machine))
        level.multi_staminup_origin = level.multi_staminup_machine.origin;
    if(isDefined(level.multi_speedcola_machine))
        level.multi_speedcola_origin = level.multi_speedcola_machine.origin;
    if(isDefined(level.multi_quickrevive_machine))
        level.multi_quickrevive_origin = level.multi_quickrevive_machine.origin;
    if(isDefined(level.multi_doubletap_machine))
        level.multi_doubletap_origin = level.multi_doubletap_machine.origin;
    
    dvar_val = getDvarFloat("perk_weapRateMultiplier");
    if(dvar_val <= 0.0)
        level.default_weap_rate_mult = 1.0;
    else
        level.default_weap_rate_mult = dvar_val;

    dvar_reload = getDvarFloat("perk_weapReloadMultiplier");
    if(dvar_reload <= 0.0)
        level.default_weap_reload_mult = 0.5;
    else
        level.default_weap_reload_mult = dvar_reload;
    
    level.get_player_weapon_limit = ::custom_get_player_weapon_limit;
    level._game_module_point_adjustment = ::point_crusher_multiplier;
    level.original_game_module_game_end_check = level._game_module_game_end_check;
    level._game_module_game_end_check = ::fighters_fizz_game_end_check;
    level thread register_zombie_damage_callback( ::custom_zombie_damage_multiplier );
    level thread register_zombie_death_event_callback( ::vulture_zombie_death );
    level thread register_zombie_death_event_callback( ::fighters_fizz_zombie_death );
    if(!isDefined(level.player_damage_callbacks))
        level.player_damage_callbacks = [];
    if(level.player_damage_callbacks.size == 0)
        level.player_damage_callbacks[0] = ::multi_perks_player_damage_wrapper;
    level thread enforce_mod_compatibility();

    level.vulture_stink_clouds = [];

    level.perk_purchase_limit = 99;

    // Who's Who: the chugabud code ships in every map's fastfile (included by _zm_perks)
    // but _zm_perks only enables it when the map sets zombiemode_using_chugabud_perk
    // (Die Rise only). Calling init() ourselves defines level.chugabud_laststand_func,
    // which is the hook _zm.gsc uses to run the clone last-stand on every map.
    maps\mp\zombies\_zm_chugabud::init();
    // custom last stand: keeps perks, weapons and mod upgrades in shadow mode
    // (the stock one strips everything via the "fake_death" notify, see perk_think)
    level.chugabud_laststand_func = ::whos_who_laststand;

    if (getdvar("mapname") == "zm_tomb")
    {
        level.tomb_doubletap_origin = (-580, 3620, -295);
        level thread spawn_custom_doubletap_machine();
    }

    if (getdvar("mapname") == "zm_prison")
    {
        level.prison_staminup_origin = (197, 8462, 779);
        level thread spawn_custom_staminup_machine();
        level.staminup_bottle = "zombie_perk_bottle_doubletap";
    }
    else
    {
        level.staminup_bottle = "zombie_perk_bottle_marathon";
    }

    if ( getdvar("mapname") == "zm_buried" || getdvar("mapname") == "zm_tomb" )
    {
        level._effect["exo_slam_explosion"] = level._effect["divetonuke_groundhit"];
    }
    else
    {
        level._effect["exo_slam_explosion"] = loadfx("explosions/fx_default_explosion");
    }

    level thread monitor_spent_points();
    level._zm_blocker_trigger_think_return_override = ::repairman_barrier_override;
    level.original_zbarrier_tear_override = level.zbarrier_zombie_tear_notetrack_override;
    level.zbarrier_zombie_tear_notetrack_override = ::repairman_tear_chunk_callback;

    level thread onPlayerConnect();
}

spawn_custom_doubletap_machine()  
{  
    if(!isDefined(level.tomb_doubletap_origin)) return;
    
    position = level.tomb_doubletap_origin;
    angles = (0, 90, 0);
      
    machine = spawn("script_model", position);
    machine setmodel("zombie_vending_marathon_on");
    machine.angles = angles;
    
    collision = spawn("script_model", position, 1);
    collision.angles = angles;
    collision setmodel("zm_collision_perks1");
    collision.script_noteworthy = "clip";
    collision disconnectpaths();
}

spawn_custom_staminup_machine()
{  
    if(!isDefined(level.prison_staminup_origin)) return;
    
    position = level.prison_staminup_origin;
    angles = (0, 180, 0);
      
    machine = spawn("script_model", position);
    machine setmodel("p6_zm_al_vending_doubletap2_on");
    machine.angles = angles;
    
    collision = spawn("script_model", position, 1);
    collision.angles = angles;
    collision setmodel("zm_collision_perks1");
    collision.script_noteworthy = "clip";
    collision disconnectpaths();
}

create_trigger_radius(hint_text, origin)
{
    trigger = spawn("trigger_radius", origin, 1, 70, 70);
    trigger setcursorhint("HINT_NOICON");
    trigger sethintstring(hint_text);
    trigger setinvisibletoall();
    if(isPlayer(self))
        trigger setvisibletoplayer(self);
    return trigger;
}

onPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);
        player thread onPlayerSpawned();
    }
}

onPlayerSpawned()
{
    self endon("disconnect");
    level endon("game_ended");
    for(;;)
    {
        self waittill("spawned_player");
        self reset_perk_values();
        self thread check_proximity_to_machines();
        self thread perk_bought_check();
        self thread monitor_staminup_speed();
        self thread monitor_juggernog_health();
        self thread dam_a_nade_round_watcher();
        self thread fighters_fizz_watcher();
        self thread monitor_player_weapons();
    }
}

reset_perk_values()
{
    self.hasMuleKickOnce = false;
    self.multi_mule_kick_counter = 1;
    self.starting_mule_kick_price = 4000;
    self.mule_kick_price = self.starting_mule_kick_price;
    self.weapon_limit_counter = 3;
    self.original_mule_kick_machine_location = undefined;
    self.current_mule_kick_trigger = undefined;
    self.last_mule_kick_purchase_time = 0;
    self.can_buy_multi_mule = false;

    self.hasJuggernogOnce = false;
    self.multi_juggernog_counter = 1;
    self.starting_jugger_price = 5000;
    self.jugger_price = self.starting_jugger_price;
    self.original_jugger_machine_location = undefined;
    self.current_jugger_trigger = undefined;
    self.last_jugger_purchase_time = 0;
    self.can_buy_multi_jugger = false;

    self.has_vulture = false;
    self.vulture_price = 3000;
    self.can_buy_vulture = false;

    self.has_ethereal_razor = false;
    self.ethereal_razor_level = 0;
    self.ethereal_razor_price = 3000;
    self.can_buy_ethereal_razor = false;

    self.has_dam_a_nade = false;
    self.dam_a_nade_level = 0;
    self.dam_a_nade_price = 2500;
    self.can_buy_dam_a_nade = false;

    self.hasJetpackOnce = false;
    self.jetpack_price = 4000;
    self.has_jetpack = false;
    self.original_staminup_machine_location = undefined;
    self.current_staminup_trigger = undefined;
    self.last_staminup_purchase_time = 0;
    self.can_buy_jetpack = false;

    self.multi_staminup_counter = 0;
    self.starting_staminup_price = 2000;
    self.staminup_price = self.starting_staminup_price;
    self.can_buy_staminup = false;
    self setmovespeedscale(1.0);

    self.has_bandolier_bandit = false;
    self.bandolier_bandit_level = 0;
    self.bandolier_bandit_price = 3000;
    self.can_buy_bandolier_bandit = false;
    self.bandolier_stash = [];
    self.bandolier_prev_stock = [];
    self.bandolier_hud = undefined;

    self.has_blood_bullets = false;
    self.blood_bullets_price = 3000;
    self.can_buy_blood_bullets = false;

    self.has_nitrogen_cooled = false;
    self.nitrogen_cooled_price = 2000;
    self.can_buy_nitrogen_cooled = false;

    self.hasPointCrusherOnce = false;
    self.multi_pointcrusher_counter = 0;
    self.starting_pointcrusher_price = 4000;
    self.pointcrusher_price = self.starting_pointcrusher_price;
    self.point_multiplier = 1;
    self.original_speedcola_machine_location = undefined;
    self.current_speedcola_trigger = undefined;
    self.last_speedcola_purchase_time = 0;
    self.can_buy_pointcrusher = false;

    self.multi_speedcola_counter = 0;
    self.starting_speedcola_price = 3000;
    self.speedcola_price = self.starting_speedcola_price;
    self.can_buy_speedcola = false;
    if(isDefined(level.default_weap_reload_mult))
    {
        self setclientdvar("perk_weapReloadMultiplier", "" + level.default_weap_reload_mult);
        setdvar("perk_weapReloadMultiplier", level.default_weap_reload_mult);
    }

    self.has_cashback = false;
    self.cashback_level = 0;
    self.cashback_price = 3000;
    self.can_buy_cashback = false;

    self.has_repairman = false;
    self.repairman_level = 0;
    self.repairman_price = 2000;
    self.can_buy_repairman = false;

    self.has_muscle_milk = false;
    self.muscle_milk_price = 3000;
    self.muscle_milk_cooldown = false;
    self.original_quickrevive_machine_location = undefined;
    self.current_quickrevive_trigger = undefined;
    self.last_quickrevive_purchase_time = 0;
    self.can_buy_muscle_milk = false;

    self.has_whos_who = false;
    self.whos_who_price = 2000;
    self.can_buy_whos_who = false;

    self.has_fighters_fizz = false;
    self.fighters_fizz_price = 3500;
    self.can_buy_fighters_fizz = false;

    self.hasPunchColaOnce = false;
    self.multi_punchcola_counter = 1;
    self.starting_punchcola_price = 5000;
    self.punchcola_price = self.starting_punchcola_price;
    self.punchcola_damage_level = 1;
    self.original_doubletap_machine_location = undefined;
    self.current_doubletap_trigger = undefined;
    self.last_doubletap_purchase_time = 0;
    self.can_buy_punchcola = false;

    self.has_winters_wail = false;
    self.winters_wail_price = 4000;
    self.winters_wail_charges = 0;
    self.winters_wail_lock = false;
    self.winters_wail_invulnerable = false;
    self.can_buy_winters_wail = false;

    self.has_doubletap_1 = false;
    self.doubletap_1_counter = 1;
    self.starting_doubletap_1_price = 2000;
    self.doubletap_1_price = self.starting_doubletap_1_price;
    self.doubletap_1_level = 0;
    self.can_buy_doubletap_1 = false;

    self.has_vigor_rush = false;
    self.vigor_rush_price = 3000;
    self.can_buy_vigor_rush = false;
    if(isDefined(level.default_weap_rate_mult))
    {
        self setclientdvar("perk_weapRateMultiplier", "" + level.default_weap_rate_mult);
        setdvar("perk_weapRateMultiplier", level.default_weap_rate_mult);
    }

    self.had_mule_kick = false;
    self.had_juggernog = false;
    self.had_staminup = false;
    self.had_speedcola = false;
    self.had_quickrevive = false;
    self.had_doubletap = false;

    self.machine_is_in_use = false;
    self.is_purchasing = false;
    self.num_perks = 0;
    self.perk_reminder = 0;
    self.perk_count = 0;
    self.perks_given = 0;
}

is_perk_paused(perk)
{
    if(isDefined(self.disabled_perks) && isDefined(self.disabled_perks[perk]) && self.disabled_perks[perk])
        return true;
    return false;
}

is_perk_machine_powered(perk_name)
{
    vending_triggers = getentarray("zombie_vending", "targetname");
    for(i = 0; i < vending_triggers.size; i++)
    {
        trig = vending_triggers[i];
        if(isDefined(trig.script_noteworthy) && trig.script_noteworthy == perk_name)
        {
            if(isDefined(trig.power_on))
                return (trig.power_on == 1);
        }
    }
    return true;
}

get_perk_name_for_type(perk_type)
{
    switch(perk_type)
    {
        case "mule_kick":
            return "specialty_additionalprimaryweapon";
        case "jugger":
            return "specialty_armorvest";
        case "staminup":
            return "specialty_longersprint";
        case "speedcola":
            return "specialty_fastreload";
        case "quickrevive":
            return "specialty_quickrevive";
        case "doubletap":
            return "specialty_rof";
    }
    return undefined;
}

cleanup_perk_trigger(perk_type)
{
    if(perk_type == "mule_kick" && isDefined(self.current_mule_kick_trigger))
    {
        self.current_mule_kick_trigger delete();
        self.current_mule_kick_trigger = undefined;
    }
    else if(perk_type == "jugger" && isDefined(self.current_jugger_trigger))
    {
        self.current_jugger_trigger delete();
        self.current_jugger_trigger = undefined;
    }
    else if(perk_type == "staminup" && isDefined(self.current_staminup_trigger))
    {
        self.current_staminup_trigger delete();
        self.current_staminup_trigger = undefined;
    }
    else if(perk_type == "staminup_buy" && isDefined(self.buy_staminup_trigger))
    {
        self.buy_staminup_trigger delete();
        self.buy_staminup_trigger = undefined;
    }
    else if(perk_type == "speedcola" && isDefined(self.current_speedcola_trigger))
    {
        self.current_speedcola_trigger delete();
        self.current_speedcola_trigger = undefined;
    }
    else if(perk_type == "quickrevive" && isDefined(self.current_quickrevive_trigger))
    {
        self.current_quickrevive_trigger delete();
        self.current_quickrevive_trigger = undefined;
    }
    else if(perk_type == "doubletap" && isDefined(self.current_doubletap_trigger))
    {
        self.current_doubletap_trigger delete();
        self.current_doubletap_trigger = undefined;
    }
    else if(perk_type == "doubletap_buy" && isDefined(self.buy_doubletap_trigger))
    {
        self.buy_doubletap_trigger delete();
        self.buy_doubletap_trigger = undefined;
    }
}

get_perk_machine_location(perk_type)
{
    targetname = undefined;
    script_noteworthy = undefined;
    
    switch(perk_type)
    {
        case "mule_kick":
            targetname = "vending_additionalprimaryweapon";
            script_noteworthy = "specialty_additionalprimaryweapon";
            break;
        case "jugger":
            targetname = "vending_jugg";
            script_noteworthy = "specialty_armorvest";
            break;
        case "staminup":
        case "staminup_buy":
            if(getDvar("mapname") == "zm_prison" && isDefined(level.prison_staminup_origin))
                return level.prison_staminup_origin;
            targetname = "vending_marathon";
            script_noteworthy = "specialty_longersprint";
            break;
        case "speedcola":
            targetname = "vending_sleight";
            script_noteworthy = "specialty_fastreload";
            break;
        case "quickrevive":
            if(getDvar("mapname") == "zm_tomb")
                return (2355.26, 5033.44, -303.875);
            targetname = "vending_revive";
            script_noteworthy = "specialty_quickrevive";
            break;
        case "doubletap":
        case "doubletap_buy":
            if(getDvar("mapname") == "zm_tomb" && isDefined(level.tomb_doubletap_origin))
                return level.tomb_doubletap_origin;
            targetname = "vending_doubletap";
            script_noteworthy = "specialty_rof";
            break;
    }
    
    if(isDefined(targetname))
    {
        ent = getEnt(targetname, "targetname");
        if(isDefined(ent))
            return ent.origin;
    }
    
    if(isDefined(script_noteworthy))
    {
        vending_triggers = getentarray("zombie_vending", "targetname");
        for(i = 0; i < vending_triggers.size; i++)
        {
            if(isDefined(vending_triggers[i].script_noteworthy) && vending_triggers[i].script_noteworthy == script_noteworthy)
                return vending_triggers[i].origin;
        }
    }
    
    switch(perk_type)
    {
        case "mule_kick":
            if(isDefined(level.multi_mule_kick_origin)) return level.multi_mule_kick_origin;
            break;
        case "jugger":
            if(isDefined(level.multi_juggernog_origin)) return level.multi_juggernog_origin;
            break;
        case "staminup":
        case "staminup_buy":
            if(isDefined(level.multi_staminup_origin)) return level.multi_staminup_origin;
            break;
        case "speedcola":
            if(isDefined(level.multi_speedcola_origin)) return level.multi_speedcola_origin;
            break;
        case "quickrevive":
            if(isDefined(level.multi_quickrevive_origin)) return level.multi_quickrevive_origin;
            break;
        case "doubletap":
        case "doubletap_buy":
            if(isDefined(level.multi_doubletap_origin)) return level.multi_doubletap_origin;
            break;
    }
    
    return undefined;
}

get_player_perk_machine_location(perk_type)
{
    loc = undefined;
    switch(perk_type)
    {
        case "mule_kick":
            loc = self.original_mule_kick_machine_location;
            break;
        case "jugger":
            loc = self.original_jugger_machine_location;
            break;
        case "staminup":
            loc = self.original_staminup_machine_location;
            break;
        case "speedcola":
            loc = self.original_speedcola_machine_location;
            break;
        case "quickrevive":
            loc = self.original_quickrevive_machine_location;
            break;
        case "doubletap":
            loc = self.original_doubletap_machine_location;
            break;
    }
    
    if(!isDefined(loc))
    {
        loc = get_perk_machine_location(perk_type);
        if(isDefined(loc))
        {
            switch(perk_type)
            {
                case "mule_kick": self.original_mule_kick_machine_location = loc; break;
                case "jugger": self.original_jugger_machine_location = loc; break;
                case "staminup": self.original_staminup_machine_location = loc; break;
                case "speedcola": self.original_speedcola_machine_location = loc; break;
                case "quickrevive": self.original_quickrevive_machine_location = loc; break;
                case "doubletap": self.original_doubletap_machine_location = loc; break;
            }
        }
    }
    else if(getDvar("mapname") == "zm_highrise")
    {
        fresh_loc = get_perk_machine_location(perk_type);
        if(isDefined(fresh_loc))
        {
            loc = fresh_loc;
            switch(perk_type)
            {
                case "mule_kick": self.original_mule_kick_machine_location = loc; break;
                case "jugger": self.original_jugger_machine_location = loc; break;
                case "staminup": self.original_staminup_machine_location = loc; break;
                case "speedcola": self.original_speedcola_machine_location = loc; break;
                case "quickrevive": self.original_quickrevive_machine_location = loc; break;
                case "doubletap": self.original_doubletap_machine_location = loc; break;
            }
        }
    }
    return loc;
}

check_proximity_to_machines()
{
    self endon("disconnect");
    self endon("death");
    
    while(true)
    {
        if(self hasPerk("specialty_additionalprimaryweapon") && !self.is_purchasing)
            self check_perk_proximity("mule_kick", self get_player_perk_machine_location("mule_kick"), self.last_mule_kick_purchase_time);
        
        if(self hasPerk("specialty_armorvest") && !self.is_purchasing)
            self check_perk_proximity("jugger", self get_player_perk_machine_location("jugger"), self.last_jugger_purchase_time);
        
        if(self hasPerk("specialty_longersprint") && !self.is_purchasing)
            self check_perk_proximity("staminup", self get_player_perk_machine_location("staminup"), self.last_staminup_purchase_time);
        else if(getdvar("mapname") == "zm_prison" && !self hasPerk("specialty_longersprint") && !self.is_purchasing)
            self check_perk_proximity("staminup_buy", level.prison_staminup_origin, 0);
        
        if(self hasPerk("specialty_fastreload") && !self.is_purchasing)
            self check_perk_proximity("speedcola", self get_player_perk_machine_location("speedcola"), self.last_speedcola_purchase_time);
        
        if(self hasPerk("specialty_quickrevive") && !self.is_purchasing)
            self check_perk_proximity("quickrevive", self get_player_perk_machine_location("quickrevive"), self.last_quickrevive_purchase_time, self.has_muscle_milk && self.has_whos_who && self.has_fighters_fizz);

        if(self hasPerk("specialty_rof") && !self.is_purchasing)
            self check_perk_proximity("doubletap", self get_player_perk_machine_location("doubletap"), self.last_doubletap_purchase_time);
        else if(getdvar("mapname") == "zm_tomb" && !self hasPerk("specialty_rof") && !self.is_purchasing)
            self check_perk_proximity("doubletap_buy", level.tomb_doubletap_origin, 0);
        else if(!self hasPerk("specialty_rof") && !self.is_purchasing)
        {
            dt_loc = self get_player_perk_machine_location("doubletap");
            if(isDefined(dt_loc) && distance(self.origin, dt_loc) <= 70)
            {
                if(self adsButtonPressed())
                {
                    held = true;
                    for(i = 0; i < 12; i++)
                    {
                        wait 0.05;
                        if(!self adsButtonPressed() || distance(self.origin, dt_loc) > 70)
                        {
                            held = false;
                            break;
                        }
                    }
                    if(held)
                    {
                        self playsound("evt_perk_deny");
                        self iprintln("^1Requires Double Tap Root Beer first!");
                        while(self adsButtonPressed())
                            wait 0.05;
                    }
                }
            }
        }
        
        wait 0.2;
    }
}

check_perk_proximity(perk_type, machine_location, last_purchase_time, additional_condition)
{
    if(!isDefined(machine_location))
        return;

    perk_name = get_perk_name_for_type(perk_type);
    if(isDefined(perk_name) && !is_perk_machine_powered(perk_name))
    {
        cleanup_perk_trigger(perk_type);
        return;
    }
        
    if(distance(self.origin, machine_location) <= 70 && !self.machine_is_in_use && (!isDefined(additional_condition) || !additional_condition))
    {
        if(GetTime() - last_purchase_time >= 200)
        {
            if(perk_type == "mule_kick")
                self thread show_multi_mule_kick_prompt();
            else if(perk_type == "jugger")
                self thread show_multi_juggernog_prompt();
            else if(perk_type == "staminup")
                self thread show_staminup_prompt();
            else if(perk_type == "staminup_buy")
                self thread show_staminup_buy_prompt();
            else if(perk_type == "speedcola")
                self thread show_speedcola_pointcrusher_prompt();
            else if(perk_type == "quickrevive")
                self thread show_muscle_milk_prompt();
            else if(perk_type == "doubletap")
                self thread show_punchcola_prompt();
            else if(perk_type == "doubletap_buy")
                self thread show_doubletap_buy_prompt();
        }
    }
    else
    {
        cleanup_perk_trigger(perk_type);
    }
}

show_perk_prompt_core(trigger_var, perk_name, price, machine_location, purchase_func, extra_condition)
{
    while(self isTouching(trigger_var) && self hasPerk(perk_name) && !self.machine_is_in_use && !self.is_purchasing && !extra_condition)
    {
        if(self useButtonPressed() && self.score >= price && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(isDefined(trigger_var))
            {
                trigger_var delete();
                trigger_var = undefined;
            }
            if(distance(self.origin, machine_location) <= 70)
                self thread [[purchase_func]]();
            break;
        }
        else if(self useButtonPressed() && self.score < price)
        {
            if(distance(self.origin, machine_location) <= 70)
            {
                self playsound("evt_perk_deny");
                self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                while(self useButtonPressed())
                    wait 0.05;
            }
        }
        wait 0.1;
    }
}

show_buy_prompt_core(trigger_var, perk_name, price, machine_location, purchase_func)
{
    while(self isTouching(trigger_var) && !self hasPerk(perk_name) && !self.machine_is_in_use && !self.is_purchasing)
    {
        if(self useButtonPressed() && self.score >= price && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(isDefined(trigger_var))
            {
                trigger_var delete();
                trigger_var = undefined;
            }
            if(distance(self.origin, machine_location) <= 70)
                self thread [[purchase_func]]();
            break;
        }
        else if(self useButtonPressed() && self.score < price)
        {
            if(distance(self.origin, machine_location) <= 70)
            {
                self playsound("evt_perk_deny");
                self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                while(self useButtonPressed())
                    wait 0.05;
            }
        }
        wait 0.1;
    }
}

show_multi_mule_kick_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_additionalprimaryweapon") || self.is_purchasing || !self.can_buy_multi_mule)
        return;
    if(isDefined(self.current_mule_kick_trigger))
        return;
    self.current_mule_kick_trigger = self create_trigger_radius("Hold ^3[{+activate}]^7 for Multi-Mule Kick [Cost: " + self.mule_kick_price + "]", self.original_mule_kick_machine_location + (0, 0, 30));
    self show_perk_prompt_core(self.current_mule_kick_trigger, "specialty_additionalprimaryweapon", self.mule_kick_price, self.original_mule_kick_machine_location, ::process_multi_mule_kick_purchase, false);
    if(isDefined(self.current_mule_kick_trigger))
    {
        self.current_mule_kick_trigger delete();
        self.current_mule_kick_trigger = undefined;
    }
}

get_jugg_hint_string(is_aiming)
{
    hint = "";
    if(is_aiming)
    {
        if(self.can_buy_ethereal_razor)
            hint = "Hold ^3[{+activate}]^7 for Ethereal Razor [Cost: " + self.ethereal_razor_price + "]";
        if(self.can_buy_dam_a_nade)
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Press ^3[{+melee}]^7 for Dam-A-Nade [Cost: " + self.dam_a_nade_price + "]";
        }
    }
    else
    {
        if(self.can_buy_multi_jugger)
            hint = "Hold ^3[{+activate}]^7 for Multi-Juggernog [Cost: " + self.jugger_price + "]";
        if(!self.has_vulture && self.can_buy_vulture)
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Press ^3[{+melee}]^7 for Vulture Aid [Cost: " + self.vulture_price + "]";
        }
        if(hint != "")
            hint += " ^1|^7 ";
        hint += "Aim ^3[{+speed_throw}]^7 for More";
    }
    return hint;
}

show_multi_juggernog_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_armorvest") || self.is_purchasing)
        return;
    if(!self.can_buy_multi_jugger && (self.has_vulture || !self.can_buy_vulture) && !self.can_buy_ethereal_razor && !self.can_buy_dam_a_nade)
        return;
    if(isDefined(self.current_jugger_trigger))
        return;

    hint = self get_jugg_hint_string(self adsButtonPressed());
    if(hint != "")
        self.current_jugger_trigger = self create_trigger_radius(hint, self.original_jugger_machine_location + (0, 0, 30));
    if(!isDefined(self.current_jugger_trigger))
        return;
    self show_jugg_prompt_core(self.current_jugger_trigger);
    if(isDefined(self.current_jugger_trigger))
    {
        self.current_jugger_trigger delete();
        self.current_jugger_trigger = undefined;
    }
}

show_jugg_prompt_core(trigger_var)
{
    was_aiming = self adsButtonPressed();
    while(self isTouching(trigger_var) && self hasPerk("specialty_armorvest") && !self.machine_is_in_use && !self.is_purchasing)
    {
        if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            is_aiming = self adsButtonPressed();
            if(is_aiming != was_aiming)
            {
                was_aiming = is_aiming;
                hint = self get_jugg_hint_string(is_aiming);
                trigger_var sethintstring(hint);
            }

            if(is_aiming)
            {
                if(self.can_buy_ethereal_razor && self useButtonPressed() && self.score >= self.ethereal_razor_price)
                {
                    if(distance(self.origin, self.original_jugger_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_jugger_trigger = undefined;
                        }
                        self thread process_ethereal_razor_purchase();
                        break;
                    }
                }
                else if(self.can_buy_dam_a_nade && self meleeButtonPressed() && self.score >= self.dam_a_nade_price)
                {
                    if(distance(self.origin, self.original_jugger_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_jugger_trigger = undefined;
                        }
                        self thread process_dam_a_nade_purchase();
                        break;
                    }
                }
                else if((self useButtonPressed() && self.can_buy_ethereal_razor && self.score < self.ethereal_razor_price)
                    || (self meleeButtonPressed() && self.can_buy_dam_a_nade && self.score < self.dam_a_nade_price))
                {
                    if(distance(self.origin, self.original_jugger_machine_location) <= 70)
                    {
                        self playsound("evt_perk_deny");
                        self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                        while(self useButtonPressed() || self meleeButtonPressed())
                            wait 0.05;
                    }
                }
            }
            else
            {
                if(self.can_buy_multi_jugger && self useButtonPressed() && self.score >= self.jugger_price)
                {
                    if(distance(self.origin, self.original_jugger_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_jugger_trigger = undefined;
                        }
                        self thread process_multi_juggernog_purchase();
                        break;
                    }
                }
                else if(!self.has_vulture && self.can_buy_vulture && self meleeButtonPressed() && self.score >= self.vulture_price)
                {
                    if(distance(self.origin, self.original_jugger_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_jugger_trigger = undefined;
                        }
                        self thread process_vulture_purchase();
                        break;
                    }
                }
                else if((self useButtonPressed() && self.can_buy_multi_jugger && self.score < self.jugger_price)
                    || (self meleeButtonPressed() && !self.has_vulture && self.can_buy_vulture && self.score < self.vulture_price))
                {
                    if(distance(self.origin, self.original_jugger_machine_location) <= 70)
                    {
                        self playsound("evt_perk_deny");
                        self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                        while(self useButtonPressed() || self meleeButtonPressed())
                            wait 0.05;
                    }
                }
            }
        }
        wait 0.1;
    }
}

get_speedcola_hint_string(is_aiming)
{
    hint = "";
    if(is_aiming)
    {
        if(self.can_buy_cashback && self.cashback_level < 2)
        {
            if(self.cashback_level == 0)
                hint = "Hold ^3[{+activate}]^7 for Cashback Cocktail [Cost: " + self.cashback_price + "]";
            else
                hint = "Hold ^3[{+activate}]^7 for Upgrade Cashback Cocktail [Cost: " + self.cashback_price + "]";
        }
        if(self.can_buy_repairman)
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Press ^3[{+melee}]^7 for Repairman Rum [Cost: " + self.repairman_price + "]";
        }
    }
    else
    {
        if(self.can_buy_pointcrusher)
            hint = "Hold ^3[{+activate}]^7 for Point Crusher [Cost: " + self.pointcrusher_price + "]";
        if(self.can_buy_speedcola)
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Press ^3[{+melee}]^7 for Multi-Speed Cola [Cost: " + self.speedcola_price + "]";
        }
        if(hint != "")
            hint += " ^1|^7 ";
        hint += "Aim ^3[{+speed_throw}]^7 for More";
    }
    return hint;
}

show_speedcola_pointcrusher_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_fastreload") || self.is_purchasing)
        return;
    if(!self.can_buy_pointcrusher && !self.can_buy_speedcola && (!self.can_buy_cashback || self.cashback_level >= 2) && !self.can_buy_repairman)
        return;
    if(isDefined(self.current_speedcola_trigger))
        return;

    hint = self get_speedcola_hint_string(self adsButtonPressed());
    if(hint != "")
        self.current_speedcola_trigger = self create_trigger_radius(hint, self.original_speedcola_machine_location + (0, 0, 30));
    if(!isDefined(self.current_speedcola_trigger))
        return;
    self show_speedcola_prompt_core(self.current_speedcola_trigger);
    if(isDefined(self.current_speedcola_trigger))
    {
        self.current_speedcola_trigger delete();
        self.current_speedcola_trigger = undefined;
    }
}

show_speedcola_prompt_core(trigger_var)
{
    was_aiming = self adsButtonPressed();
    while(self isTouching(trigger_var) && self hasPerk("specialty_fastreload") && !self.machine_is_in_use && !self.is_purchasing)
    {
        if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            is_aiming = self adsButtonPressed();
            if(is_aiming != was_aiming)
            {
                was_aiming = is_aiming;
                hint = self get_speedcola_hint_string(is_aiming);
                trigger_var sethintstring(hint);
            }

            if(is_aiming)
            {
                if(self.can_buy_cashback && self.cashback_level < 2 && self useButtonPressed() && self.score >= self.cashback_price)
                {
                    if(distance(self.origin, self.original_speedcola_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_speedcola_trigger = undefined;
                        }
                        self thread process_cashback_purchase();
                        break;
                    }
                }
                else if(self.can_buy_repairman && self meleeButtonPressed() && self.score >= self.repairman_price)
                {
                    if(distance(self.origin, self.original_speedcola_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_speedcola_trigger = undefined;
                        }
                        self thread process_repairman_purchase();
                        break;
                    }
                }
                else if((self useButtonPressed() && self.can_buy_cashback && self.cashback_level < 2 && self.score < self.cashback_price)
                    || (self meleeButtonPressed() && self.can_buy_repairman && self.score < self.repairman_price))
                {
                    if(distance(self.origin, self.original_speedcola_machine_location) <= 70)
                    {
                        self playsound("evt_perk_deny");
                        self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                        while(self useButtonPressed() || self meleeButtonPressed())
                            wait 0.05;
                    }
                }
            }
            else
            {
                if(self.can_buy_pointcrusher && self useButtonPressed() && self.score >= self.pointcrusher_price)
                {
                    if(distance(self.origin, self.original_speedcola_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_speedcola_trigger = undefined;
                        }
                        self thread process_speedcola_pointcrusher_purchase();
                        break;
                    }
                }
                else if(self.can_buy_speedcola && self meleeButtonPressed() && self.score >= self.speedcola_price)
                {
                    if(distance(self.origin, self.original_speedcola_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_speedcola_trigger = undefined;
                        }
                        self thread process_multi_speedcola_purchase();
                        break;
                    }
                }
                else if((self useButtonPressed() && self.can_buy_pointcrusher && self.score < self.pointcrusher_price)
                    || (self meleeButtonPressed() && self.can_buy_speedcola && self.score < self.speedcola_price))
                {
                    if(distance(self.origin, self.original_speedcola_machine_location) <= 70)
                    {
                        self playsound("evt_perk_deny");
                        self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                        while(self useButtonPressed() || self meleeButtonPressed())
                            wait 0.05;
                    }
                }
            }
        }
        wait 0.1;
    }
}

get_staminup_hint_string(is_aiming)
{
    hint = "";
    if(is_aiming)
    {
        if(self.can_buy_bandolier_bandit)
        {
            if(self.bandolier_bandit_level == 0)
                hint = "Hold ^3[{+activate}]^7 for Bandolier Bandit [Cost: " + self.bandolier_bandit_price + "]";
            else
                hint = "Hold ^3[{+activate}]^7 for Upgrade Bandolier Bandit [Cost: " + self.bandolier_bandit_price + "]";
        }
        if(!self.has_blood_bullets && self.can_buy_blood_bullets)
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Press ^3[{+melee}]^7 for Blood Bullets [Cost: " + self.blood_bullets_price + "]";
        }
    }
    else
    {
        if(!self.has_jetpack && self.can_buy_jetpack)
            hint = "Hold ^3[{+activate}]^7 for Exo Suit [Cost: " + self.jetpack_price + "]";
        if(self.can_buy_staminup)
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Press ^3[{+melee}]^7 for Multi-Stamin-Up [Cost: " + self.staminup_price + "]";
        }
        if(!self.has_nitrogen_cooled && self.can_buy_nitrogen_cooled)
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Press ^3[{+breath_sprint}]^7 for Nitrogen Cooled [Cost: " + self.nitrogen_cooled_price + "]";
        }
        if(self.can_buy_bandolier_bandit || (!self.has_blood_bullets && self.can_buy_blood_bullets))
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Aim ^3[{+speed_throw}]^7 for More";
        }
    }
    return hint;
}

show_staminup_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_longersprint") || self.is_purchasing)
        return;
    if((self.has_jetpack || !self.can_buy_jetpack) && !self.can_buy_staminup && !self.can_buy_bandolier_bandit && (self.has_blood_bullets || !self.can_buy_blood_bullets) && (self.has_nitrogen_cooled || !self.can_buy_nitrogen_cooled))
        return;
    if(isDefined(self.current_staminup_trigger))
        return;

    hint = self get_staminup_hint_string(self adsButtonPressed());
    if(hint != "")
        self.current_staminup_trigger = self create_trigger_radius(hint, self.original_staminup_machine_location + (0, 0, 30));
    if(!isDefined(self.current_staminup_trigger))
        return;
    self show_staminup_prompt_core(self.current_staminup_trigger);
    if(isDefined(self.current_staminup_trigger))
    {
        self.current_staminup_trigger delete();
        self.current_staminup_trigger = undefined;
    }
}

show_staminup_prompt_core(trigger_var)
{
    was_aiming = self adsButtonPressed();
    while(self isTouching(trigger_var) && self hasPerk("specialty_longersprint") && !self.machine_is_in_use && !self.is_purchasing)
    {
        if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            is_aiming = self adsButtonPressed();
            if(is_aiming != was_aiming)
            {
                was_aiming = is_aiming;
                hint = self get_staminup_hint_string(is_aiming);
                trigger_var sethintstring(hint);
            }

            if(is_aiming)
            {
                if(self.can_buy_bandolier_bandit && self useButtonPressed() && self.score >= self.bandolier_bandit_price)
                {
                    if(distance(self.origin, self.original_staminup_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_staminup_trigger = undefined;
                        }
                        self thread process_bandolier_bandit_purchase();
                        break;
                    }
                }
                else if(!self.has_blood_bullets && self.can_buy_blood_bullets && self meleeButtonPressed() && self.score >= self.blood_bullets_price)
                {
                    if(distance(self.origin, self.original_staminup_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_staminup_trigger = undefined;
                        }
                        self thread process_blood_bullets_purchase();
                        break;
                    }
                }
                else if((self useButtonPressed() && self.can_buy_bandolier_bandit && self.score < self.bandolier_bandit_price)
                    || (self meleeButtonPressed() && !self.has_blood_bullets && self.can_buy_blood_bullets && self.score < self.blood_bullets_price))
                {
                    if(distance(self.origin, self.original_staminup_machine_location) <= 70)
                    {
                        self playsound("evt_perk_deny");
                        self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                        while(self useButtonPressed() || self meleeButtonPressed())
                            wait 0.05;
                    }
                }
            }
            else
            {
                if(!self.has_jetpack && self.can_buy_jetpack && self useButtonPressed() && self.score >= self.jetpack_price)
                {
                    if(distance(self.origin, self.original_staminup_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_staminup_trigger = undefined;
                        }
                        self thread process_staminup_jetpack_purchase();
                        break;
                    }
                }
                else if(self.can_buy_staminup && self meleeButtonPressed() && self.score >= self.staminup_price)
                {
                    if(distance(self.origin, self.original_staminup_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_staminup_trigger = undefined;
                        }
                        self thread process_multi_staminup_purchase();
                        break;
                    }
                }
                else if(!self.has_nitrogen_cooled && self.can_buy_nitrogen_cooled && self sprintButtonPressed() && self.score >= self.nitrogen_cooled_price)
                {
                    if(distance(self.origin, self.original_staminup_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_staminup_trigger = undefined;
                        }
                        self thread process_nitrogen_cooled_purchase();
                        break;
                    }
                }
                else if((self useButtonPressed() && !self.has_jetpack && self.can_buy_jetpack && self.score < self.jetpack_price)
                    || (self meleeButtonPressed() && self.can_buy_staminup && self.score < self.staminup_price)
                    || (self sprintButtonPressed() && !self.has_nitrogen_cooled && self.can_buy_nitrogen_cooled && self.score < self.nitrogen_cooled_price))
                {
                    if(distance(self.origin, self.original_staminup_machine_location) <= 70)
                    {
                        self playsound("evt_perk_deny");
                        self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                        while(self useButtonPressed() || self meleeButtonPressed() || self sprintButtonPressed())
                            wait 0.05;
                    }
                }
            }
        }
        wait 0.1;
    }
}

get_quickrevive_hint_string(is_aiming)
{
    hint = "";
    whos_who_available = !self.has_whos_who && self.can_buy_whos_who && !isDefined(self.e_whos_who_corpse);
    if(is_aiming)
    {
        if(!self.has_fighters_fizz && self.can_buy_fighters_fizz)
            hint = "Hold ^3[{+activate}]^7 for Fighter's Fizz [Cost: " + self.fighters_fizz_price + "]";
    }
    else
    {
        if(!self.has_muscle_milk && self.can_buy_muscle_milk)
            hint = "Hold ^3[{+activate}]^7 for Muscle Milk [Cost: " + self.muscle_milk_price + "]";
        if(whos_who_available)
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Press ^3[{+melee}]^7 for Who's Who [Cost: " + self.whos_who_price + "]";
        }
        if(!self.has_fighters_fizz && self.can_buy_fighters_fizz)
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Aim ^3[{+speed_throw}]^7 for More";
        }
    }
    return hint;
}

show_muscle_milk_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_quickrevive") || self.is_purchasing)
        return;
    if((self.has_muscle_milk || !self.can_buy_muscle_milk) && (self.has_whos_who || !self.can_buy_whos_who) && (self.has_fighters_fizz || !self.can_buy_fighters_fizz))
        return;
    if(isDefined(self.current_quickrevive_trigger))
        return;

    hint = self get_quickrevive_hint_string(self adsButtonPressed());
    if(hint != "")
        self.current_quickrevive_trigger = self create_trigger_radius(hint, self.original_quickrevive_machine_location + (0, 0, 30));
    if(!isDefined(self.current_quickrevive_trigger))
        return;
    self show_quickrevive_prompt_core(self.current_quickrevive_trigger);
    if(isDefined(self.current_quickrevive_trigger))
    {
        self.current_quickrevive_trigger delete();
        self.current_quickrevive_trigger = undefined;
    }
}

show_quickrevive_prompt_core(trigger_var)
{
    was_aiming = self adsButtonPressed();
    while(self isTouching(trigger_var) && self hasPerk("specialty_quickrevive") && !self.machine_is_in_use && !self.is_purchasing)
    {
        if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            is_aiming = self adsButtonPressed();
            if(is_aiming != was_aiming)
            {
                was_aiming = is_aiming;
                hint = self get_quickrevive_hint_string(is_aiming);
                trigger_var sethintstring(hint);
            }

            if(is_aiming)
            {
                if(!self.has_fighters_fizz && self.can_buy_fighters_fizz && self useButtonPressed() && self.score >= self.fighters_fizz_price)
                {
                    if(distance(self.origin, self.original_quickrevive_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_quickrevive_trigger = undefined;
                        }
                        self thread process_fighters_fizz_purchase();
                        break;
                    }
                }
                else if(self useButtonPressed() && !self.has_fighters_fizz && self.can_buy_fighters_fizz && self.score < self.fighters_fizz_price)
                {
                    if(distance(self.origin, self.original_quickrevive_machine_location) <= 70)
                    {
                        self playsound("evt_perk_deny");
                        self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                        while(self useButtonPressed())
                            wait 0.05;
                    }
                }
            }
            else
            {
                if(!self.has_muscle_milk && self.can_buy_muscle_milk && self useButtonPressed() && self.score >= self.muscle_milk_price)
                {
                    if(distance(self.origin, self.original_quickrevive_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_quickrevive_trigger = undefined;
                        }
                        self thread process_muscle_milk_purchase();
                        break;
                    }
                }
                else if(!self.has_whos_who && !isDefined(self.e_whos_who_corpse) && self.can_buy_whos_who && self meleeButtonPressed() && self.score >= self.whos_who_price)
                {
                    if(distance(self.origin, self.original_quickrevive_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_quickrevive_trigger = undefined;
                        }
                        self thread process_whos_who_purchase();
                        break;
                    }
                }
                else if((self useButtonPressed() && !self.has_muscle_milk && self.can_buy_muscle_milk && self.score < self.muscle_milk_price)
                    || (self meleeButtonPressed() && !self.has_whos_who && self.can_buy_whos_who && self.score < self.whos_who_price))
                {
                    if(distance(self.origin, self.original_quickrevive_machine_location) <= 70)
                    {
                        self playsound("evt_perk_deny");
                        self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                        while(self useButtonPressed() || self meleeButtonPressed())
                            wait 0.05;
                    }
                }
            }
        }
        wait 0.1;
    }
}

get_doubletap_hint_string(is_aiming)
{
    hint = "";
    if(is_aiming)
    {
        if(self.can_buy_doubletap_1)
            hint = "Hold ^3[{+activate}]^7 for Multi-Double Tap 1.0 [Cost: " + self.doubletap_1_price + "]";
        if(!self.has_vigor_rush && self.can_buy_vigor_rush)
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Press ^3[{+melee}]^7 for Vigor Rush [Cost: " + self.vigor_rush_price + "]";
        }
    }
    else
    {
        if(self.can_buy_punchcola)
            hint = "Hold ^3[{+activate}]^7 for Punch-a-Cola [Cost: " + self.punchcola_price + "]";
        if(!self.has_winters_wail && self.can_buy_winters_wail)
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Press ^3[{+melee}]^7 for Winter's Wail [Cost: " + self.winters_wail_price + "]";
        }
        if(self.can_buy_doubletap_1 || (!self.has_vigor_rush && self.can_buy_vigor_rush))
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Aim ^3[{+speed_throw}]^7 for More";
        }
    }
    return hint;
}

show_punchcola_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_rof") || self.is_purchasing)
        return;
    if(!self.can_buy_punchcola && (self.has_winters_wail || !self.can_buy_winters_wail) && !self.can_buy_doubletap_1 && (self.has_vigor_rush || !self.can_buy_vigor_rush))
        return;
    if(isDefined(self.current_doubletap_trigger))
        return;

    hint = self get_doubletap_hint_string(self adsButtonPressed());
    if(hint != "")
        self.current_doubletap_trigger = self create_trigger_radius(hint, self.original_doubletap_machine_location + (0, 0, 30));
    if(!isDefined(self.current_doubletap_trigger))
        return;
    self show_doubletap_prompt_core(self.current_doubletap_trigger);
    if(isDefined(self.current_doubletap_trigger))
    {
        self.current_doubletap_trigger delete();
        self.current_doubletap_trigger = undefined;
    }
}

show_doubletap_prompt_core(trigger_var)
{
    was_aiming = self adsButtonPressed();
    while(self isTouching(trigger_var) && self hasPerk("specialty_rof") && !self.machine_is_in_use && !self.is_purchasing)
    {
        if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            is_aiming = self adsButtonPressed();
            if(is_aiming != was_aiming)
            {
                was_aiming = is_aiming;
                hint = self get_doubletap_hint_string(is_aiming);
                trigger_var sethintstring(hint);
            }

            if(is_aiming)
            {
                if(self.can_buy_doubletap_1 && self useButtonPressed() && self.score >= self.doubletap_1_price)
                {
                    if(distance(self.origin, self.original_doubletap_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_doubletap_trigger = undefined;
                        }
                        self thread process_doubletap_1_purchase();
                        break;
                    }
                }
                else if(!self.has_vigor_rush && self.can_buy_vigor_rush && self meleeButtonPressed() && self.score >= self.vigor_rush_price)
                {
                    if(distance(self.origin, self.original_doubletap_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_doubletap_trigger = undefined;
                        }
                        self thread process_vigor_rush_purchase();
                        break;
                    }
                }
                else if((self useButtonPressed() && self.can_buy_doubletap_1 && self.score < self.doubletap_1_price)
                    || (self meleeButtonPressed() && !self.has_vigor_rush && self.can_buy_vigor_rush && self.score < self.vigor_rush_price))
                {
                    if(distance(self.origin, self.original_doubletap_machine_location) <= 70)
                    {
                        self playsound("evt_perk_deny");
                        self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                        while(self useButtonPressed() || self meleeButtonPressed())
                            wait 0.05;
                    }
                }
            }
            else
            {
                if(self.can_buy_punchcola && self useButtonPressed() && self.score >= self.punchcola_price)
                {
                    if(distance(self.origin, self.original_doubletap_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_doubletap_trigger = undefined;
                        }
                        self thread process_punchcola_purchase();
                        break;
                    }
                }
                else if(!self.has_winters_wail && self.can_buy_winters_wail && self meleeButtonPressed() && self.score >= self.winters_wail_price)
                {
                    if(distance(self.origin, self.original_doubletap_machine_location) <= 70)
                    {
                        if(isDefined(trigger_var))
                        {
                            trigger_var delete();
                            self.current_doubletap_trigger = undefined;
                        }
                        self thread process_winters_wail_purchase();
                        break;
                    }
                }
                else if((self useButtonPressed() && self.can_buy_punchcola && self.score < self.punchcola_price)
                    || (self meleeButtonPressed() && !self.has_winters_wail && self.can_buy_winters_wail && self.score < self.winters_wail_price))
                {
                    if(distance(self.origin, self.original_doubletap_machine_location) <= 70)
                    {
                        self playsound("evt_perk_deny");
                        self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                        while(self useButtonPressed() || self meleeButtonPressed())
                            wait 0.05;
                    }
                }
            }
        }
        wait 0.1;
    }
}

show_doubletap_buy_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(self hasPerk("specialty_rof") || self.is_purchasing)
        return;
    
    if(isDefined(self.buy_doubletap_trigger))
        return;

    if(!isDefined(level.tomb_doubletap_origin)) return;

    self.buy_doubletap_trigger = spawn("trigger_radius", level.tomb_doubletap_origin, 1, 100, 128);
    self.buy_doubletap_trigger setcursorhint("HINT_NOICON");
    self.buy_doubletap_trigger sethintstring("Hold ^3[{+activate}]^7 for Double Tap [Cost: 2000]");
    self.buy_doubletap_trigger setinvisibletoall();
    self.buy_doubletap_trigger setvisibletoplayer(self);
        
    self show_buy_prompt_core(self.buy_doubletap_trigger, "specialty_rof", 2000, level.tomb_doubletap_origin, ::process_doubletap_buy);
    
    if(isDefined(self.buy_doubletap_trigger))
    {
        self.buy_doubletap_trigger delete();
        self.buy_doubletap_trigger = undefined;
    }
}

show_staminup_buy_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(self hasPerk("specialty_longersprint") || self.is_purchasing)
        return;
    
    if(isDefined(self.buy_staminup_trigger))
        return;

    if(!isDefined(level.prison_staminup_origin)) return;

    self.buy_staminup_trigger = spawn("trigger_radius", level.prison_staminup_origin, 1, 100, 128);
    self.buy_staminup_trigger setcursorhint("HINT_NOICON");
    self.buy_staminup_trigger sethintstring("Hold ^3[{+activate}]^7 for Stamin-Up [Cost: 2000]");
    self.buy_staminup_trigger setinvisibletoall();
    self.buy_staminup_trigger setvisibletoplayer(self);
        
    self show_buy_prompt_core(self.buy_staminup_trigger, "specialty_longersprint", 2000, level.prison_staminup_origin, ::process_staminup_buy);
    
    if(isDefined(self.buy_staminup_trigger))
    {
        self.buy_staminup_trigger delete();
        self.buy_staminup_trigger = undefined;
    }
}

process_doubletap_buy()
{
    self process_perk_purchase("specialty_rof", 2000, level.tomb_doubletap_origin, "zombie_perk_bottle_doubletap", undefined, true);
    self maps\mp\zombies\_zm_perks::give_perk( "specialty_rof" );
    self.last_doubletap_purchase_time = GetTime();
    self notify("perk_acquired");
}

process_staminup_buy()
{
    self process_perk_purchase("specialty_longersprint", 2000, level.prison_staminup_origin, level.staminup_bottle, undefined, true);
    self maps\mp\zombies\_zm_perks::give_perk( "specialty_longersprint" );
    self.last_staminup_purchase_time = GetTime();
    self notify("perk_acquired");
    self iprintln("^2Stamin-Up Acquired!\n^1If you do not see the icon, it's because Mob of the Dead does not have one for it.");
}

process_perk_purchase(perk_name, price, machine_location, bottle_name, additional_condition, allow_new_purchase)
{
    if(self.is_purchasing)
        return;

    if(!isDefined(allow_new_purchase))
        allow_new_purchase = false;

    if(!allow_new_purchase && !(self hasPerk(perk_name)))
        return;
    
    if(isDefined(additional_condition) && additional_condition)
        return;
    
    if(!isDefined(machine_location) || distance(self.origin, machine_location) > 70)
        return;
    
    self.is_purchasing = true;
    self.machine_is_in_use = true;
    self playsound("zmb_cha_ching");
    self.score -= price;
    level notify("spent_points", self, price);
    
    self allowProne(false);
    self allowSprint(false);
    self disableOffhandWeapons();
    self disableWeaponCycling();
    
    weapona = self getCurrentWeapon();
    self giveWeapon(bottle_name);
    self switchToWeapon(bottle_name);
    self waittill("weapon_change_complete");
    
    self enableOffhandWeapons();
    self enableWeaponCycling();
    self takeWeapon(bottle_name);
    self switchToWeapon(weapona);
    
    self maps\mp\zombies\_zm_audio::playerexert("burp");
    self setBlur(4, 0.1);
    wait 0.1;
    self setBlur(0, 0.1);
    self allowProne(true);
    self allowSprint(true);
    
    wait 0.5;
    self.machine_is_in_use = false;
    self.is_purchasing = false;
}

process_multi_mule_kick_purchase()
{
    self process_perk_purchase("specialty_additionalprimaryweapon", self.mule_kick_price, self.original_mule_kick_machine_location, "zombie_perk_bottle_additionalprimaryweapon");
    self.weapon_limit_counter++;
    self.multi_mule_kick_counter++;
    self.mule_kick_price = self.starting_mule_kick_price * self.multi_mule_kick_counter;
    self.last_mule_kick_purchase_time = GetTime();
    self iprintln("^1Mule Kick Level " + self.multi_mule_kick_counter + "\n^2Weapon Limit increased to " + self.weapon_limit_counter);
}

process_multi_juggernog_purchase()
{
    self process_perk_purchase("specialty_armorvest", self.jugger_price, self.original_jugger_machine_location, "zombie_perk_bottle_jugg");
    self.maxhealth += 150;
    self.health = self.maxhealth;
    self.multi_juggernog_counter++;
    self.jugger_price = self.starting_jugger_price * self.multi_juggernog_counter;
    self.last_jugger_purchase_time = GetTime();
    self.hits_counter = int(self.maxhealth / 50);
    self iprintln("^1Juggernog Level " + self.multi_juggernog_counter + "\n^2Health increased to " + self.maxhealth + "\n^8Now you resist " + self.hits_counter + " Hits!");
}

process_vulture_purchase()
{
    self process_perk_purchase("specialty_armorvest", self.vulture_price, self.original_jugger_machine_location, "zombie_perk_bottle_jugg", self.has_vulture);
    self.has_vulture = true;
    self.last_jugger_purchase_time = GetTime();
    self thread monitor_vulture_stink();
    self iprintln("^2Vulture Aid Acquired!\n^3Killed zombies can drop ammo, points or a stink cloud.\n^1Stand inside the green stink and zombies will ignore you!");
}

// Vulture Aid drop: runs on the zombie that died
vulture_zombie_death()
{
    if(isDefined(self.attacker) && isPlayer(self.attacker))
    {
        self.attacker notify("zombie_killed_by_player", self);
        if(self.attacker.has_vulture)
        {
            if(randomint(100) < 30)
                self.attacker thread vulture_drop(self.origin);
        }
    }
}

vulture_drop(v_origin)
{
    self endon("disconnect");
    self endon("death");

    drop = spawn("script_model", v_origin + (0, 0, 15));
    drop setmodel("tag_origin");

    roll = randomint(100);

    // green stink cloud: hides every Vulture owner standing inside it 
    if(roll >= 90)
    {
        drop.stink_active = true;
        level.vulture_stink_clouds[level.vulture_stink_clouds.size] = drop;

        // soft green mist pulses that remain clear to see through inside
        for(i = 0; i < 30; i++)
        {
            playfxontag(level._effect["poltergeist"], drop, "tag_origin");
            wait 0.75;
        }

        drop.stink_active = false;
        arrayremovevalue(level.vulture_stink_clouds, drop, 0);
        drop delete();
        return;
    }

    drop.is_ammo = roll < 40;
    playfxontag(level._effect["powerup_on"], drop, "tag_origin");

    // the drop only lasts a few seconds, only for the player who earned it
    for(i = 0; i < 80; i++)
    {
        if(distanceSquared(self.origin, drop.origin) < 2304) // ~48 units pickup radius
        {
            playfx(level._effect["powerup_grabbed"], drop.origin);
            if(drop.is_ammo)
            {
                if(getDvar("mapname") == "zm_buried")
                {
                    self playsoundtoplayer("zmb_vulture_drop_pickup_ammo", self);
                }
                else
                {
                    self playsound("zmb_weap_wall");
                }

                self vulture_give_ammo();
            }
            else
            {
                if(getDvar("mapname") == "zm_buried")
                {
                    self playsoundtoplayer("zmb_vulture_drop_pickup_money", self);
                }
                else
                {
                    self playsound("zmb_cha_ching");
                }

                points = randomintrange(1, 6) * 10;
                pc_mult = 1;
                if(isDefined(self.point_multiplier) && self.point_multiplier > 1)
                    pc_mult = self.point_multiplier;
                else if(isDefined(self.multi_pointcrusher_counter) && self.multi_pointcrusher_counter > 0)
                    pc_mult = self.multi_pointcrusher_counter + 1;

                points = points * pc_mult;
                self maps\mp\zombies\_zm_score::add_to_player_score(points);
                self.pers["score"] = self.score;
            }
            break;
        }
        wait 0.15;
    }

    drop delete();
}

bandolier_skip_weapon(weap)
{
    if(!isDefined(weap) || weap == "none")
        return true;
    if(isdefined(level.zombie_include_equipment) && isdefined(level.zombie_include_equipment[weap]))
        return true;
    if(isdefined(level.zombie_weapons_no_max_ammo) && isdefined(level.zombie_weapons_no_max_ammo[weap]))
        return true;
    if(is_offhand_weapon(weap) || is_placeable_mine(weap) || is_equipment(weap) || maps\mp\zombies\_zm_utility::is_zombie_perk_bottle(weap))
        return true;
    return false;
}

bandolier_get_vanilla_stock(weap)
{
    if(!isDefined(weap) || weap == "none")
        return 0;

    if(!isDefined(level.weapon_true_max_stock))
        level.weapon_true_max_stock = [];

    if(isDefined(level.weapon_true_max_stock[weap]) && level.weapon_true_max_stock[weap] > 0)
        return level.weapon_true_max_stock[weap];

    // Explicit baseline for starting pistols and Ray Gun Mark 2 in Zombies
    if(weap == "m1911_zm")
    {
        level.weapon_true_max_stock[weap] = 80;
        return 80;
    }
    if(weap == "m1911_upgraded_zm")
    {
        level.weapon_true_max_stock[weap] = 50;
        return 50;
    }
    if(weap == "raygun_mark2_upgraded_zm")
    {
        level.weapon_true_max_stock[weap] = 201;
        return 201;
    }
    if(weap == "raygun_mark2_zm")
    {
        level.weapon_true_max_stock[weap] = 168;
        return 168;
    }

    // Reserve = weaponmaxammo - weaponclipsize
    max_tot = weaponmaxammo(weap);
    clip_sz = weaponclipsize(weap);

    val = 0;
    if(isDefined(max_tot) && max_tot > 0 && isDefined(clip_sz) && clip_sz > 0 && max_tot > clip_sz)
    {
        val = max_tot - clip_sz;
    }
    else if(isDefined(max_tot) && max_tot > 0)
    {
        val = max_tot;
    }
    else
    {
        val = weaponstartammo(weap);
    }

    if(!isDefined(val) || val <= 0)
        val = self getweaponammostock(weap);

    if(isDefined(val) && val > 0)
        level.weapon_true_max_stock[weap] = val;

    return val;
}

bandolier_get_stash_max(weap)
{
    vanilla_max = self bandolier_get_vanilla_stock(weap);
    if(!isDefined(vanilla_max) || vanilla_max <= 0)
        return 0;

    bonus = int(vanilla_max * (0.20 * self.bandolier_bandit_level));
    if(bonus < 1)
        bonus = self.bandolier_bandit_level;
    return bonus;
}

bandolier_hud_create()
{
    self notify("bandolier_hud_recreated");

    if(isDefined(self.bandolier_hud))
    {
        self.bandolier_hud destroy();
        self.bandolier_hud = undefined;
    }

    hud = newclienthudelem(self);
    hud.alignx = "right";
    hud.aligny = "bottom";
    hud.horzalign = "user_right";
    hud.vertalign = "user_bottom";
    hud.x = -25;
    hud.y = -62;
    hud.font = "default";
    hud.fontscale = 1.3;
    hud.color = (1, 0.85, 0.2);
    hud.alpha = 0;
    hud.foreground = true;
    hud.hidewhendead = true;
    hud.hidewheninmenu = true;

    self.bandolier_hud = hud;
    self thread bandolier_hud_cleanup_watcher();
    return hud;
}

bandolier_hud_cleanup_watcher()
{
    self endon("bandolier_hud_recreated");
    self waittill_either("death", "disconnect");
    if(isDefined(self.bandolier_hud))
    {
        self.bandolier_hud destroy();
        self.bandolier_hud = undefined;
    }
}

bandolier_hud_update(cur_active_weap)
{
    if(!isDefined(self.bandolier_hud))
        return;

    if(!is_true(self.has_bandolier_bandit) || !isAlive(self) || self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        self.bandolier_hud.alpha = 0;
        return;
    }

    if(!isDefined(cur_active_weap) || self bandolier_skip_weapon(cur_active_weap))
    {
        self.bandolier_hud.alpha = 0;
        return;
    }

    stash = 0;
    if(isDefined(self.bandolier_stash) && isDefined(self.bandolier_stash[cur_active_weap]))
        stash = self.bandolier_stash[cur_active_weap];

    if(stash > 0)
    {
        self.bandolier_hud.alpha = 1;
        self.bandolier_hud settext("^3[+" + stash + "]");
    }
    else
    {
        self.bandolier_hud.alpha = 0;
    }
}

vulture_give_ammo()
{
    weapon = self getCurrentWeapon();
    if(weapon == "none" || is_offhand_weapon(weapon) || is_placeable_mine(weapon) || is_equipment(weapon))
    {
        primaries = self getWeaponsListPrimaries();
        if(isDefined(primaries) && primaries.size > 0)
            weapon = primaries[0];
        else
            return;
    }

    base_max = self bandolier_get_vanilla_stock(weapon);
    if(base_max <= 0)
        return;

    stash_max = 0;
    if(is_true(self.has_bandolier_bandit))
        stash_max = self bandolier_get_stash_max(weapon);

    current = self getweaponammostock(weapon);
    current_stash = 0;
    if(isDefined(self.bandolier_stash) && isDefined(self.bandolier_stash[weapon]))
        current_stash = self.bandolier_stash[weapon];

    if(current >= base_max && current_stash >= stash_max)
    {
        primaries = self getWeaponsListPrimaries();
        found = false;
        if(isDefined(primaries))
        {
            foreach(p_weap in primaries)
            {
                if(p_weap != weapon && !is_offhand_weapon(p_weap) && !is_placeable_mine(p_weap) && !is_equipment(p_weap))
                {
                    p_base = self bandolier_get_vanilla_stock(p_weap);
                    p_cur = self getweaponammostock(p_weap);
                    p_stash_max = 0;
                    if(is_true(self.has_bandolier_bandit))
                        p_stash_max = self bandolier_get_stash_max(p_weap);
                    p_stash = 0;
                    if(isDefined(self.bandolier_stash) && isDefined(self.bandolier_stash[p_weap]))
                        p_stash = self.bandolier_stash[p_weap];

                    if((p_base > 0 && p_cur < p_base) || (p_stash < p_stash_max))
                    {
                        weapon = p_weap;
                        base_max = p_base;
                        current = p_cur;
                        stash_max = p_stash_max;
                        current_stash = p_stash;
                        found = true;
                        break;
                    }
                }
            }
        }
        if(!found)
            return;
    }

    bonus = int(base_max * 0.1);
    if(bonus < 1)
        bonus = 1;

    if(current < base_max)
    {
        new_stock = min(base_max, current + bonus);
        self setweaponammostock(weapon, new_stock);
        overflow = (current + bonus) - base_max;
        if(overflow > 0 && stash_max > 0)
        {
            if(!isDefined(self.bandolier_stash))
                self.bandolier_stash = [];
            self.bandolier_stash[weapon] = min(stash_max, current_stash + overflow);
        }
    }
    else if(stash_max > 0 && current_stash < stash_max)
    {
        if(!isDefined(self.bandolier_stash))
            self.bandolier_stash = [];
        self.bandolier_stash[weapon] = min(stash_max, current_stash + bonus);
    }
}

player_should_be_ignored()
{
    if(isDefined(self.zombie_vars) && isDefined(self.zombie_vars["zombie_powerup_zombie_blood_on"]) && self.zombie_vars["zombie_powerup_zombie_blood_on"])
        return true;
    if(isDefined(self.afterlife) && self.afterlife)
        return true;
    if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        return true;
    if(is_true(self.is_zombie))
        return true;
    return false;
}

// while a Vulture owner stands inside a stink cloud zombies ignore them;
// all zombies targeting this player lose acquisition and are diverted away
monitor_vulture_stink()
{
    self endon("disconnect");
    self endon("death");

    was_inside = false;

    while(self.has_vulture)
    {
        inside = false;
        foreach(cloud in level.vulture_stink_clouds)
        {
            if(isDefined(cloud.stink_active) && cloud.stink_active && distance2d(self.origin, cloud.origin) < 115)
            {
                inside = true;
                break;
            }
        }

        if(inside)
        {
            self.ignoreme = 1;
            zombies = getAiArray(level.zombie_team);
            foreach(z in zombies)
            {
                if(isDefined(z.favoriteenemy) && z.favoriteenemy == self)
                {
                    // clear target from zombie
                    z.favoriteenemy = undefined;
                    z notify("stop_find_flesh");
                    z notify("zombie_acquire_enemy");

                    // divert zombie toward dog location or random wander point
                    target_loc = undefined;
                    if(isDefined(level.enemy_dog_locations) && level.enemy_dog_locations.size > 0)
                    {
                        rand_idx = randomint(level.enemy_dog_locations.size);
                        target_loc = level.enemy_dog_locations[rand_idx].origin;
                    }
                    else
                    {
                        target_loc = z.origin + (randomfloatrange(-300, 300), randomfloatrange(-300, 300), 0);
                    }

                    z setgoalpos(target_loc);
                    z.stopped_by_stink = true;
                }
            }
        }
        else if(was_inside)
        {
            if(!self player_should_be_ignored())
                self.ignoreme = 0;
            zombies = getAiArray(level.zombie_team);
            foreach(z in zombies)
            {
                if(isDefined(z.stopped_by_stink))
                {
                    z.stopped_by_stink = undefined;
                    z notify("stop_find_flesh");
                    z notify("zombie_acquire_enemy");
                    z thread maps\mp\zombies\_zm_ai_basic::find_flesh();
                }
            }
        }

        was_inside = inside;
        wait 0.2;
    }

    if(!self player_should_be_ignored())
        self.ignoreme = 0;
}

process_speedcola_pointcrusher_purchase()
{
    self process_perk_purchase("specialty_fastreload", self.pointcrusher_price, self.original_speedcola_machine_location, "zombie_perk_bottle_sleight");
    self.multi_pointcrusher_counter++;
    self.point_multiplier = self.multi_pointcrusher_counter + 1;
    self.pointcrusher_price = self.starting_pointcrusher_price * self.point_multiplier;
    self.last_speedcola_purchase_time = GetTime();
    self iprintln("^1Point Crusher Level " + self.multi_pointcrusher_counter + "\n^2Points Multiplier increased to x" + self.point_multiplier);
}

process_multi_speedcola_purchase()
{
    self process_perk_purchase("specialty_fastreload", self.speedcola_price, self.original_speedcola_machine_location, "zombie_perk_bottle_sleight");
    self.multi_speedcola_counter++;
    self.speedcola_price = self.starting_speedcola_price * (self.multi_speedcola_counter + 1);
    self.last_speedcola_purchase_time = GetTime();

    base_mult = 0.5;
    if(isDefined(level.default_weap_reload_mult) && level.default_weap_reload_mult > 0.0)
        base_mult = level.default_weap_reload_mult;

    mult = base_mult / (1.0 + (0.20 * self.multi_speedcola_counter));
    if(mult < 0.05)
        mult = 0.05;

    self setclientdvar("perk_weapReloadMultiplier", "" + mult);
    setdvar("perk_weapReloadMultiplier", mult);

    self iprintln("^2Speed Cola Level " + self.multi_speedcola_counter + "\n^2Reload Speed increased by +20 percent\n^3Total Reload Speed: +" + (self.multi_speedcola_counter * 20) + " percent faster!");
}

process_cashback_purchase()
{
    price = self.cashback_price;
    self process_perk_purchase("specialty_fastreload", price, self.original_speedcola_machine_location, "zombie_perk_bottle_sleight");
    self.has_cashback = true;
    self.cashback_level++;
    self.last_speedcola_purchase_time = GetTime();
    if(self.cashback_level == 1)
    {
        self.cashback_price = 2000;
        self iprintln("^2Cashback Cocktail Acquired!\n^320 percent cash back on all purchases!\n^1Upgrade available for 2000 (+10 percent more)");
    }
    else
    {
        self.can_buy_cashback = false;
        self iprintln("^2Cashback Cocktail Upgraded!\n^3Total 30 percent cash back on all purchases (Max Level)!");
    }
}

process_repairman_purchase()
{
    price = self.repairman_price;
    self process_perk_purchase("specialty_fastreload", price, self.original_speedcola_machine_location, "zombie_perk_bottle_sleight");
    self.has_repairman = true;
    self.repairman_level++;
    self.repairman_price = 2000 * (self.repairman_level + 1);
    self.last_speedcola_purchase_time = GetTime();
    self iprintln("^2Repairman Rum Level " + self.repairman_level + "!\n^3Repairs window barriers super fast!\n^1Barrier repair points: x" + (4 * self.repairman_level) + "!");
}

process_ethereal_razor_purchase()
{
    price = self.ethereal_razor_price;
    self process_perk_purchase("specialty_armorvest", price, self.original_jugger_machine_location, "zombie_perk_bottle_jugg");
    self.has_ethereal_razor = true;
    self.ethereal_razor_level++;
    self.ethereal_razor_price = 3000 * (self.ethereal_razor_level + 1);
    self.last_jugger_purchase_time = GetTime();
    self iprintln("^2Ethereal Razor Level " + self.ethereal_razor_level + "!\n^3Melee damage: x" + (5 * self.ethereal_razor_level) + "!\n^1Melee cleaves nearby zombies and heals you!");
}

process_dam_a_nade_purchase()
{
    price = self.dam_a_nade_price;
    self process_perk_purchase("specialty_armorvest", price, self.original_jugger_machine_location, "zombie_perk_bottle_jugg");
    self.has_dam_a_nade = true;
    self.dam_a_nade_level++;
    self.dam_a_nade_price = 2500 * (self.dam_a_nade_level + 1);
    self.last_jugger_purchase_time = GetTime();
    
    lethal = self maps\mp\zombies\_zm_utility::get_player_lethal_grenade();
    if(isDefined(lethal) && lethal != "" && self hasweapon(lethal))
    {
        cur = self getweaponammoclip(lethal);
        self setweaponammoclip(lethal, cur + 1);
    }
    tactical = self maps\mp\zombies\_zm_utility::get_player_tactical_grenade();
    if(isDefined(tactical) && tactical != "" && self hasweapon(tactical))
    {
        cur = self getweaponammoclip(tactical);
        self setweaponammoclip(tactical, cur + 1);
    }

    self iprintln("^2Dam-A-Nade Level " + self.dam_a_nade_level + "!\n^3Grenade Damage: x" + (10 * self.dam_a_nade_level) + " | Explosive Damage: x" + (2 * self.dam_a_nade_level) + "\n^1Carrying +1 lethal & +1 tactical! Grenades regen at round end!");
}

process_fighters_fizz_purchase()
{
    self process_perk_purchase("specialty_quickrevive", self.fighters_fizz_price, self.original_quickrevive_machine_location, "zombie_perk_bottle_revive", self.has_fighters_fizz);
    self.has_fighters_fizz = true;
    self.can_buy_fighters_fizz = false;
    self.last_quickrevive_purchase_time = GetTime();
    self iprintln("^2Fighter's Fizz Acquired!\n^3Keep your weapons when downed!\n^1Kill a zombie while downed to self-revive and keep all perks!");
}

process_staminup_jetpack_purchase()
{
    self process_perk_purchase("specialty_longersprint", self.jetpack_price, self.original_staminup_machine_location, level.staminup_bottle, self.has_jetpack);
    self.has_jetpack = true;
    self.last_staminup_purchase_time = GetTime();
    self iprintln("^2Exo Suit Acquired!\n^3Sprint + Change Stance to Exo Slide!\n^1Double Jump + Crouch to Ground Slam!\n^6Hold Aim [{+speed_throw}] in air to Hover!");
    self thread init_jetpack();
}

process_multi_staminup_purchase()
{
    self process_perk_purchase("specialty_longersprint", self.staminup_price, self.original_staminup_machine_location, level.staminup_bottle);
    self.multi_staminup_counter++;
    self.staminup_price = self.starting_staminup_price * (self.multi_staminup_counter + 1);
    self.last_staminup_purchase_time = GetTime();

    scale = 1.0 + (0.10 * self.multi_staminup_counter);
    self setmovespeedscale(scale);

    self iprintln("^3Multi-Stamin-Up Level " + self.multi_staminup_counter + "\n^2Speed increased by +10 percent\n^3Total Speed: +" + (self.multi_staminup_counter * 10) + " percent faster!");
}

process_bandolier_bandit_purchase()
{
    self process_perk_purchase("specialty_longersprint", self.bandolier_bandit_price, self.original_staminup_machine_location, level.staminup_bottle);
    self.has_bandolier_bandit = true;
    self.bandolier_bandit_level++;
    self.bandolier_bandit_price = 3000 * (self.bandolier_bandit_level + 1);
    self.last_staminup_purchase_time = GetTime();

    if(!isDefined(self.bandolier_stash))
        self.bandolier_stash = [];
    if(!isDefined(self.bandolier_prev_stock))
        self.bandolier_prev_stock = [];

    weapons = self getweaponslist(1);
    if(isDefined(weapons))
    {
        foreach(w in weapons)
        {
            if(self bandolier_skip_weapon(w))
                continue;

            stash_max = self bandolier_get_stash_max(w);
            self.bandolier_stash[w] = stash_max;
            self.bandolier_prev_stock[w] = self getweaponammostock(w);
        }
    }

    self iprintln("^3Bandolier Bandit Level " + self.bandolier_bandit_level + "!\n^2Max reserve ammo increased by +20 percent\n^3Total Reserve Ammo: +" + (self.bandolier_bandit_level * 20) + " percent!");
    self thread bandolier_bandit_think();
}

process_blood_bullets_purchase()
{
    self process_perk_purchase("specialty_longersprint", self.blood_bullets_price, self.original_staminup_machine_location, level.staminup_bottle, self.has_blood_bullets);
    self.has_blood_bullets = true;
    self.can_buy_blood_bullets = false;
    self.last_staminup_purchase_time = GetTime();

    self iprintln("^2Blood Bullets Acquired!\n^3Ammo in active gun slowly regenerates into clip.\n^1Clip size determines frequency!");
    self thread blood_bullets_think();
}

process_nitrogen_cooled_purchase()
{
    self process_perk_purchase("specialty_longersprint", self.nitrogen_cooled_price, self.original_staminup_machine_location, level.staminup_bottle, self.has_nitrogen_cooled);
    self.has_nitrogen_cooled = true;
    self.can_buy_nitrogen_cooled = false;
    self.last_staminup_purchase_time = GetTime();

    self iprintln("^2Nitrogen Cooled Acquired!\n^3Nearby zombies will slow to a walking pace!");
    self thread nitrogen_cooled_think();
}

bandolier_bandit_think()
{
    self endon("disconnect");
    self endon("death");
    self notify("bandolier_bandit_think_singleton");
    self endon("bandolier_bandit_think_singleton");

    self thread bandolier_bandit_max_ammo_watcher();

    if(!isDefined(self.bandolier_stash))
        self.bandolier_stash = [];
    if(!isDefined(self.bandolier_prev_stock))
        self.bandolier_prev_stock = [];

    self bandolier_hud_create();

    while(is_true(self.has_bandolier_bandit))
    {
        wait 0.1;
        if(!is_true(self.has_bandolier_bandit))
            break;

        if(isDefined(self.bandolier_bandit_level) && self.bandolier_bandit_level > 0 && isAlive(self) && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            weapons = self getweaponslist(1);
            cur_active_weap = self getCurrentWeapon();

            // Purge tracking for weapons no longer in inventory
            cached_keys = getarraykeys(self.bandolier_prev_stock);
            if(isDefined(cached_keys))
            {
                foreach(saved_w in cached_keys)
                {
                    if(!self hasWeapon(saved_w))
                    {
                        self.bandolier_prev_stock[saved_w] = undefined;
                        self.bandolier_stash[saved_w] = undefined;
                    }
                }
            }

            if(isDefined(weapons))
            {
                foreach(w in weapons)
                {
                    if(self bandolier_skip_weapon(w))
                        continue;

                    stash_max = self bandolier_get_stash_max(w);
                    if(stash_max <= 0)
                        continue;

                    if(!isDefined(self.bandolier_stash[w]))
                        self.bandolier_stash[w] = stash_max;

                    cur_stock = self getweaponammostock(w);
                    prev_stock = self.bandolier_prev_stock[w];

                    if(!isDefined(prev_stock))
                    {
                        self.bandolier_stash[w] = stash_max;
                        self.bandolier_prev_stock[w] = cur_stock;
                    }
                    else if(cur_stock > prev_stock && (self GetFractionMaxAmmo(w) >= 0.999 || cur_stock >= self bandolier_get_vanilla_stock(w)))
                    {
                        self.bandolier_stash[w] = stash_max;
                    }

                    if(self.bandolier_stash[w] > 0 && self GetFractionMaxAmmo(w) < 1.0)
                    {
                        stock_before = self GetWeaponAmmoStock(w);
                        amount = self.bandolier_stash[w];
                        self SetWeaponAmmoStock(w, stock_before + amount);
                        stock_after = self GetWeaponAmmoStock(w);
                        added = stock_after - stock_before;

                        if(added > 0)
                        {
                            self.bandolier_stash[w] -= added;
                            if(self.bandolier_stash[w] < 0)
                                self.bandolier_stash[w] = 0;
                            cur_stock = stock_after;
                        }
                    }

                    self.bandolier_prev_stock[w] = cur_stock;
                }
            }

            self bandolier_hud_update(cur_active_weap);
        }
        else
        {
            if(isDefined(self.bandolier_hud))
                self.bandolier_hud.alpha = 0;
        }
    }

    if(isDefined(self.bandolier_hud))
    {
        self.bandolier_hud destroy();
        self.bandolier_hud = undefined;
    }
}

bandolier_bandit_max_ammo_watcher()
{
    self endon("disconnect");
    self endon("death");
    self notify("bandolier_bandit_watcher_singleton");
    self endon("bandolier_bandit_watcher_singleton");

    while(is_true(self.has_bandolier_bandit))
    {
        self waittill("zmb_max_ammo");
        wait 0.05;
        if(is_true(self.has_bandolier_bandit) && isDefined(self.bandolier_bandit_level) && self.bandolier_bandit_level > 0)
        {
            weapons = self getweaponslist(1);
            if(isDefined(weapons))
            {
                foreach(w in weapons)
                {
                    if(self bandolier_skip_weapon(w))
                        continue;

                    stock_refilled = self getweaponammostock(w);
                    if(stock_refilled > 0)
                    {
                        if(!isDefined(level.weapon_true_max_stock[w]) || stock_refilled > level.weapon_true_max_stock[w])
                            level.weapon_true_max_stock[w] = stock_refilled;
                    }

                    stash_max = self bandolier_get_stash_max(w);
                    self.bandolier_stash[w] = stash_max;

                    self.bandolier_prev_stock[w] = stock_refilled;
                }
            }
            cur_active_weap = self getCurrentWeapon();
            self bandolier_hud_update(cur_active_weap);
        }
    }
}

blood_bullets_think()
{
    self endon("disconnect");
    self endon("death");

    while(is_true(self.has_blood_bullets))
    {
        if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand() && !is_true(self.is_purchasing) && !is_true(self.afterlife) && !isDefined(self.e_whos_who_corpse))
        {
            w = self getcurrentweapon();
            if(isDefined(w) && w != "none" && !maps\mp\zombies\_zm_utility::is_zombie_perk_bottle(w))
            {
                clip_size = weaponclipsize(w);
                if(clip_size > 0)
                {
                    cur_clip = self getweaponammoclip(w);
                    if(cur_clip < clip_size)
                    {
                        delay = clamp(25.0 / clip_size, 0.4, 2.0);
                        wait delay;
                        if(self getcurrentweapon() == w && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
                        {
                            now_clip = self getweaponammoclip(w);
                            if(now_clip < clip_size)
                            {
                                self setweaponammoclip(w, now_clip + 1);
                            }
                        }
                        continue;
                    }
                }
            }
        }
        wait 0.5;
    }
}

nitrogen_cooled_think()
{
    self endon("disconnect");
    self endon("death");

    while(is_true(self.has_nitrogen_cooled))
    {
        if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand() && !is_true(self.afterlife))
        {
            zombies = get_round_enemy_array();
            cur_time = getTime();

            foreach(z in zombies)
            {
                if(isDefined(z) && isAlive(z) && !is_true(z.is_frozen))
                {
                    dist = distance(z.origin, self.origin);
                    if(dist <= 200)
                    {
                        if(!is_true(z.nitrogen_slowed))
                        {
                            z.nitrogen_slowed = true;
                            z.nitrogen_orig_speed = isDefined(z.zombie_move_speed) ? z.zombie_move_speed : "run";
                            if(z.nitrogen_orig_speed != "walk")
                            {
                                z set_zombie_run_cycle("walk");
                                z.zombie_move_speed = "walk";
                            }
                        }
                        z.nitrogen_last_contact = cur_time;
                    }
                    else if(is_true(z.nitrogen_slowed) && isDefined(z.nitrogen_last_contact))
                    {
                        if(cur_time - z.nitrogen_last_contact >= 600)
                        {
                            if(isDefined(z.nitrogen_orig_speed))
                            {
                                z set_zombie_run_cycle(z.nitrogen_orig_speed);
                                z.zombie_move_speed = z.nitrogen_orig_speed;
                                z.nitrogen_orig_speed = undefined;
                            }
                            z.nitrogen_slowed = undefined;
                            z.nitrogen_last_contact = undefined;
                        }
                    }
                }
            }
        }
        wait 0.25;
    }
}

process_muscle_milk_purchase()
{
    self process_perk_purchase("specialty_quickrevive", self.muscle_milk_price, self.original_quickrevive_machine_location, "zombie_perk_bottle_revive", self.has_muscle_milk);
    self.has_muscle_milk = true;
    self.last_quickrevive_purchase_time = GetTime();
    self iprintln("^2Muscle Milk Acquired!\n^3Now you can electrocute when you use your melee weapon.\n^1Cooldown: 15 seconds");
    self thread monitor_muscle_milk();
}

process_whos_who_purchase()
{
    self process_perk_purchase("specialty_quickrevive", self.whos_who_price, self.original_quickrevive_machine_location, "zombie_perk_bottle_revive", self.has_whos_who);
    // give_perk on specialty_finalstand sets lives = 1, which arms the chugabud clone last-stand
    self maps\mp\zombies\_zm_perks::give_perk("specialty_finalstand");
    self.has_whos_who = true;
    self.last_quickrevive_purchase_time = GetTime();
    self notify("perk_acquired");
    self iprintln("^2Who's Who Acquired!\n^3When you fall, a clone of you will remain at your body.\n^1Revive yourself before it bleeds out!");
}

// custom Who's Who last stand: unlike the stock chugabud one it never notifies
// "fake_death" (that notify is what makes perk_think strip every perk) and never
// takes the weapons away, so the player keeps everything in shadow mode and
// after being revived; only Who's Who itself is removed once spent
whos_who_laststand()
{
    self endon("player_suicide");
    self endon("disconnect");

    self maps\mp\zombies\_zm_laststand::increment_downed_stat();
    self.whos_who_finishing = false;
    self.health = self.maxhealth;

    self allowstand(false);
    self allowcrouch(false);
    self allowprone(true);
    self.ignoreme = true;
    self enableinvulnerability();
    self freezecontrols(true);
    wait 0.9;

    playsoundatposition("evt_ww_disappear", self.origin);
    playfx(level._effect["chugabud_revive_fx"], self.origin);

    corpse = maps\mp\zombies\_zm_clone::spawn_player_clone(self, self.origin, undefined, self.whos_who_shader);
    corpse.angles = self.angles;
    corpse maps\mp\zombies\_zm_clone::clone_give_weapon("m1911_zm");
    corpse maps\mp\zombies\_zm_clone::clone_animate("laststand");
    corpse.revive_hud = self whos_who_revive_hud_create();
    corpse thread maps\mp\zombies\_zm_laststand::revive_trigger_spawn();
    corpse thread whos_who_corpse_revive_icon(self);
    corpse thread whos_who_corpse_cleanup_on_spectator(self);
    self.e_whos_who_corpse = corpse;

    // the perk is spent as soon as the clone exists: removing it here stops the
    // engine's chugabud check (lives > 0 + specialty_finalstand) from spawning a
    // fresh clone on every fall while the player is in shadow mode
    self whos_who_remove_perk();

    spawnpoint = maps\mp\zombies\_zm_chugabud::chugabud_get_spawnpoint();
    self setorigin(spawnpoint.origin);
    self setplayerangles(spawnpoint.angles);
    playsoundatposition("evt_ww_appear", spawnpoint.origin);
    playfx(level._effect["chugabud_revive_fx"], spawnpoint.origin);
    self allowstand(true);
    self allowcrouch(true);
    self allowprone(true);
    self.ignoreme = false;
    self setstance("stand");
    self freezecontrols(false);
    wait 1;
    self disableinvulnerability();

    // solo: re-arm quick revive so falling again in shadow mode self-revives
    saved_lives = self.lives;
    if(flag("solo_game") && self hasPerk("specialty_quickrevive"))
        self.lives = 1;

    self thread whos_who_cleanup_on_shadow_down(corpse, saved_lives);
    corpse thread whos_who_bleed_timer(getdvarfloat(#"player_lastStandBleedoutTime"));
    corpse waittill_any("player_revived", "bleedout_time_over");

    if(isDefined(corpse.bled_out) && corpse.bled_out)
        self whos_who_finish(corpse, false, saved_lives);
    else
        self whos_who_finish(corpse, true, saved_lives);
}

whos_who_finish(corpse, was_revived, saved_lives)
{
    if(self.whos_who_finishing)
        return;
    self.whos_who_finishing = true;

    if(was_revived)
    {
        self setorigin(corpse.origin);
        self setplayerangles(corpse.angles);
        playsoundatposition("evt_ww_appear", corpse.origin);
        playfx(level._effect["chugabud_revive_fx"], corpse.origin);
        if(isDefined(saved_lives))
            self.lives = saved_lives;
    }

    self whos_who_corpse_cleanup(corpse, was_revived);

    // Who's Who is spent (normally already removed when the clone spawned), but
    // perks, weapons and mod upgrades are all kept
    self whos_who_remove_perk();
    self.whos_who_finishing = false;
    self.e_whos_who_corpse = undefined;
}

whos_who_remove_perk()
{
    if(self hasPerk("specialty_finalstand"))
    {
        self unsetperk("specialty_finalstand");
        self.num_perks--;
        self maps\mp\zombies\_zm_perks::set_perk_clientfield("specialty_finalstand", 0);
    }
    self.hasperkspecialtychugabud = undefined;
    self.has_whos_who = false;
}

whos_who_bleed_timer(delay)
{
    wait(delay);

    if(isDefined(self.revivetrigger))
    {
        while(self.revivetrigger.beingrevived)
            wait 0.01;
    }

    self.bled_out = true;
    self notify("bleedout_time_over");
}

whos_who_cleanup_on_shadow_down(corpse, saved_lives)
{
    self endon("disconnect");

    while(isDefined(self.e_whos_who_corpse) && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        wait 0.1;

    if(!isDefined(self.e_whos_who_corpse))
        return;

    // the player fell again in shadow mode: remove the original body so there
    // are no doubles and let the normal last stand / quick revive flow take over
    self whos_who_corpse_cleanup(corpse, false);
    self.whos_who_finishing = false;
    self.e_whos_who_corpse = undefined;
    self whos_who_remove_perk();
    self.has_whos_who = false;
    self.can_buy_whos_who = true;
    self.fighters_fizz_saved_has_whos_who = false;

    if(is_true(self.has_fighters_fizz))
    {
        level.no_end_game_check = 1;
        self.fighters_fizz_active = true;
        if(self hasPerk("specialty_quickrevive") && !is_true(self.fighters_fizz_had_quickrevive))
        {
            self.fighters_fizz_had_quickrevive = true;
            self.fighters_fizz_saved_lives = isDefined(saved_lives) ? saved_lives : (isDefined(self.lives) ? self.lives : 1);
            self.lives = 0;
        }
        self thread fighters_fizz_active_laststand();
    }
}

whos_who_corpse_cleanup(corpse, was_revived)
{
    if(!was_revived)
    {
        playsoundatposition("evt_ww_disappear", corpse.origin);
        playfx(level._effect["chugabud_bleedout_fx"], corpse.origin);
    }

    if(isDefined(corpse.revivetrigger))
    {
        corpse notify("stop_revive_trigger");
        corpse.revivetrigger delete();
        corpse.revivetrigger = undefined;
    }

    if(isDefined(corpse.revive_hud_elem))
    {
        corpse.revive_hud_elem destroy();
        corpse.revive_hud_elem = undefined;
    }

    if(isDefined(self.revive_hud))
    {
        self.revive_hud destroy();
        self.revive_hud = undefined;
    }

    wait 0.1;
    corpse delete();
    self.e_whos_who_corpse = undefined;
}

whos_who_corpse_cleanup_on_spectator(player)
{
    self endon("death");
    player endon("disconnect");

    while(player.sessionstate != "spectator")
        wait 0.05;

    player.whos_who_finishing = false;
    player.e_whos_who_corpse = undefined;
    player.has_fighters_fizz = false;
    player.fighters_fizz_active = false;
    level.no_end_game_check = undefined;
    player whos_who_corpse_cleanup(self, false);
}

whos_who_corpse_revive_icon(player)
{
    self endon("death");
    height_offset = 30;
    hud_elem = newhudelem();
    self.revive_hud_elem = hud_elem;
    hud_elem.x = self.origin[0];
    hud_elem.y = self.origin[1];
    hud_elem.z = self.origin[2] + height_offset;
    hud_elem.alpha = 1;
    hud_elem.archived = 1;
    hud_elem setshader("waypoint_revive", 5, 5);
    hud_elem setwaypoint(1);
    hud_elem.hidewheninmenu = 1;
    hud_elem.immunetodemogamehudsettings = 1;

    while(isDefined(self.revive_hud_elem))
    {
        hud_elem.x = self.origin[0];
        hud_elem.y = self.origin[1];
        hud_elem.z = self.origin[2] + height_offset;
        wait 0.01;
    }
}

whos_who_revive_hud_create()
{
    self.revive_hud = newclienthudelem(self);
    self.revive_hud.alignx = "center";
    self.revive_hud.aligny = "middle";
    self.revive_hud.horzalign = "center";
    self.revive_hud.vertalign = "bottom";
    self.revive_hud.y = -50;
    self.revive_hud.foreground = 1;
    self.revive_hud.font = "default";
    self.revive_hud.fontscale = 1.5;
    self.revive_hud.alpha = 0;
    self.revive_hud.color = ( 1, 1, 1 );
    self.revive_hud settext("");
    return self.revive_hud;
}

process_punchcola_purchase()
{
    self process_perk_purchase("specialty_rof", self.punchcola_price, self.original_doubletap_machine_location, "zombie_perk_bottle_doubletap");
    self.punchcola_damage_level++;
    self.multi_punchcola_counter++;
    self.punchcola_price = self.starting_punchcola_price * self.multi_punchcola_counter;
    self.last_doubletap_purchase_time = GetTime();
    self iprintln("^1Punch-a-Cola Level " + (self.punchcola_damage_level - 1) + "\n^2Damage Multiplier: x" + self.punchcola_damage_level);
}

process_winters_wail_purchase()
{
    self process_perk_purchase("specialty_rof", self.winters_wail_price, self.original_doubletap_machine_location, "zombie_perk_bottle_doubletap", self.has_winters_wail);
    self.has_winters_wail = true;
    self.winters_wail_charges = 3;
    self.winters_wail_lock = false;
    self.last_doubletap_purchase_time = GetTime();
    self thread monitor_winters_wail();
    self iprintln("^2Winter's Wail Acquired! ^7[3 charges]\n^3Taking a hit while wounded triggers a frost blast that freezes zombies around you.\n^1Recharges over time, refills every round and with Max Ammo.");
}

process_doubletap_1_purchase()
{
    self process_perk_purchase("specialty_rof", self.doubletap_1_price, self.original_doubletap_machine_location, "zombie_perk_bottle_doubletap");
    self.has_doubletap_1 = true;
    self.doubletap_1_level++;
    self.doubletap_1_counter++;
    self.doubletap_1_price = self.starting_doubletap_1_price * self.doubletap_1_counter;
    self.last_doubletap_purchase_time = GetTime();

    rate_boost_pct = self.doubletap_1_level * 15;
    base_mult = 1.0;
    if(isDefined(level.default_weap_rate_mult) && level.default_weap_rate_mult > 0.0)
        base_mult = level.default_weap_rate_mult;

    mult = base_mult / (1.0 + (0.15 * self.doubletap_1_level));
    if(mult < 0.05)
        mult = 0.05;

    self setclientdvar("perk_weapRateMultiplier", "" + mult);
    setdvar("perk_weapRateMultiplier", mult);

    self iprintln("^3Multi-Double Tap 1.0 Level " + self.doubletap_1_level + "\n^2Fire Rate increased by +15 percent\n^3Total Fire Rate: +" + (self.doubletap_1_level * 15) + " percent faster!");
}

process_vigor_rush_purchase()
{
    self process_perk_purchase("specialty_rof", self.vigor_rush_price, self.original_doubletap_machine_location, "zombie_perk_bottle_doubletap", self.has_vigor_rush);
    self.has_vigor_rush = true;
    self.can_buy_vigor_rush = false;
    self.last_doubletap_purchase_time = GetTime();

    self iprintln("^2Vigor Rush Acquired!\n^3Bullet weapons create small explosions when shooting zombies!");
}

// Winter's Wail (BO4 recreation): defensive frost blast triggered when the
// player takes a hit while below full health; 3 charges, +1 every 60s,
// fully refilled on round start and on Max Ammo
monitor_winters_wail()
{
    self endon("disconnect");
    self endon("death");

    self thread winters_wail_recharge();
    self thread winters_wail_round_refill();
    self thread winters_wail_maxammo_refill();
}

winters_wail_recharge()
{
    self endon("disconnect");
    self endon("death");

    while(self.has_winters_wail)
    {
        wait 60;
        if(self.has_winters_wail && self.winters_wail_charges < 3)
        {
            self.winters_wail_charges++;
            self iprintln("^2Winter's Wail:^7 charge restored ^3[" + self.winters_wail_charges + "/3]");
        }
    }
}

winters_wail_round_refill()
{
    self endon("disconnect");
    self endon("death");

    last_round = level.round_number;

    while(self.has_winters_wail)
    {
        if(level.round_number != last_round)
        {
            last_round = level.round_number;
            if(self.winters_wail_charges < 3)
            {
                self.winters_wail_charges = 3;
                self iprintln("^2Winter's Wail:^7 charges restored ^3[3/3]");
            }
        }
        wait 0.5;
    }
}

winters_wail_maxammo_refill()
{
    self endon("disconnect");
    self endon("death");

    while(self.has_winters_wail)
    {
        self waittill("zmb_max_ammo");
        if(self.has_winters_wail)
        {
            if(self.winters_wail_charges < 3)
            {
                self.winters_wail_charges = 3;
                self iprintln("^2Winter's Wail:^7 charges restored ^3[3/3]");
            }
        }
    }
}

winters_wail_cooldown()
{
    self notify("winters_wail_cooldown_started");
    self endon("winters_wail_cooldown_started");
    self endon("disconnect");
    self endon("death");

    self.winters_wail_lock = true;
    wait 5;
    self.winters_wail_lock = false;
}

winters_wail_blast()
{
    self.winters_wail_charges--;
    self thread winters_wail_cooldown();

    // 3x layered VFX radial burst for exaggerated frost blast
    self thread play_winters_wail_blast_fx();

    earthquake(0.35, 0.8, self.origin, 1000);
    self playsound("evt_ww_appear");
    self iprintln("^3Winter's Wail frost blast! ^7[" + self.winters_wail_charges + "/3]");

    zombies = getAiArray(level.zombie_team);
    foreach(z in zombies)
    {
        if(distance(self.origin, z.origin) < 225)
        {
            z doDamage(100 + level.round_number * 20, z.origin, self);
            z thread winters_wail_freeze();
        }
    }
}

play_winters_wail_blast_fx()
{
    // Center burst
    playfx(level._effect["winters_wail"], self.origin);
    playfx(level._effect["powerup_grabbed_wave"], self.origin);
    playfx(level._effect["winters_wail_eyes"], self.origin + (0, 0, 30));

    // Radial offsets to expand frost cloud 3x (+25% range)
    offsets = array(
        (50, 0, 10),
        (-50, 0, 10),
        (0, 50, 10),
        (0, -50, 10),
        (35, 35, 15),
        (-35, -35, 15),
        (35, -35, 15),
        (-35, 35, 15)
    );

    foreach(offset in offsets)
    {
        playfx(level._effect["winters_wail"], self.origin + offset);
        playfx(level._effect["winters_wail_eyes"], self.origin + offset);
    }
}

// runs on the zombie: frozen solid first, then thawing (slow), then normal
winters_wail_emergency_invulnerability(duration)
{
    self notify("winters_wail_invuln_started");
    self endon("winters_wail_invuln_started");
    self endon("disconnect");
    self endon("death");

    self.winters_wail_invulnerable = true;
    wait duration;
    self.winters_wail_invulnerable = false;
}

winters_wail_freeze()
{
    self endon("death");

    self.is_frozen = true;
    playfxontag(level._effect["winters_wail_eyes"], self, "J_SpineUpper");

    if(!isDefined(self.zombie_move_speed))
        return;

    if(!isDefined(self.zombie_move_speed_original))
        self.zombie_move_speed_original = self.zombie_move_speed;

    // phase 1: completely frozen solid and physically anchored in place
    self notify("stop_find_flesh");
    self notify("zombie_acquire_enemy");
    self.ignoreall = 1;

    anchor = spawn("script_origin", self.origin);
    anchor.angles = self.angles;
    self linkto(anchor);

    self thread winters_wail_anchor_cleanup(anchor);

    wait 3;

    // phase 2: unfreeze and thaw, moving slowly
    self.is_frozen = false;
    if(isDefined(anchor))
    {
        self unlink();
        anchor delete();
    }

    self.ignoreall = 0;
    self set_zombie_run_cycle("walk");
    self.zombie_move_speed = "walk";
    self thread maps\mp\zombies\_zm_ai_basic::find_flesh();
    wait 4;

    // phase 3: back to normal speed
    if(isDefined(self.zombie_move_speed_original))
    {
        self set_zombie_run_cycle(self.zombie_move_speed_original);
        self.zombie_move_speed = self.zombie_move_speed_original;
        self.zombie_move_speed_original = undefined;
    }
}

winters_wail_anchor_cleanup(anchor)
{
    self waittill("death");
    if(isDefined(anchor))
        anchor delete();
}

perk_bought_check()
{
    self endon("death");
    self endon("disconnect");
    self thread monitor_perk_status();
    
    for(;;)
    {
        self.perk_reminder = self.num_perks;
        self waittill("perk_acquired");
        
        if(self hasPerk("specialty_additionalprimaryweapon") && !isDefined(self.original_mule_kick_machine_location))
        {
            self.original_mule_kick_machine_location = self get_player_perk_machine_location("mule_kick");
            self.last_mule_kick_purchase_time = GetTime();
            self.can_buy_multi_mule = false; wait 1; self.can_buy_multi_mule = true;
        }
        
        if(self hasPerk("specialty_armorvest") && !isDefined(self.original_jugger_machine_location))
        {
            self.original_jugger_machine_location = self get_player_perk_machine_location("jugger");
            self.last_jugger_purchase_time = GetTime();
            self.can_buy_multi_jugger = false;
            self.can_buy_vulture = false;
            self.can_buy_ethereal_razor = false;
            self.can_buy_dam_a_nade = false;
            wait 1;
            self.can_buy_multi_jugger = true;
            self.can_buy_vulture = true;
            self.can_buy_ethereal_razor = true;
            self.can_buy_dam_a_nade = true;
        }
        
        if(self hasPerk("specialty_longersprint") && !isDefined(self.original_staminup_machine_location))
        {
            self.original_staminup_machine_location = self get_player_perk_machine_location("staminup");
            self.last_staminup_purchase_time = GetTime();
            self.can_buy_jetpack = false;
            self.can_buy_staminup = false;
            self.can_buy_bandolier_bandit = false;
            self.can_buy_blood_bullets = false;
            self.can_buy_nitrogen_cooled = false;
            wait 1;
            self.can_buy_jetpack = true;
            self.can_buy_staminup = true;
            self.can_buy_bandolier_bandit = true;
            self.can_buy_blood_bullets = true;
            self.can_buy_nitrogen_cooled = true;
        }
        
        if(self hasPerk("specialty_fastreload") && !isDefined(self.original_speedcola_machine_location))
        {
            self.original_speedcola_machine_location = self get_player_perk_machine_location("speedcola");
            self.last_speedcola_purchase_time = GetTime();
            self.can_buy_pointcrusher = false;
            self.can_buy_speedcola = false;
            self.can_buy_cashback = false;
            self.can_buy_repairman = false;
            wait 1;
            self.can_buy_pointcrusher = true;
            self.can_buy_speedcola = true;
            self.can_buy_cashback = true;
            self.can_buy_repairman = true;
        }
        
        if(self hasPerk("specialty_quickrevive") && !isDefined(self.original_quickrevive_machine_location))
        {
            self.original_quickrevive_machine_location = self get_player_perk_machine_location("quickrevive");
            self.last_quickrevive_purchase_time = GetTime();
            // raise flags at the same time: if one becomes true earlier the
            // trigger is created in that window with an incomplete hintstring
            self.can_buy_muscle_milk = false;
            self.can_buy_whos_who = false;
            self.can_buy_fighters_fizz = false;
            wait 1;
            self.can_buy_muscle_milk = true;
            self.can_buy_whos_who = true;
            self.can_buy_fighters_fizz = true;
        }

        if(self hasPerk("specialty_rof") && !isDefined(self.original_doubletap_machine_location))
        {
            self.original_doubletap_machine_location = self get_player_perk_machine_location("doubletap");
            self.last_doubletap_purchase_time = GetTime();
            if(!isDefined(self.punchcola_damage_level)) self.punchcola_damage_level = 1;
            self.can_buy_punchcola = false;
            self.can_buy_winters_wail = false;
            self.can_buy_doubletap_1 = false;
            self.can_buy_vigor_rush = false;
            wait 1;
            self.can_buy_punchcola = true;
            self.can_buy_winters_wail = true;
            self.can_buy_doubletap_1 = true;
            self.can_buy_vigor_rush = true;
        }
        
        n = 1;
        if(!(self.num_perks > self.perk_reminder))
        {
            n = (self.num_perks - self.perk_reminder);
            self.num_perks = (self.perk_reminder + n);
        }
        self.perk_reminder = self.num_perks;
        self.perk_count += n;
    }
}

monitor_perk_status()
{
    self endon("death");
    self endon("disconnect");
    
    while(true)
    {
        if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand() || is_true(self.fighters_fizz_active))
        {
            wait 0.2;
            continue;
        }

        if ((!isdefined(level.zombiemode_using_afterlife) || !level.zombiemode_using_afterlife || !is_true(self.afterlife)) && !isDefined(self.e_whos_who_corpse))
        {
            // Mule Kick
            if(!self hasPerk("specialty_additionalprimaryweapon"))
            {
                if(self is_perk_paused("specialty_additionalprimaryweapon") || (is_true(self.had_mule_kick) && !is_perk_machine_powered("specialty_additionalprimaryweapon")))
                {
                    if(isDefined(self.current_mule_kick_trigger))
                    {
                        self.current_mule_kick_trigger delete();
                        self.current_mule_kick_trigger = undefined;
                    }
                }
                else
                {
                    self.had_mule_kick = false;
                    self.multi_mule_kick_counter = 1;
                    self.mule_kick_price = self.starting_mule_kick_price;
                    self.original_mule_kick_machine_location = undefined;
                    self.last_mule_kick_purchase_time = 0;
                    self.weapon_limit_counter = 3;
                    self.can_buy_multi_mule = false;
                    if(isDefined(self.current_mule_kick_trigger))
                    {
                        self.current_mule_kick_trigger delete();
                        self.current_mule_kick_trigger = undefined;
                    }
                }
            }
            else
            {
                self.had_mule_kick = true;
                if(!isDefined(self.original_mule_kick_machine_location))
                    self.original_mule_kick_machine_location = self get_player_perk_machine_location("mule_kick");
                if(GetTime() - self.last_mule_kick_purchase_time >= 1000)
                    self.can_buy_multi_mule = true;
            }
            
            // Juggernog
            if(!self hasPerk("specialty_armorvest"))
            {
                if(self is_perk_paused("specialty_armorvest") || (is_true(self.had_juggernog) && !is_perk_machine_powered("specialty_armorvest")))
                {
                    if(isDefined(self.current_jugger_trigger))
                    {
                        self.current_jugger_trigger delete();
                        self.current_jugger_trigger = undefined;
                    }
                }
                else
                {
                    self.had_juggernog = false;
                    self.multi_juggernog_counter = 1;
                    self.jugger_price = self.starting_jugger_price;
                    self.has_vulture = false;
                    self.can_buy_vulture = false;
                    self.can_buy_multi_jugger = false;
                    self.has_ethereal_razor = false;
                    self.ethereal_razor_level = 0;
                    self.ethereal_razor_price = 3000;
                    self.can_buy_ethereal_razor = false;
                    self.has_dam_a_nade = false;
                    self.dam_a_nade_level = 0;
                    self.dam_a_nade_price = 2500;
                    self.can_buy_dam_a_nade = false;
                    self.original_jugger_machine_location = undefined;
                    self.last_jugger_purchase_time = 0;
                    if(isDefined(self.current_jugger_trigger))
                    {
                        self.current_jugger_trigger delete();
                        self.current_jugger_trigger = undefined;
                    }
                }
            }
            else
            {
                self.had_juggernog = true;
                if(!isDefined(self.original_jugger_machine_location))
                    self.original_jugger_machine_location = self get_player_perk_machine_location("jugger");
                if(GetTime() - self.last_jugger_purchase_time >= 1000)
                {
                    self.can_buy_multi_jugger = true;
                    self.can_buy_vulture = true;
                    self.can_buy_ethereal_razor = true;
                    self.can_buy_dam_a_nade = true;
                }
                if(isDefined(self.multi_juggernog_counter) && self.multi_juggernog_counter > 1)
                {
                    min_health = 250 + ((self.multi_juggernog_counter - 1) * 150);
                    if(self.maxhealth < min_health)
                    {
                        self.maxhealth = min_health;
                        self.health = self.maxhealth;
                    }
                }
            }
            
            // Stamin-Up
            if(!self hasPerk("specialty_longersprint"))
            {
                if(self is_perk_paused("specialty_longersprint") || (is_true(self.had_staminup) && !is_perk_machine_powered("specialty_longersprint")))
                {
                    if(isDefined(self.current_staminup_trigger))
                    {
                        self.current_staminup_trigger delete();
                        self.current_staminup_trigger = undefined;
                    }
                }
                else
                {
                    self.had_staminup = false;
                    self.has_jetpack = false;
                    self.multi_staminup_counter = 0;
                    self.starting_staminup_price = 2000;
                    self.staminup_price = self.starting_staminup_price;
                    self.can_buy_jetpack = false;
                    self.can_buy_staminup = false;
                    self.has_bandolier_bandit = false;
                    self.bandolier_bandit_level = 0;
                    self.bandolier_bandit_price = 3000;
                    self.can_buy_bandolier_bandit = false;
                    self.bandolier_stash = [];
                    if(isDefined(self.bandolier_hud))
                    {
                        self.bandolier_hud destroy();
                        self.bandolier_hud = undefined;
                    }
                    self.has_blood_bullets = false;
                    self.can_buy_blood_bullets = false;
                    self.has_nitrogen_cooled = false;
                    self.can_buy_nitrogen_cooled = false;
                    self setmovespeedscale(1.0);
                    self.original_staminup_machine_location = undefined;
                    self.last_staminup_purchase_time = 0;
                    if(isDefined(self.current_staminup_trigger))
                    {
                        self.current_staminup_trigger delete();
                        self.current_staminup_trigger = undefined;
                    }
                }
            }
            else
            {
                self.had_staminup = true;
                if(!isDefined(self.original_staminup_machine_location))
                    self.original_staminup_machine_location = self get_player_perk_machine_location("staminup");
                if(GetTime() - self.last_staminup_purchase_time >= 1000)
                {
                    self.can_buy_jetpack = true;
                    self.can_buy_staminup = true;
                    self.can_buy_bandolier_bandit = true;
                    if(!is_true(self.has_blood_bullets))
                        self.can_buy_blood_bullets = true;
                    if(!is_true(self.has_nitrogen_cooled))
                        self.can_buy_nitrogen_cooled = true;
                }
                if(isDefined(self.multi_staminup_counter) && self.multi_staminup_counter > 0)
                {
                    if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
                    {
                        if(!isDefined(self.n_move_scale) || self.n_move_scale >= 1.0)
                        {
                            expected_scale = 1.0 + (0.10 * self.multi_staminup_counter);
                            self setmovespeedscale(expected_scale);
                        }
                    }
                }
            }
            
            // Speed Cola
            if(!self hasPerk("specialty_fastreload"))
            {
                if(self is_perk_paused("specialty_fastreload") || (is_true(self.had_speedcola) && !is_perk_machine_powered("specialty_fastreload")))
                {
                    if(isDefined(self.current_speedcola_trigger))
                    {
                        self.current_speedcola_trigger delete();
                        self.current_speedcola_trigger = undefined;
                    }
                }
                else
                {
                    self.had_speedcola = false;
                    self.multi_pointcrusher_counter = 0;
                    self.pointcrusher_price = self.starting_pointcrusher_price;
                    self.point_multiplier = 1;
                    self.multi_speedcola_counter = 0;
                    self.speedcola_price = self.starting_speedcola_price;
                    self.can_buy_pointcrusher = false;
                    self.can_buy_speedcola = false;
                    self.has_cashback = false;
                    self.cashback_level = 0;
                    self.cashback_price = 3000;
                    self.can_buy_cashback = false;
                    self.has_repairman = false;
                    self.repairman_level = 0;
                    self.repairman_price = 2000;
                    self.can_buy_repairman = false;
                    if(isDefined(level.default_weap_reload_mult))
                    {
                        self setclientdvar("perk_weapReloadMultiplier", "" + level.default_weap_reload_mult);
                        setdvar("perk_weapReloadMultiplier", level.default_weap_reload_mult);
                    }
                    self.original_speedcola_machine_location = undefined;
                    self.last_speedcola_purchase_time = 0;
                    if(isDefined(self.current_speedcola_trigger))
                    {
                        self.current_speedcola_trigger delete();
                        self.current_speedcola_trigger = undefined;
                    }
                }
            }
            else
            {
                self.had_speedcola = true;
                if(!isDefined(self.original_speedcola_machine_location))
                    self.original_speedcola_machine_location = self get_player_perk_machine_location("speedcola");
                if(GetTime() - self.last_speedcola_purchase_time >= 1000)
                {
                    self.can_buy_pointcrusher = true;
                    self.can_buy_speedcola = true;
                    if(!isDefined(self.cashback_level) || self.cashback_level < 2)
                        self.can_buy_cashback = true;
                    self.can_buy_repairman = true;
                }
                if(isDefined(self.multi_speedcola_counter) && self.multi_speedcola_counter > 0)
                {
                    base_mult = 0.5;
                    if(isDefined(level.default_weap_reload_mult) && level.default_weap_reload_mult > 0.0)
                        base_mult = level.default_weap_reload_mult;
                    mult = base_mult / (1.0 + (0.20 * self.multi_speedcola_counter));
                    if(mult < 0.05) mult = 0.05;
                    self setclientdvar("perk_weapReloadMultiplier", "" + mult);
                }
            }
            
            // Quick Revive
            if(!self hasPerk("specialty_quickrevive"))
            {
                if(self is_perk_paused("specialty_quickrevive") || (is_true(self.had_quickrevive) && !is_perk_machine_powered("specialty_quickrevive")))
                {
                    if(isDefined(self.current_quickrevive_trigger))
                    {
                        self.current_quickrevive_trigger delete();
                        self.current_quickrevive_trigger = undefined;
                    }
                }
                else
                {
                    self.had_quickrevive = false;
                    self.has_muscle_milk = false;
                    self.has_whos_who = false;
                    self.has_fighters_fizz = false;
                    self.fighters_fizz_price = 3500;
                    self.can_buy_muscle_milk = false;
                    self.can_buy_whos_who = false;
                    self.can_buy_fighters_fizz = false;
                    self.original_quickrevive_machine_location = undefined;
                    self.last_quickrevive_purchase_time = 0;
                    if(isDefined(self.current_quickrevive_trigger))
                    {
                        self.current_quickrevive_trigger delete();
                        self.current_quickrevive_trigger = undefined;
                    }
                }
            }
            else
            {
                self.had_quickrevive = true;
                if(!isDefined(self.original_quickrevive_machine_location))
                    self.original_quickrevive_machine_location = self get_player_perk_machine_location("quickrevive");
                if(GetTime() - self.last_quickrevive_purchase_time >= 1000)
                {
                    self.can_buy_muscle_milk = true;
                    self.can_buy_whos_who = true;
                    if(!is_true(self.has_fighters_fizz))
                        self.can_buy_fighters_fizz = true;
                }
            }

            // Double Tap
            if(!self hasPerk("specialty_rof"))
            {
                if(self is_perk_paused("specialty_rof") || (is_true(self.had_doubletap) && !is_perk_machine_powered("specialty_rof")))
                {
                    if(isDefined(self.current_doubletap_trigger))
                    {
                        self.current_doubletap_trigger delete();
                        self.current_doubletap_trigger = undefined;
                    }
                }
                else
                {
                    self.had_doubletap = false;
                    self.multi_punchcola_counter = 1;
                    self.punchcola_price = self.starting_punchcola_price;
                    self.punchcola_damage_level = 1;
                    self.has_winters_wail = false;
                    self.winters_wail_charges = 0;
                    self.winters_wail_lock = false;
                    self.can_buy_punchcola = false;
                    self.can_buy_winters_wail = false;
                    self.has_doubletap_1 = false;
                    self.doubletap_1_counter = 1;
                    self.doubletap_1_price = self.starting_doubletap_1_price;
                    self.doubletap_1_level = 0;
                    self.can_buy_doubletap_1 = false;
                    self.has_vigor_rush = false;
                    self.can_buy_vigor_rush = false;
                    if(isDefined(level.default_weap_rate_mult))
                    {
                        self setclientdvar("perk_weapRateMultiplier", "" + level.default_weap_rate_mult);
                        setdvar("perk_weapRateMultiplier", level.default_weap_rate_mult);
                    }
                    self.original_doubletap_machine_location = undefined;
                    self.last_doubletap_purchase_time = 0;
                    if(isDefined(self.current_doubletap_trigger))
                    {
                        self.current_doubletap_trigger delete();
                        self.current_doubletap_trigger = undefined;
                    }
                }
            }
            else
            {
                self.had_doubletap = true;
                if(!isDefined(self.original_doubletap_machine_location))
                    self.original_doubletap_machine_location = self get_player_perk_machine_location("doubletap");
                if(GetTime() - self.last_doubletap_purchase_time >= 1000)
                {
                    self.can_buy_punchcola = true;
                    self.can_buy_winters_wail = true;
                    self.can_buy_doubletap_1 = true;
                    if(!is_true(self.has_vigor_rush))
                        self.can_buy_vigor_rush = true;
                }
                if(isDefined(self.doubletap_1_level) && self.doubletap_1_level > 0)
                {
                    base_mult = 1.0;
                    if(isDefined(level.default_weap_rate_mult) && level.default_weap_rate_mult > 0.0)
                        base_mult = level.default_weap_rate_mult;
                    mult = base_mult / (1.0 + (0.15 * self.doubletap_1_level));
                    if(mult < 0.05) mult = 0.05;
                    self setclientdvar("perk_weapRateMultiplier", "" + mult);
                    setdvar("perk_weapRateMultiplier", mult);
                }
            }
        }
        
        wait 0.5;
    }
}

player_has_custom_perk(perk)
{
    if(isDefined(self.perkarray))
    {
        for(i = 0; i < self.perkarray.size; i++)
        {
            if(isDefined(self.perkarray[i]) && isDefined(self.perkarray[i].name) && self.perkarray[i].name == perk)
                return true;
        }
    }
    return false;
}

custom_get_player_weapon_limit(player)
{
    weapon_limit = 2;
    has_mule = false;
    if(player hasPerk("specialty_additionalprimaryweapon"))
        has_mule = true;
    else if(player player_has_custom_perk("MULE"))
        has_mule = true;

    if(has_mule)
    {
        if(isDefined(player.weapon_limit_counter) && player.weapon_limit_counter >= 3)
            weapon_limit = player.weapon_limit_counter;
        else
            weapon_limit = 3;
    }
    else 
    {
        weapons = player getWeaponsListPrimaries();
        if(weapons.size > 2)
            player takeWeapon(weapons[2]);
    }
    return weapon_limit;
}

enforce_mod_compatibility()
{
    level endon("end_game");

    while(true)
    {
        level.get_player_weapon_limit = ::custom_get_player_weapon_limit;
        level.perk_purchase_limit = 99;

        if(isDefined(level.original_damagecallback) && level.original_damagecallback == ::multi_perks_actor_damage_wrapper)
        {
            if(isDefined(level.compat_prev_callbackactordamage) && level.compat_prev_callbackactordamage != ::multi_perks_actor_damage_wrapper)
                level.original_damagecallback = level.compat_prev_callbackactordamage;
        }

        if(isDefined(level.callbackactordamage) && level.callbackactordamage != ::multi_perks_actor_damage_wrapper)
        {
            level.compat_prev_callbackactordamage = level.callbackactordamage;
            level.callbackactordamage = ::multi_perks_actor_damage_wrapper;
        }

        if(!isDefined(level.player_damage_callbacks))
        {
            level.player_damage_callbacks = [];
            level.player_damage_callbacks[0] = ::multi_perks_player_damage_wrapper;
        }
        else
        {
            needs_wrap = false;
            for(i = 0; i < level.player_damage_callbacks.size; i++)
            {
                if(level.player_damage_callbacks[i] != ::multi_perks_player_damage_wrapper)
                {
                    needs_wrap = true;
                    break;
                }
            }
            if(needs_wrap)
            {
                level.compat_prev_player_damage_callbacks = [];
                for(i = 0; i < level.player_damage_callbacks.size; i++)
                {
                    if(level.player_damage_callbacks[i] != ::multi_perks_player_damage_wrapper)
                    {
                        level.compat_prev_player_damage_callbacks[level.compat_prev_player_damage_callbacks.size] = level.player_damage_callbacks[i];
                    }
                }
                level.player_damage_callbacks = [];
                level.player_damage_callbacks[0] = ::multi_perks_player_damage_wrapper;
            }
        }

        if(!isDefined(level._game_module_game_end_check) || level._game_module_game_end_check != ::fighters_fizz_game_end_check)
        {
            level.original_game_module_game_end_check = level._game_module_game_end_check;
            level._game_module_game_end_check = ::fighters_fizz_game_end_check;
        }

        if(!isDefined(level.zbarrier_zombie_tear_notetrack_override) || level.zbarrier_zombie_tear_notetrack_override != ::repairman_tear_chunk_callback)
        {
            level.original_zbarrier_tear_override = level.zbarrier_zombie_tear_notetrack_override;
            level.zbarrier_zombie_tear_notetrack_override = ::repairman_tear_chunk_callback;
        }

        wait 0.2;
    }
}

fighters_fizz_game_end_check()
{
    players = get_players();
    foreach(p in players)
    {
        if(p.sessionstate != "spectator")
        {
            if(is_true(p.fighters_fizz_active))
            {
                return false;
            }
            if(is_true(p.has_fighters_fizz) && p maps\mp\zombies\_zm_laststand::player_is_in_laststand() && !is_true(p.whos_who_finishing))
            {
                return false;
            }
        }
    }

    if(isDefined(level.original_game_module_game_end_check) && level.original_game_module_game_end_check != ::fighters_fizz_game_end_check)
    {
        return [[ level.original_game_module_game_end_check ]]();
    }

    return true;
}

multi_perks_actor_damage_wrapper( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime, boneindex )
{
    final_damage = damage;

    if(isDefined(attacker) && isPlayer(attacker))
    {
        is_melee = false;
        is_thrown_ballistic = false;

        if(meansofdeath == "MOD_MELEE")
        {
            is_melee = true;
        }
        else if(meansofdeath == "MOD_IMPACT" && isDefined(weapon) && issubstr(weapon, "knife_ballistic"))
        {
            is_thrown_ballistic = true;
        }
        else if(isDefined(weapon))
        {
            if(issubstr(weapon, "one_inch_punch") || issubstr(weapon, "knife") || issubstr(weapon, "knuckles") || issubstr(weapon, "spoon") || issubstr(weapon, "spork") || issubstr(weapon, "_melee"))
            {
                is_melee = true;
            }
            else if(issubstr(weapon, "staff_") && issubstr(weapon, "_upgraded") && isDefined(attacker.ismeleeing) && attacker ismeleeing())
            {
                is_melee = true;
            }
        }

        // Muscle Milk: fires shockwave on melee hit
        if(is_melee && is_true(attacker.has_muscle_milk) && !attacker.muscle_milk_cooldown && !attacker.is_purchasing)
        {
            attacker thread muscle_milk_attack(self, vpoint);
        }

        // Ethereal Razor:
        // 1) Thrown ballistic knife blade: x5 damage per level, heal, but NO radius cleave
        if(is_thrown_ballistic && is_true(attacker.has_ethereal_razor) && isDefined(attacker.ethereal_razor_level) && attacker.ethereal_razor_level > 0)
        {
            mult = 5 * attacker.ethereal_razor_level;
            final_damage = int(final_damage * mult);

            heal_amount = 50 * attacker.ethereal_razor_level;
            if(attacker.health < attacker.maxhealth)
            {
                attacker.health = min(attacker.maxhealth, attacker.health + heal_amount);
            }
        }
        // 2) Melee attacks: x5 damage per level, heal, AND radius cleave attack
        else if(is_melee && is_true(attacker.has_ethereal_razor) && isDefined(attacker.ethereal_razor_level) && attacker.ethereal_razor_level > 0)
        {
            if(!is_true(attacker.ethereal_razor_in_cleave) && !is_true(level.ethereal_razor_in_cleave))
            {
                mult = 5 * attacker.ethereal_razor_level;
                final_damage = int(final_damage * mult);

                heal_amount = 50 * attacker.ethereal_razor_level;
                if(attacker.health < attacker.maxhealth)
                {
                    attacker.health = min(attacker.maxhealth, attacker.health + heal_amount);
                }

                attacker thread ethereal_razor_cleave(self, vpoint, final_damage, weapon);
            }
        }

        // Dam-A-Nade: x10 grenades, x2 normal explosives per level
        if(is_true(attacker.has_dam_a_nade) && isDefined(attacker.dam_a_nade_level) && attacker.dam_a_nade_level > 0 && !is_true(attacker.exo_slam_active))
        {
            is_grenade = false;
            is_explosive = false;

            if(meansofdeath == "MOD_GRENADE" || meansofdeath == "MOD_GRENADE_SPLASH")
                is_grenade = true;
            else if(meansofdeath == "MOD_EXPLOSIVE" || meansofdeath == "MOD_PROJECTILE" || meansofdeath == "MOD_PROJECTILE_SPLASH")
                is_explosive = true;

            if(isDefined(weapon))
            {
                if(issubstr(weapon, "grenade") || issubstr(weapon, "frag") || issubstr(weapon, "semtex") || issubstr(weapon, "claymore") || issubstr(weapon, "betty"))
                    is_grenade = true;
                else if(issubstr(weapon, "rpg") || issubstr(weapon, "ray") || issubstr(weapon, "war_machine") || issubstr(weapon, "mortar") || issubstr(weapon, "launcher"))
                    is_explosive = true;
            }

            if(is_grenade)
            {
                final_damage = int(final_damage * (10 * attacker.dam_a_nade_level));
            }
            else if(is_explosive)
            {
                final_damage = int(final_damage * (2 * attacker.dam_a_nade_level));
            }
        }

        // Punch Cola (specialty_rof damage multiplier)
        if(attacker hasPerk("specialty_rof") && isDefined(attacker.punchcola_damage_level) && attacker.punchcola_damage_level > 1)
        {
            final_damage = int(final_damage * attacker.punchcola_damage_level);
        }

        // Vigor Rush: bullet weapons create small explosions when shooting zombies
        if(is_true(attacker.has_vigor_rush) && !is_true(attacker.vigor_rush_in_explosion))
        {
            if(meansofdeath == "MOD_PISTOL_BULLET" || meansofdeath == "MOD_RIFLE_BULLET")
            {
                if(isDefined(vpoint))
                {
                    if(isDefined(vdir) && length(vdir) > 0.01)
                    {
                        hit_normal = -1 * vectornormalize(vdir);
                        impact_pos = vpoint + (hit_normal * 4);
                    }
                    else
                    {
                        hit_normal = (0, 0, 1);
                        impact_pos = vpoint;
                    }
                }
                else
                {
                    impact_pos = self.origin + (0, 0, 40);
                    hit_normal = (0, 0, 1);
                }

                cur_time = GetTime();
                if(!isDefined(attacker.last_vigor_rush_fx_time) || (cur_time - attacker.last_vigor_rush_fx_time >= 40))
                {
                    attacker.last_vigor_rush_fx_time = cur_time;

                    if(isDefined(level._effect["vigor_rush_impact"]))
                        playfx(level._effect["vigor_rush_impact"], impact_pos, hit_normal);
                    else if(isDefined(level._effect["wood_chunk_destory"]))
                        playfx(level._effect["wood_chunk_destory"], impact_pos, hit_normal);
                }

                attacker.vigor_rush_in_explosion = true;
                nearby_zombies = get_round_enemy_array();
                foreach(nz in nearby_zombies)
                {
                    if(isDefined(nz) && isAlive(nz) && nz != self)
                    {
                        if(distance(nz.origin, impact_pos) <= 60)
                        {
                            nz dodamage(150, impact_pos, attacker, attacker, "MOD_GRENADE_SPLASH");
                        }
                    }
                }
                attacker.vigor_rush_in_explosion = false;

                final_damage += 150;
            }
        }

        // Fighter's Fizz kill detection
        if(is_true(attacker.fighters_fizz_active) || (attacker maps\mp\zombies\_zm_laststand::player_is_in_laststand() && is_true(attacker.has_fighters_fizz)))
        {
            if(final_damage >= self.health || (isDefined(self.health) && self.health <= 0) || !isAlive(self))
            {
                attacker notify("fighters_fizz_kill");
            }
        }
    }

    old_maxhealth = undefined;
    if(isDefined(attacker) && isPlayer(attacker) && attacker hasPerk("specialty_armorvest") && isDefined(attacker.multi_juggernog_counter) && attacker.multi_juggernog_counter > 1)
    {
        old_maxhealth = attacker.maxhealth;
    }

    if(isDefined(level.compat_prev_callbackactordamage))
    {
        self [[ level.compat_prev_callbackactordamage ]]( inflictor, attacker, final_damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime, boneindex );
    }

    if(isDefined(old_maxhealth) && isDefined(attacker) && isPlayer(attacker))
    {
        min_jugg_health = 250 + ((attacker.multi_juggernog_counter - 1) * 150);
        max_jugg_cap = 350 + ((attacker.multi_juggernog_counter - 1) * 150);

        if(attacker.maxhealth < min_jugg_health)
        {
            if(attacker.maxhealth == 350 && old_maxhealth >= min_jugg_health)
            {
                attacker.maxhealth = old_maxhealth + 1;
                if(attacker.maxhealth > max_jugg_cap)
                    attacker.maxhealth = max_jugg_cap;
                attacker.health = attacker.maxhealth;
            }
            else
            {
                attacker.maxhealth = min_jugg_health;
                if(attacker.health > attacker.maxhealth)
                    attacker.health = attacker.maxhealth;
            }
        }
    }
}

multi_perks_player_damage_wrapper( einflictor, eattacker, idamage, idflags, smeansofdeath, sweapon, vpoint, vdir, shitloc, psoffsettime, boneindex )
{
    // Exo slide invulnerability
    if(is_true(self.is_sliding))
        return 0;

    // Exo slam fall damage and self-splash damage immunity
    if(is_true(self.exo_slam_active) || is_true(self.is_slamming) || (isDefined(self.last_slam_time) && (GetTime() - self.last_slam_time < 1500)))
    {
        if(smeansofdeath == "MOD_FALLING")
            return 0;
        if(isDefined(eattacker) && eattacker == self)
            return 0;
    }

    if(is_true(self.has_jetpack) && smeansofdeath == "MOD_FALLING")
    {
        if(self.jump_boost > 0 || (isDefined(self.last_boost_time) && (GetTime() - self.last_boost_time < 2500)))
            return 0;
    }

    final_damage = idamage;
    if(isDefined(level.compat_prev_player_damage_callbacks))
    {
        for(i = 0; i < level.compat_prev_player_damage_callbacks.size; i++)
        {
            res = self [[ level.compat_prev_player_damage_callbacks[i] ]]( einflictor, eattacker, final_damage, idflags, smeansofdeath, sweapon, vpoint, vdir, shitloc, psoffsettime, boneindex );
            if(isDefined(res) && res != -1)
            {
                final_damage = res;
                break;
            }
        }
    }

    if(self hasPerk("specialty_armorvest") && isDefined(self.multi_juggernog_counter) && self.multi_juggernog_counter > 1)
    {
        min_jugg_health = 250 + ((self.multi_juggernog_counter - 1) * 150);
        if(self.maxhealth < min_jugg_health)
        {
            self.maxhealth = min_jugg_health;
        }
    }

    // Winter's Wail Emergency Save & Frost Blast logic
    if(isDefined(self.has_winters_wail) && self.has_winters_wail && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        is_zombie_damage = false;
        if(isDefined(eattacker))
        {
            if(isDefined(eattacker.is_zombie) && eattacker.is_zombie)
                is_zombie_damage = true;
            else if(isDefined(eattacker.team) && eattacker.team == level.zombie_team)
                is_zombie_damage = true;
            else if(isAi(eattacker))
                is_zombie_damage = true;
        }

        if(isDefined(smeansofdeath) && (smeansofdeath == "MOD_FALLING" || smeansofdeath == "MOD_SUICIDE"))
            is_zombie_damage = false;

        if(is_zombie_damage)
        {
            // If the attacking zombie is currently frozen solid, negate damage
            if(isDefined(eattacker) && isDefined(eattacker.is_frozen) && eattacker.is_frozen)
            {
                return 0;
            }

            // If recently activated an emergency blast, invulnerability absorbs near-simultaneous hits
            if(isDefined(self.winters_wail_invulnerable) && self.winters_wail_invulnerable)
            {
                return 0;
            }

            if(self.winters_wail_charges > 0)
            {
                // Emergency save condition: health <= 150 OR incoming damage would down the player
                if(self.health <= 150 || final_damage >= self.health)
                {
                    self thread winters_wail_blast();
                    self thread winters_wail_emergency_invulnerability(1.5);

                    // If incoming damage is lethal, negate it completely so the player does not die!
                    if(final_damage >= self.health)
                    {
                        final_damage = 0;
                    }
                }
                else if(self.health < self.maxhealth && !self.winters_wail_lock)
                {
                    self thread winters_wail_blast();
                    self thread winters_wail_emergency_invulnerability(1.0);
                }
            }
        }
    }

    if(final_damage >= self.health && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        if(is_true(self.has_whos_who) && self.lives > 0 && self hasPerk("specialty_finalstand"))
        {
            // Who's Who priority
        }
        else if(is_true(self.has_fighters_fizz))
        {
            self.fighters_fizz_active = true;

            if(self hasPerk("specialty_quickrevive"))
            {
                self.fighters_fizz_had_quickrevive = true;
                self.fighters_fizz_saved_lives = self.lives;
                self.lives = 0;
            }
        }
    }

    return final_damage;
}

monitor_juggernog_health()
{
    self endon("disconnect");
    for(;;)
    {
        if(self hasPerk("specialty_armorvest") && isDefined(self.multi_juggernog_counter) && self.multi_juggernog_counter > 1)
        {
            min_health = 250 + ((self.multi_juggernog_counter - 1) * 150);
            if(self.maxhealth < min_health)
            {
                self.maxhealth = min_health;
            }
        }
        wait 0.1;
    }
}

monitor_staminup_speed()
{
    self endon("disconnect");
    for(;;)
    {
        if(self hasPerk("specialty_longersprint") && isDefined(self.multi_staminup_counter) && self.multi_staminup_counter > 0)
        {
            if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
            {
                if(!isDefined(self.n_move_scale) || self.n_move_scale >= 1.0)
                {
                    expected_scale = 1.0 + (0.10 * self.multi_staminup_counter);
                    self setmovespeedscale(expected_scale);
                }
            }
        }
        wait 0.5;
    }
}

init_jetpack()
{
    self endon("disconnect");
    level endon("end_game");
    
    self.sprint_boost = 0; self.jump_boost = 0; self.slam_boost = 0;
    self.exo_boost = 100; self.is_flying_jetpack = 0;
    self.last_boost_time = 0; self.boost_cooldown = false; self.hover_active = false;
    self.is_sliding = false;
    self.last_slide_time = 0;
    
    self thread monitor_exo_boost();
    self thread handle_jetpack_movement();
    self thread monitor_exo_slide();
}

handle_jetpack_movement()
{
    self endon("disconnect");
    level endon("end_game");
    
    while(1)
    {
        if(self.has_jetpack && !self isonground())
        {
            if(self sprintbuttonpressed() || self jumpbuttonpressed()) { wait_network_frame(); continue; }
            
            self.sprint_boost = 0; self.jump_boost = 0; self.slam_boost = 0;
            start_slam_z = self.origin[2];
            
            while(!self isonground())
            {
                if(self.exo_boost >= 20 && self.jump_boost < 1 && self jumpbuttonpressed())
                {
                    self.is_flying_jetpack = 1; self.jump_boost++;
                    earthquake(0.22, 0.9, self.origin, 850);
                    self playrumbleonentity("damage_heavy");
                    self setvelocity((self getvelocity()[0], self getvelocity()[1], 350));
                    self thread land(); self.exo_boost -= 20; self thread monitor_exo_boost();
                }
                
                if(self.exo_boost >= 20 && self.sprint_boost < 1 && self sprintbuttonpressed())
                {
                    self.is_flying_jetpack = 1; self.sprint_boost++;
                    angles = self getplayerangles(); direction = anglestoforward(angles);
                    current_vel = self getvelocity();
                    boost_vel = (current_vel[0] + direction[0] * 600, current_vel[1] + direction[1] * 600, current_vel[2]);
                    earthquake(0.22, 0.9, self.origin, 850);
                    self playrumbleonentity("damage_heavy");
                    self setvelocity(boost_vel);
                    self thread land(); self.exo_boost -= 20; self thread monitor_exo_boost();
                }
                
                if(self adsbuttonpressed() && self.exo_boost > 0)
                {
                    current_vel = self getvelocity();
                    hover_vel = (current_vel[0] * 0.92, current_vel[1] * 0.92, -10);
                    self setvelocity(hover_vel);
                    self.exo_boost = max(0, self.exo_boost - 0.4);
                }
                
                if(self.exo_boost >= 30 && self.slam_boost < 1 && self.jump_boost > 0 && self stancebuttonpressed())
                {
                    self.slam_boost++;
                    self.is_slamming = true;
                    self.exo_slam_active = true;
                    start_slam_z = self.origin[2];
                    current_vel = self getvelocity();
                    self setvelocity((current_vel[0] * 0.3, current_vel[1] * 0.3, -650));
                    self playrumbleonentity("damage_heavy");
                    self thread land(); self.exo_boost -= 30; self thread monitor_exo_boost();
                }
                
                wait_network_frame();
            }
            
            if(self.slam_boost > 0)
            {
                self.last_slam_time = GetTime();
                self.exo_slam_active = true;
                drop_height = max(100, start_slam_z - self.origin[2]);
                slam_radius = clamp(int(120 + (drop_height / 350.0) * 120), 120, 240);
                
                slam_mult = 1.0;
                if(is_true(self.has_dam_a_nade) && isDefined(self.dam_a_nade_level) && self.dam_a_nade_level > 0)
                {
                    slam_mult = 2.0 * self.dam_a_nade_level;
                }

                base_dmg = int((2000 + clamp(drop_height * 4, 0, 2000)) * slam_mult);
                radiusdamage(self.origin, slam_radius, base_dmg, int(500 * slam_mult), self, "MOD_GRENADE_SPLASH");

                crush_zombies = get_round_enemy_array();
                foreach(cz in crush_zombies)
                {
                    if(isDefined(cz) && isAlive(cz) && distance2d(cz.origin, self.origin) <= 48 && abs(cz.origin[2] - self.origin[2]) <= 60)
                    {
                        cz dodamage(cz.health + 5000, self.origin, self, self, "MOD_CRUSH");
                    }
                }

                self playsound("zmb_phdflop_explo");
                earthquake(0.45, 0.6, self.origin, 650);
                self playrumbleonentity("damage_heavy");

                if(isDefined(level._effect["exo_slam_explosion"]))
                    playfx(level._effect["exo_slam_explosion"], self.origin);
                else if(isDefined(level._effect["divetonuke_groundhit"]))
                    playfx(level._effect["divetonuke_groundhit"], self.origin);
                else
                    playfx(loadfx("explosions/fx_default_explosion"), self.origin);

                wait 0.2;
                self.exo_slam_active = false;
                self.is_slamming = false;
            }
        }
        wait_network_frame();
    }
}

monitor_exo_boost()
{
    self endon("disconnect");
    self notify("boostMonitor");
    self endon("boostMonitor");
    
    while(1)
    {
        while(self.exo_boost >= 100) wait_network_frame();
        wait 3;
        while(self.exo_boost < 100) { self.exo_boost = self.exo_boost + 5; wait 0.25; }
    }
}

land()
{
    self endon("disconnect");
    while(!self isonground()) wait_network_frame();
    self.is_flying_jetpack = 0;
}

monitor_exo_slide()
{
    self endon("disconnect");
    self endon("death");
    level endon("end_game");
    self notify("monitor_exo_slide_singleton");
    self endon("monitor_exo_slide_singleton");

    prev_stance = self getstance();

    while(is_true(self.has_jetpack))
    {
        wait 0.05;
        if(!is_true(self.has_jetpack))
            break;

        cur_stance = self getstance();

        // Player must be on the ground, not downed, and not already sliding
        if(self isonground() && !is_true(self.is_sliding) && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            vel = self getvelocity();
            speed_2d = length((vel[0], vel[1], 0));
            is_running = (self issprinting() || (self sprintbuttonpressed() && speed_2d > 200));

            stance_pressed = self stancebuttonpressed() || self buttonpressed("BUTTON_B");
            stance_to_crouch = (prev_stance == "stand" && cur_stance == "crouch");

            if(is_running && (stance_pressed || stance_to_crouch) && cur_stance != "prone")
            {
                cur_time = GetTime();
                if(!isDefined(self.last_slide_time) || (cur_time - self.last_slide_time >= 250))
                {
                    self thread do_exo_slide();
                }
            }
        }

        prev_stance = cur_stance;
    }
}

do_exo_slide()
{
    self endon("disconnect");
    self endon("death");
    level endon("end_game");

    self.is_sliding = true;
    self.last_slide_time = GetTime();

    // Lock player stance in crouch for the duration of the slide
    self setstance("crouch");

    angles = self getplayerangles();
    forward_dir = anglestoforward((0, angles[1], 0));
    vel = self getvelocity();
    vel_2d = (vel[0], vel[1], 0);

    if(length(vel_2d) > 80)
        slide_dir = vectornormalize(vel_2d);
    else
        slide_dir = forward_dir;

    self playrumbleonentity("slide_rumble");
    self playsound("zmb_plane_fire_whoosh");
    self playsound("fly_step_run_dirt");

    playfx(loadfx("bio/player/fx_footstep_dust"), self.origin);

    steps = 20;
    initial_speed = 570;
    final_speed = 220;

    for(i = 0; i < steps; i++)
    {
        if(!self isonground() || !is_true(self.has_jetpack) || self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
            break;

        // Cancel slide immediately if player drops to prone
        if(self getstance() == "prone")
            break;

        // Cancel slide by jumping
        if(i > 1 && self jumpbuttonpressed())
        {
            self setstance("stand");
            cur_v = self getvelocity();
            self setvelocity((cur_v[0], cur_v[1], 260));
            break;
        }

        // Cancel slide by pressing sprint / run button
        if(i > 1 && (self sprintbuttonpressed() || self issprinting()))
        {
            self setstance("stand");
            break;
        }

        if(self getstance() == "stand")
            self setstance("crouch");

        frac = i / (steps * 1.0);
        cur_speed = initial_speed - (initial_speed - final_speed) * frac;

        cur_z = self getvelocity()[2];
        self setvelocity((slide_dir[0] * cur_speed, slide_dir[1] * cur_speed, cur_z));

        // Damage zombies in the direct path of the slide
        if(i % 3 == 0)
        {
            zombies = get_round_enemy_array();
            foreach(z in zombies)
            {
                if(isDefined(z) && isAlive(z) && distance2d(self.origin, z.origin) <= 45 && abs(self.origin[2] - z.origin[2]) <= 40)
                {
                    z dodamage(100, self.origin, self, self, "MOD_IMPACT");
                }
            }
        }

        wait 0.05;
    }

    self.is_sliding = false;
}

point_crusher_multiplier(player, zombie_team, player_points)
{
    if(isDefined(player.multi_pointcrusher_counter) && player.multi_pointcrusher_counter > 0)
    {
        player_points *= player.multi_pointcrusher_counter;
        player maps\mp\zombies\_zm_score::add_to_player_score(player_points);
        player.pers["score"] = player.score;
    }
}

monitor_muscle_milk()
{
    self endon("disconnect");
    self endon("death");

    while(self.has_muscle_milk)
    {
        if(!self hasPerk("specialty_quickrevive")) { self.has_muscle_milk = false; break; }
        wait 0.1;
    }
}

// called from custom_zombie_damage_multiplier when a melee attack connects;
// the effect and the shock wave center on the zombie that was hit
muscle_milk_attack(zombie, hit_origin)
{
    self.muscle_milk_cooldown = true;

    if(isDefined(zombie))
        playfxontag(level._effect["poltergeist"], zombie, "J_SpineUpper");
    else
        playfx(level._effect["poltergeist"], self.origin);
    self playsound("zmb_turbine_explo");

    center = self.origin;
    if(isDefined(hit_origin))
        center = hit_origin;

    zombies = getAiArray(level.zombie_team);
    foreach(z in zombies)
    {
        if(distance(center, z.origin) < 150) z doDamage(z.health + 777, z.origin, self);
    }

    self thread muscle_milk_cooldown_timer();
}

muscle_milk_cooldown_timer()
{
    wait 15;
    if(self.has_muscle_milk) self iprintln("^2Muscle Milk Ready!");
    self.muscle_milk_cooldown = false;
}

custom_zombie_damage_multiplier(mod, hit_location, hit_origin, player, amount)
{
    // Fighter's Fizz kill detection (backup)
    if (isdefined(player) && isplayer(player) && (is_true(player.fighters_fizz_active) || (player maps\mp\zombies\_zm_laststand::player_is_in_laststand() && is_true(player.has_fighters_fizz))))
    {
        if (amount >= self.health || !isAlive(self))
        {
            player notify("fighters_fizz_kill");
        }
    }
    return false;
}

ethereal_razor_cleave(primary_zombie, hit_origin, cleave_damage, melee_weapon)
{
    self endon("disconnect");

    if(!isDefined(melee_weapon))
        melee_weapon = "knife_zm";

    center = self.origin;
    if(isDefined(primary_zombie) && isAlive(primary_zombie))
        center = primary_zombie.origin;
    else if(isDefined(hit_origin) && distanceSquared(self.origin, hit_origin) < 250000)
        center = hit_origin;

    cleave_radius = 80;
    cleave_radius_sq = cleave_radius * cleave_radius;
    zombies = getAiArray(level.zombie_team);
    if(!isDefined(zombies))
        return;

    self.ethereal_razor_in_cleave = true;
    level.ethereal_razor_in_cleave = true;
    for(i = 0; i < zombies.size; i++)
    {
        z = zombies[i];
        if(!isDefined(z) || !isAlive(z))
            continue;
        if(isDefined(primary_zombie) && z == primary_zombie)
            continue;
        if(isDefined(z.is_inert) && z.is_inert)
            continue;

        if(distancesquared(center, z.origin) <= cleave_radius_sq)
        {
            z dodamage(cleave_damage, z.origin, self, self, "none", "MOD_MELEE", 0, melee_weapon);
        }
    }
    self.ethereal_razor_in_cleave = false;
    level.ethereal_razor_in_cleave = false;
}

dam_a_nade_round_watcher()
{
    self endon("disconnect");
    for(;;)
    {
        level waittill("end_of_round");
        if(is_true(self.has_dam_a_nade))
        {
            lethal = self maps\mp\zombies\_zm_utility::get_player_lethal_grenade();
            if(isDefined(lethal) && lethal != "" && self hasweapon(lethal))
            {
                self setweaponammoclip(lethal, 5);
            }
            tactical = self maps\mp\zombies\_zm_utility::get_player_tactical_grenade();
            if(isDefined(tactical) && tactical != "" && self hasweapon(tactical))
            {
                cur_tactical = self getweaponammoclip(tactical);
                if(cur_tactical < 4)
                    self setweaponammoclip(tactical, cur_tactical + 1);
            }
        }
    }
}

monitor_player_weapons()
{
    self endon("disconnect");
    for(;;)
    {
        if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand() && !is_true(self.is_purchasing) && !is_true(self.afterlife) && !isDefined(self.e_whos_who_corpse))
        {
            cur_weap = self getcurrentweapon();
            if(isDefined(cur_weap) && cur_weap != "none" && !maps\mp\zombies\_zm_utility::is_zombie_perk_bottle(cur_weap))
            {
                self.fighters_fizz_saved_active_weapon = cur_weap;
            }
            primaries = self getweaponslistprimaries();
            if(isDefined(primaries) && primaries.size > 0)
            {
                self.fighters_fizz_saved_weapons = primaries;
            }

            if(is_true(self.has_fighters_fizz))
            {
                self.fighters_fizz_saved_perks = [];
                perk_list = array("specialty_armorvest", "specialty_fastreload", "specialty_longersprint", "specialty_rof", "specialty_quickrevive", "specialty_additionalprimaryweapon", "specialty_deadshot", "specialty_flakjacket", "specialty_scavenger", "specialty_grenadepullback");
                foreach(p in perk_list)
                {
                    if(self hasPerk(p))
                        self.fighters_fizz_saved_perks[self.fighters_fizz_saved_perks.size] = p;
                }
                self.fighters_fizz_saved_multi_jugg = self.multi_juggernog_counter;
                self.fighters_fizz_saved_multi_speedcola = self.multi_speedcola_counter;
                self.fighters_fizz_saved_multi_staminup = self.multi_staminup_counter;
                self.fighters_fizz_saved_multi_mule = self.multi_mule_kick_counter;
                self.fighters_fizz_saved_weapon_limit = self.weapon_limit_counter;
                self.fighters_fizz_saved_punchcola_lvl = self.punchcola_damage_level;
                self.fighters_fizz_saved_doubletap1_lvl = self.doubletap_1_level;
                self.fighters_fizz_saved_has_winters = self.has_winters_wail;
                self.fighters_fizz_saved_has_muscle = self.has_muscle_milk;
                self.fighters_fizz_saved_has_vulture = self.has_vulture;
                self.fighters_fizz_saved_has_jetpack = self.has_jetpack;
                self.fighters_fizz_saved_has_cashback = self.has_cashback;
                self.fighters_fizz_saved_cashback_lvl = self.cashback_level;
                self.fighters_fizz_saved_has_repairman = self.has_repairman;
                self.fighters_fizz_saved_repairman_lvl = self.repairman_level;
                self.fighters_fizz_saved_has_ethereal = self.has_ethereal_razor;
                self.fighters_fizz_saved_ethereal_lvl = self.ethereal_razor_level;
                self.fighters_fizz_saved_has_dam_a_nade = self.has_dam_a_nade;
                self.fighters_fizz_saved_dam_a_nade_lvl = self.dam_a_nade_level;
                self.fighters_fizz_saved_has_whos_who = self.has_whos_who;
                self.fighters_fizz_saved_multi_pointcrusher = self.multi_pointcrusher_counter;
                self.fighters_fizz_saved_point_multiplier = self.point_multiplier;
                self.fighters_fizz_saved_pointcrusher_price = self.pointcrusher_price;
                self.fighters_fizz_saved_has_bandolier = self.has_bandolier_bandit;
                self.fighters_fizz_saved_bandolier_lvl = self.bandolier_bandit_level;
                self.fighters_fizz_saved_bandolier_price = self.bandolier_bandit_price;
                self.fighters_fizz_saved_bandolier_stash = self.bandolier_stash;
                self.fighters_fizz_saved_has_blood_bullets = self.has_blood_bullets;
                self.fighters_fizz_saved_has_nitrogen = self.has_nitrogen_cooled;
                self.fighters_fizz_saved_has_vigor_rush = self.has_vigor_rush;
            }
        }
        wait 0.25;
    }
}

fighters_fizz_watcher()
{
    self endon("disconnect");
    for(;;)
    {
        self waittill("player_downed");

        if(isDefined(self.e_whos_who_corpse) || is_true(self.whos_who_finishing))
            continue;

        if(!is_true(self.has_fighters_fizz) && !is_true(self.fighters_fizz_active))
            continue;

        self.fighters_fizz_active = true;
        if(self hasPerk("specialty_quickrevive") && !is_true(self.fighters_fizz_had_quickrevive))
        {
            self.fighters_fizz_had_quickrevive = true;
            self.fighters_fizz_saved_lives = self.lives;
            self.lives = 0;
        }
        self thread fighters_fizz_active_laststand();
    }
}

fighters_fizz_active_laststand()
{
    self endon("disconnect");
    self endon("death");

    level.no_end_game_check = 1;

    wait 0.1;

    self enableweaponcycling();

    // Restore saved primary weapons into player's inventory
    if(isDefined(self.fighters_fizz_saved_weapons) && self.fighters_fizz_saved_weapons.size > 0)
    {
        foreach(w in self.fighters_fizz_saved_weapons)
        {
            if(!self hasweapon(w))
            {
                self giveweapon(w);
            }
            clip = self getweaponammoclip(w);
            stock = self getweaponammostock(w);
            if(clip == 0 && stock == 0)
            {
                self setweaponammoclip(w, weaponclipsize(w));
            }
        }
    }

    if(isDefined(self.fighters_fizz_saved_active_weapon) && self hasweapon(self.fighters_fizz_saved_active_weapon))
    {
        self switchtoweaponimmediate(self.fighters_fizz_saved_active_weapon);
    }
    else if(isDefined(self.fighters_fizz_saved_weapons) && self.fighters_fizz_saved_weapons.size > 0)
    {
        self switchtoweaponimmediate(self.fighters_fizz_saved_weapons[0]);
    }

    wait 0.05;
    self enableweaponcycling();
    if(isDefined(self.fighters_fizz_saved_active_weapon) && self hasweapon(self.fighters_fizz_saved_active_weapon))
    {
        self switchtoweaponimmediate(self.fighters_fizz_saved_active_weapon);
    }

    self iprintlnbold("^3[FIGHTER'S FIZZ ACTIVATED!]^7");
    self iprintlnbold("^2Kill a zombie to self-revive!");
    self iprintln("^3[Fighter's Fizz]^7 Press ^2[{+melee}]^7, ^2[{+activate}]^7, or ^2[{+breath_sprint}]^7 to cycle guns");

    self thread fighters_fizz_downed_hud();
    self thread fighters_fizz_weapon_cycle_watcher();
    self thread fighters_fizz_listen_weapon_change();
    self thread fighters_fizz_bleedout_timer();

    outcome = self waittill_any_return("fighters_fizz_kill", "fighters_fizz_bleedout", "player_revived");
    self notify("fighters_fizz_ended");
    level.no_end_game_check = undefined;
    self.whos_who_finishing = false;
    self.e_whos_who_corpse = undefined;

    if(outcome == "fighters_fizz_kill")
    {
        self.fighters_fizz_active = false;
        self.has_fighters_fizz = false;

        had_qr = is_true(self.fighters_fizz_had_quickrevive);
        saved_lives = self.fighters_fizz_saved_lives;
        self.fighters_fizz_had_quickrevive = false;

        if(isDefined(saved_lives))
        {
            self.lives = saved_lives;
        }
        else if(flag("solo_game") && had_qr && (!isDefined(self.lives) || self.lives <= 0))
        {
            self.lives = 1;
        }

        self iprintlnbold("^2Fighter's Fizz Activated! Self-Revived!");
        self playsound("zmb_perks_packa_ready");

        self maps\mp\zombies\_zm_laststand::auto_revive(self);
        self thread fighters_fizz_restore_perks(had_qr, saved_lives);
    }
    else if(outcome == "fighters_fizz_bleedout")
    {
        self.fighters_fizz_active = false;
        self.has_fighters_fizz = false;

        if(is_true(self.fighters_fizz_had_quickrevive))
        {
            self.fighters_fizz_had_quickrevive = false;
            self iprintlnbold("^3Quick Revive Activated! (Last Resort)");
            if(isDefined(self.fighters_fizz_saved_lives))
            {
                self.lives = max(0, self.fighters_fizz_saved_lives - 1);
            }
            self maps\mp\zombies\_zm_laststand::auto_revive(self);
        }
        else
        {
            players = get_players();
            any_alive = false;
            foreach(p in players)
            {
                if(p != self && isAlive(p) && !p maps\mp\zombies\_zm_laststand::player_is_in_laststand() && p.sessionstate != "spectator")
                    any_alive = true;
            }

            if(!any_alive)
            {
                level notify("pre_end_game");
                wait_network_frame();
                level notify("end_game");
            }
            else
            {
                self maps\mp\zombies\_zm_laststand::bleed_out();
            }
        }
    }
    else
    {
        // Teammate revived player
        self.fighters_fizz_active = false;
        had_qr = is_true(self.fighters_fizz_had_quickrevive);
        saved_lives = self.fighters_fizz_saved_lives;
        self.fighters_fizz_had_quickrevive = false;
        self thread fighters_fizz_restore_perks(had_qr, saved_lives);
    }
}

fighters_fizz_weapon_cycle_watcher()
{
    self endon("disconnect");
    self endon("death");
    self endon("fighters_fizz_ended");

    weapons = self.fighters_fizz_saved_weapons;
    if(!isDefined(weapons) || weapons.size <= 1)
        return;

    self.fighters_fizz_weapon_idx = 0;
    active = self getcurrentweapon();
    for(i = 0; i < weapons.size; i++)
    {
        if(weapons[i] == active)
        {
            self.fighters_fizz_weapon_idx = i;
            break;
        }
    }

    self thread fighters_fizz_listen_weapon_change();

    while(is_true(self.fighters_fizz_active))
    {
        btn_pressed = false;
        if(self meleeButtonPressed() || self useButtonPressed() || self sprintButtonPressed())
        {
            btn_pressed = true;
        }

        if(btn_pressed)
        {
            self.fighters_fizz_weapon_idx = (self.fighters_fizz_weapon_idx + 1) % weapons.size;
            next_weap = weapons[self.fighters_fizz_weapon_idx];
            if(self hasWeapon(next_weap))
            {
                self enableweaponcycling();
                self switchtoweaponimmediate(next_weap);
            }

            while(self meleeButtonPressed() || self useButtonPressed() || self sprintButtonPressed())
            {
                wait 0.05;
            }
        }
        wait 0.05;
    }
}

fighters_fizz_listen_weapon_change()
{
    self endon("disconnect");
    self endon("death");
    self endon("fighters_fizz_ended");

    weapons = self.fighters_fizz_saved_weapons;
    if(!isDefined(weapons) || weapons.size <= 1)
        return;

    while(is_true(self.fighters_fizz_active))
    {
        self waittill("weapon_change", new_weap);
        if(isDefined(new_weap) && new_weap != "none")
        {
            for(i = 0; i < weapons.size; i++)
            {
                if(weapons[i] == new_weap)
                {
                    self.fighters_fizz_weapon_idx = i;
                    break;
                }
            }
        }
    }
}

fighters_fizz_bleedout_timer()
{
    self endon("disconnect");
    self endon("death");
    self endon("fighters_fizz_ended");

    self thread fighters_fizz_listen_game_bleedout();

    if(is_true(self.fighters_fizz_had_quickrevive))
        bleedout_time = 30.0;
    else
    {
        bleedout_time = getdvarfloat("player_lastStandBleedoutTime");
        if(!isDefined(bleedout_time) || bleedout_time <= 0)
            bleedout_time = 45.0;
    }

    wait max(1.0, bleedout_time - 0.5);
    self notify("fighters_fizz_bleedout");
}

fighters_fizz_listen_game_bleedout()
{
    self endon("disconnect");
    self endon("death");
    self endon("fighters_fizz_ended");
    self waittill("bled_out");
    self notify("fighters_fizz_bleedout");
}

fighters_fizz_downed_hud()
{
    self endon("disconnect");
    self endon("death");
    self endon("fighters_fizz_ended");

    if(is_true(self.fighters_fizz_had_quickrevive))
        bleedout_time = 30.0;
    else
    {
        bleedout_time = getdvarfloat("player_lastStandBleedoutTime");
        if(!isDefined(bleedout_time) || bleedout_time <= 0)
            bleedout_time = 45.0;
    }

    time_left = int(bleedout_time);

    hud_title = newclienthudelem(self);
    hud_title.alignx = "center";
    hud_title.aligny = "middle";
    hud_title.horzalign = "center";
    hud_title.vertalign = "middle";
    hud_title.font = "default";
    hud_title.y = 120;
    hud_title.foreground = true;
    hud_title.fontscale = 1.4;
    hud_title.alpha = 1;
    hud_title.color = (1, 0.85, 0.2);

    hud_sub = newclienthudelem(self);
    hud_sub.alignx = "center";
    hud_sub.aligny = "middle";
    hud_sub.horzalign = "center";
    hud_sub.vertalign = "middle";
    hud_sub.font = "default";
    hud_sub.y = 142;
    hud_sub.foreground = true;
    hud_sub.fontscale = 1.2;
    hud_sub.alpha = 1;
    hud_sub.color = (1, 1, 1);

    self thread fighters_fizz_hud_cleanup(hud_title, hud_sub);

    while(is_true(self.fighters_fizz_active) && time_left > 0)
    {
        hud_title settext("^3[FIGHTER'S FIZZ ACTIVE]^7 Kill to revive! Time: ^1" + time_left + "^7s");
        hud_sub settext("^2Press [{+melee}], [{+activate}], or [{+breath_sprint}] to switch guns");

        wait 1.0;
        time_left--;
    }

    if(isDefined(hud_title))
        hud_title destroy();
    if(isDefined(hud_sub))
        hud_sub destroy();
}

fighters_fizz_hud_cleanup(hud_title, hud_sub)
{
    self waittill_any("disconnect", "death", "fighters_fizz_ended");
    if(isDefined(hud_title))
        hud_title destroy();
    if(isDefined(hud_sub))
        hud_sub destroy();
}

fighters_fizz_zombie_death()
{
    if(isDefined(self.attacker) && isPlayer(self.attacker) && (is_true(self.attacker.fighters_fizz_active) || (self.attacker maps\mp\zombies\_zm_laststand::player_is_in_laststand() && is_true(self.attacker.has_fighters_fizz))))
    {
        self.attacker notify("fighters_fizz_kill");
    }
}

fighters_fizz_restore_perks(had_qr, saved_lives)
{
    self endon("disconnect");

    if(!isDefined(had_qr))
        had_qr = is_true(self.fighters_fizz_had_quickrevive);
    if(!isDefined(saved_lives))
        saved_lives = self.fighters_fizz_saved_lives;

    self.fighters_fizz_had_quickrevive = false;

    while(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        wait 0.1;
    wait 0.2;

    // Handle Quick Revive restoration without incrementing solo_lives_given or making the machine fly away!
    if(is_true(had_qr))
    {
        saved_solo_lives = level.solo_lives_given;
        if(!self hasPerk("specialty_quickrevive"))
        {
            level.solo_game_free_player_quickrevive = 1;
            self maps\mp\zombies\_zm_perks::give_perk("specialty_quickrevive");
            if(isDefined(saved_solo_lives))
                level.solo_lives_given = saved_solo_lives;
            if(isDefined(level.solo_lives_given) && level.solo_lives_given < 3 && flag_exists("solo_revive") && flag("solo_revive"))
                flag_clear("solo_revive");
        }
    }

    if(isDefined(self.fighters_fizz_saved_perks))
    {
        foreach(perk in self.fighters_fizz_saved_perks)
        {
            if(perk == "specialty_quickrevive")
                continue;
            if(!self hasPerk(perk))
            {
                self maps\mp\zombies\_zm_perks::give_perk(perk);
            }
        }
    }

    if(flag("solo_game"))
    {
        if(isDefined(saved_lives) && saved_lives > 0)
            self.lives = saved_lives;
        else if(isDefined(self.fighters_fizz_saved_lives) && self.fighters_fizz_saved_lives > 0)
            self.lives = self.fighters_fizz_saved_lives;
        else
            self.lives = 1;
    }
    self.fighters_fizz_saved_lives = undefined;

    if(isDefined(self.fighters_fizz_saved_multi_jugg) && self.fighters_fizz_saved_multi_jugg > 1)
    {
        self.multi_juggernog_counter = self.fighters_fizz_saved_multi_jugg;
        self.jugger_price = self.starting_jugger_price * self.multi_juggernog_counter;
        self.maxhealth = 250 + ((self.multi_juggernog_counter - 1) * 150);
        self.health = self.maxhealth;
    }

    if(isDefined(self.fighters_fizz_saved_multi_speedcola))
        self.multi_speedcola_counter = self.fighters_fizz_saved_multi_speedcola;

    if(isDefined(self.fighters_fizz_saved_multi_staminup))
        self.multi_staminup_counter = self.fighters_fizz_saved_multi_staminup;

    if(isDefined(self.fighters_fizz_saved_multi_mule))
    {
        self.multi_mule_kick_counter = self.fighters_fizz_saved_multi_mule;
        self.mule_kick_price = self.starting_mule_kick_price * self.multi_mule_kick_counter;
    }

    if(isDefined(self.fighters_fizz_saved_weapon_limit))
        self.weapon_limit_counter = self.fighters_fizz_saved_weapon_limit;

    if(isDefined(self.fighters_fizz_saved_punchcola_lvl))
    {
        self.punchcola_damage_level = self.fighters_fizz_saved_punchcola_lvl;
        self.multi_punchcola_counter = self.punchcola_damage_level;
        self.punchcola_price = self.starting_punchcola_price * self.multi_punchcola_counter;
    }

    if(isDefined(self.fighters_fizz_saved_doubletap1_lvl))
        self.doubletap_1_level = self.fighters_fizz_saved_doubletap1_lvl;

    if(is_true(self.fighters_fizz_saved_has_winters))
    {
        self.has_winters_wail = true;
        self.winters_wail_charges = 3;
    }

    if(is_true(self.fighters_fizz_saved_has_muscle))
        self.has_muscle_milk = true;

    if(is_true(self.fighters_fizz_saved_has_vulture))
        self.has_vulture = true;

    if(is_true(self.fighters_fizz_saved_has_jetpack))
    {
        self.has_jetpack = true;
        self thread init_jetpack();
    }

    if(is_true(self.fighters_fizz_saved_has_cashback))
    {
        self.has_cashback = true;
        self.cashback_level = self.fighters_fizz_saved_cashback_lvl;
    }

    if(is_true(self.fighters_fizz_saved_has_repairman))
    {
        self.has_repairman = true;
        self.repairman_level = self.fighters_fizz_saved_repairman_lvl;
        self.repairman_price = 2000 * (self.repairman_level + 1);
    }

    if(is_true(self.fighters_fizz_saved_has_ethereal))
    {
        self.has_ethereal_razor = true;
        self.ethereal_razor_level = self.fighters_fizz_saved_ethereal_lvl;
        self.ethereal_razor_price = 3000 * (self.ethereal_razor_level + 1);
    }

    if(is_true(self.fighters_fizz_saved_has_dam_a_nade))
    {
        self.has_dam_a_nade = true;
        self.dam_a_nade_level = self.fighters_fizz_saved_dam_a_nade_lvl;
        self.dam_a_nade_price = 2500 * (self.dam_a_nade_level + 1);
    }

    // Who's Who is spent on down, never restored by Fighter's Fizz so it can be bought again
    self.has_whos_who = false;
    self.can_buy_whos_who = true;

    if(isDefined(self.fighters_fizz_saved_multi_pointcrusher) && self.fighters_fizz_saved_multi_pointcrusher > 0)
    {
        self.multi_pointcrusher_counter = self.fighters_fizz_saved_multi_pointcrusher;
        self.point_multiplier = self.fighters_fizz_saved_point_multiplier;
        if(isDefined(self.fighters_fizz_saved_pointcrusher_price))
            self.pointcrusher_price = self.fighters_fizz_saved_pointcrusher_price;
    }

    if(is_true(self.fighters_fizz_saved_has_bandolier))
    {
        self.has_bandolier_bandit = true;
        self.bandolier_bandit_level = self.fighters_fizz_saved_bandolier_lvl;
        self.bandolier_bandit_price = self.fighters_fizz_saved_bandolier_price;
        if(isDefined(self.fighters_fizz_saved_bandolier_stash))
            self.bandolier_stash = self.fighters_fizz_saved_bandolier_stash;
        self thread bandolier_bandit_think();
    }

    if(is_true(self.fighters_fizz_saved_has_blood_bullets))
    {
        self.has_blood_bullets = true;
        self thread blood_bullets_think();
    }

    if(is_true(self.fighters_fizz_saved_has_nitrogen))
    {
        self.has_nitrogen_cooled = true;
        self thread nitrogen_cooled_think();
    }

    if(is_true(self.fighters_fizz_saved_has_vigor_rush))
    {
        self.has_vigor_rush = true;
    }

    self.has_fighters_fizz = false;
    self.can_buy_fighters_fizz = true;
}

monitor_spent_points()
{
    level endon("end_game");
    for(;;)
    {
        level waittill("spent_points", player, points);
        if(isDefined(player) && isPlayer(player) && is_true(player.has_cashback) && isDefined(points) && points > 0)
        {
            rate = 0.20;
            if(isDefined(player.cashback_level) && player.cashback_level >= 2)
                rate = 0.30;

            refund = int(points * rate);
            if(refund > 0)
            {
                player maps\mp\zombies\_zm_score::add_to_player_score(refund);
                player.pers["score"] = player.score;
            }
        }
    }
}

repairman_barrier_override(player)
{
    if(!isDefined(player) || !isPlayer(player) || !is_true(player.has_repairman))
        return false;

    cost = 10;
    pts_multiplier = 4 * player.repairman_level;

    while(true)
    {
        players = get_players();
        if(maps\mp\zombies\_zm_blockers::player_fails_blocker_repair_trigger_preamble(player, players, self.unitrigger_stub.trigger, 0))
            break;

        if(isDefined(self.zbarrier))
        {
            chunk = maps\mp\zombies\_zm_utility::get_random_destroyed_chunk(self, self.barrier_chunks);
            if(isDefined(chunk))
            {
                if(!isDefined(self.zbarrier.repairman_chunks))
                    self.zbarrier.repairman_chunks = [];
                self.zbarrier.repairman_chunks[chunk] = player;
            }
            self thread maps\mp\zombies\_zm_blockers::replace_chunk(self, chunk, true, isdefined(player.pers_upgrades_awarded["board"]) && player.pers_upgrades_awarded["board"]);
        }
        else
        {
            chunk = maps\mp\zombies\_zm_utility::get_random_destroyed_chunk(self, self.barrier_chunks);
            if(isDefined(chunk.script_parameter) && (chunk.script_parameters == "repair_board" || chunk.script_parameters == "barricade_vents"))
            {
                if(isDefined(chunk.unbroken_section))
                {
                    chunk show();
                    chunk solid();
                    chunk.unbroken_section maps\mp\zombies\_zm_utility::self_delete();
                }
            }
            else
                chunk show();

            if(!isDefined(chunk.material) || chunk.material != "rock")
                chunk maps\mp\zombies\_zm_utility::play_sound_on_ent("rebuild_barrier_piece");
            playsoundatposition("zmb_cha_ching", (0, 0, 0));

            self thread maps\mp\zombies\_zm_blockers::replace_chunk(self, chunk, true, isdefined(player.pers_upgrades_awarded["board"]) && player.pers_upgrades_awarded["board"]);
        }

        if(isDefined(self.clip))
        {
            self.clip maps\mp\zombies\_zm_utility::enable_trigger();
            self.clip disconnectpaths();
        }
        else
            maps\mp\zombies\_zm_blockers::blocker_disconnect_paths(self.neg_start, self.neg_end);

        wait 0.15;

        if(!maps\mp\zombies\_zm_utility::is_player_valid(player))
            break;

        player maps\mp\zombies\_zm_blockers::handle_post_board_repair_rewards(cost, self);
        bonus_points = cost * (pts_multiplier - 1);
        if(bonus_points > 0)
        {
            player maps\mp\zombies\_zm_score::add_to_player_score(bonus_points);
            player.pers["score"] = player.score;
        }

        if(maps\mp\zombies\_zm_utility::all_chunks_intact(self, self.barrier_chunks))
        {
            self notify("all_boards_repaired");
            return true;
        }

        if(maps\mp\zombies\_zm_utility::no_valid_repairable_boards(self, self.barrier_chunks))
        {
            self notify("no valid boards");
            return true;
        }
    }

    return true;
}

repairman_tear_chunk_callback(node, chunk)
{
    if(isDefined(level.original_zbarrier_tear_override) && level.original_zbarrier_tear_override != ::repairman_tear_chunk_callback)
    {
        self thread [[ level.original_zbarrier_tear_override ]](node, chunk);
    }

    if(!isDefined(node) || !isDefined(node.zbarrier))
        return;

    zbar = node.zbarrier;
    if(!isDefined(zbar.repairman_chunks) || !isDefined(zbar.repairman_chunks[chunk]))
        return;

    builder = zbar.repairman_chunks[chunk];
    zbar.repairman_chunks[chunk] = undefined;

    explo_origin = zbar.origin;
    if(isDefined(self) && isAlive(self))
        explo_origin = self.origin;

    playfx(loadfx("explosions/fx_default_explosion"), explo_origin);
    playsoundatposition("zmb_phdflop_explo", explo_origin);

    base_damage = 1200;
    if(isDefined(builder) && isPlayer(builder) && isDefined(builder.repairman_level) && builder.repairman_level > 0)
    {
        base_damage = 1200 * builder.repairman_level;
    }

    dam_mult = 1.0;
    if(isDefined(builder) && isPlayer(builder) && is_true(builder.has_dam_a_nade) && isDefined(builder.dam_a_nade_level) && builder.dam_a_nade_level > 0)
    {
        dam_mult = 2.0 * builder.dam_a_nade_level;
    }
    final_explo_damage = int(base_damage * dam_mult);

    attacker = builder;
    if(!isDefined(attacker) || !isPlayer(attacker))
        attacker = self;

    if(isDefined(self) && isAlive(self))
    {
        self dodamage(final_explo_damage, explo_origin, attacker, attacker, "none", "MOD_EXPLOSIVE");
        if(isAlive(self) && (!is_true(self.has_legs) || is_true(self.gibbed) || self.health <= 300))
        {
            self dodamage(self.health + 500, self.origin, attacker, attacker, "none", "MOD_EXPLOSIVE");
        }
    }

    zombies = getAiArray(level.zombie_team);
    if(isDefined(zombies))
    {
        for(i = 0; i < zombies.size; i++)
        {
            z = zombies[i];
            if(!isDefined(z) || !isAlive(z))
                continue;
            if(isDefined(self) && z == self)
                continue;

            if(distanceSquared(explo_origin, z.origin) <= 32400) // 180 units radius
            {
                z dodamage(final_explo_damage, explo_origin, attacker, attacker, "none", "MOD_EXPLOSIVE");
                if(isAlive(z) && (!is_true(z.has_legs) || is_true(z.gibbed) || z.health <= 300))
                {
                    z dodamage(z.health + 500, z.origin, attacker, attacker, "none", "MOD_EXPLOSIVE");
                }
            }
        }
    }
}
