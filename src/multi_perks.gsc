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
#include maps\mp\zombies\_zm_afterlife;

init()
{
    level._effect["poltergeist"] = loadfx( "misc/fx_zombie_couch_effect" );
    // Winter's Wail: white mist cloud + blue glow, both ship with every map
    level._effect["winters_wail"] = loadfx( "weapon/thunder_gun/fx_thundergun_smoke_cloud" );
    level._effect["winters_wail_eyes"] = loadfx( "maps/zombie/fx_zombie_eye_returned_blue" );
    
    level.multi_mule_kick_machine = getEnt("vending_additionalprimaryweapon", "targetname");
    level.multi_juggernog_machine = getEnt("vending_jugg", "targetname");
    level.multi_staminup_machine = getEnt("vending_marathon", "targetname");
    level.multi_speedcola_machine = getEnt("vending_sleight", "targetname");
    level.multi_quickrevive_machine = getEnt("vending_revive", "targetname");
    level.multi_doubletap_machine = getEnt("vending_doubletap", "targetname");
    
    level.get_player_weapon_limit = ::custom_get_player_weapon_limit;
    level._game_module_point_adjustment = ::point_crusher_multiplier;
    level thread register_zombie_damage_callback( ::custom_zombie_damage_multiplier );
    level thread register_zombie_death_event_callback( ::vulture_zombie_death );

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
    trigger setcursorhint("HINT_ACTIVATE");
    trigger sethintstring(hint_text);
    trigger setvisibletoall();
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

    self.hasJetpackOnce = false;
    self.jetpack_price = 4000;
    self.has_jetpack = false;
    self.original_staminup_machine_location = undefined;
    self.current_staminup_trigger = undefined;
    self.last_staminup_purchase_time = 0;
    self.can_buy_jetpack = false;

    self.hasPointCrusherOnce = false;
    self.multi_pointcrusher_counter = 0;
    self.starting_pointcrusher_price = 4000;
    self.pointcrusher_price = self.starting_pointcrusher_price;
    self.point_multiplier = 1;
    self.original_speedcola_machine_location = undefined;
    self.current_speedcola_trigger = undefined;
    self.last_speedcola_purchase_time = 0;
    self.can_buy_pointcrusher = false;

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
    self.can_buy_winters_wail = false;

    self.machine_is_in_use = false;
    self.is_purchasing = false;
    self.num_perks = 0;
    self.perk_reminder = 0;
    self.perk_count = 0;
    self.perks_given = 0;
}

check_proximity_to_machines()
{
    self endon("disconnect");
    self endon("death");
    
    while(true)
    {
        if(self hasPerk("specialty_additionalprimaryweapon") && !self.is_purchasing)
            self check_perk_proximity("mule_kick", self.original_mule_kick_machine_location, self.last_mule_kick_purchase_time);
        
        if(self hasPerk("specialty_armorvest") && !self.is_purchasing)
            self check_perk_proximity("jugger", self.original_jugger_machine_location, self.last_jugger_purchase_time);
        
        if(self hasPerk("specialty_longersprint") && !self.is_purchasing)
            self check_perk_proximity("staminup", self.original_staminup_machine_location, self.last_staminup_purchase_time, self.has_jetpack);
        else if(getdvar("mapname") == "zm_prison" && !self hasPerk("specialty_longersprint") && !self.is_purchasing)
            self check_perk_proximity("staminup_buy", level.prison_staminup_origin, 0);
        
        if(self hasPerk("specialty_fastreload") && !self.is_purchasing)
            self check_perk_proximity("speedcola", self.original_speedcola_machine_location, self.last_speedcola_purchase_time);
        
        if(self hasPerk("specialty_quickrevive") && !self.is_purchasing)
            self check_perk_proximity("quickrevive", self.original_quickrevive_machine_location, self.last_quickrevive_purchase_time, self.has_muscle_milk && self.has_whos_who);

        if(self hasPerk("specialty_rof") && !self.is_purchasing)
            self check_perk_proximity("doubletap", self.original_doubletap_machine_location, self.last_doubletap_purchase_time);
        else if(getdvar("mapname") == "zm_tomb" && !self hasPerk("specialty_rof") && !self.is_purchasing)
            self check_perk_proximity("doubletap_buy", level.tomb_doubletap_origin, 0);
        
        wait 0.2;
    }
}

check_perk_proximity(perk_type, machine_location, last_purchase_time, additional_condition)
{
    if(!isDefined(machine_location))
        return;
        
    if(distance(self.origin, machine_location) <= 70 && !self.machine_is_in_use && (!isDefined(additional_condition) || !additional_condition))
    {
        if(GetTime() - last_purchase_time >= 200)
        {
            if(perk_type == "mule_kick")
                self thread show_multi_mule_kick_prompt();
            else if(perk_type == "jugger")
                self thread show_multi_juggernog_prompt();
            else if(perk_type == "staminup")
                self thread show_staminup_jetpack_prompt();
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
                wait 1;
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
                wait 1;
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
    if(!isDefined(self.current_mule_kick_trigger))
        self.current_mule_kick_trigger = create_trigger_radius("Hold ^3[{+activate}]^7 for Multi-Mule Kick [Cost: " + self.mule_kick_price + "]", self.original_mule_kick_machine_location + (0, 0, 30));
    self show_perk_prompt_core(self.current_mule_kick_trigger, "specialty_additionalprimaryweapon", self.mule_kick_price, self.original_mule_kick_machine_location, ::process_multi_mule_kick_purchase, false);
    if(isDefined(self.current_mule_kick_trigger))
    {
        self.current_mule_kick_trigger delete();
        self.current_mule_kick_trigger = undefined;
    }
}

show_multi_juggernog_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_armorvest") || self.is_purchasing)
        return;
    if(!self.can_buy_multi_jugger && (self.has_vulture || !self.can_buy_vulture))
        return;
    if(!isDefined(self.current_jugger_trigger))
    {
        hint = "";
        if(self.can_buy_multi_jugger)
            hint = "Hold ^3[{+activate}]^7 for Multi-Juggernog [Cost: " + self.jugger_price + "]";
        if(!self.has_vulture && self.can_buy_vulture)
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Press ^3[{+melee}]^7 for Vulture Aid [Cost: " + self.vulture_price + "]";
        }
        if(hint != "")
            self.current_jugger_trigger = create_trigger_radius(hint, self.original_jugger_machine_location + (0, 0, 30));
    }
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
    while(self isTouching(trigger_var) && self hasPerk("specialty_armorvest") && !self.machine_is_in_use && !self.is_purchasing)
    {
        if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
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
            else if(!self.has_vulture && self meleeButtonPressed() && self.score >= self.vulture_price)
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
                || (self meleeButtonPressed() && !self.has_vulture && self.score < self.vulture_price))
            {
                if(distance(self.origin, self.original_jugger_machine_location) <= 70)
                {
                    self playsound("evt_perk_deny");
                    self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                    wait 1;
                }
            }
        }
        wait 0.1;
    }
}

show_speedcola_pointcrusher_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_fastreload") || self.is_purchasing || !self.can_buy_pointcrusher)
        return;
    if(!isDefined(self.current_speedcola_trigger))
        self.current_speedcola_trigger = create_trigger_radius("Hold ^3[{+activate}]^7 for Point Crusher [Cost: " + self.pointcrusher_price + "]", self.original_speedcola_machine_location + (0, 0, 30));
    self show_perk_prompt_core(self.current_speedcola_trigger, "specialty_fastreload", self.pointcrusher_price, self.original_speedcola_machine_location, ::process_speedcola_pointcrusher_purchase, false);
    if(isDefined(self.current_speedcola_trigger))
    {
        self.current_speedcola_trigger delete();
        self.current_speedcola_trigger = undefined;
    }
}

show_staminup_jetpack_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_longersprint") || self.is_purchasing || self.has_jetpack || !self.can_buy_jetpack)
        return;
    if(!isDefined(self.current_staminup_trigger))
        self.current_staminup_trigger = create_trigger_radius("Hold ^3[{+activate}]^7 for Exo Suit [Cost: " + self.jetpack_price + "]", self.original_staminup_machine_location + (0, 0, 30));
    self show_perk_prompt_core(self.current_staminup_trigger, "specialty_longersprint", self.jetpack_price, self.original_staminup_machine_location, ::process_staminup_jetpack_purchase, self.has_jetpack);
    if(isDefined(self.current_staminup_trigger))
    {
        self.current_staminup_trigger delete();
        self.current_staminup_trigger = undefined;
    }
}

show_muscle_milk_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_quickrevive") || self.is_purchasing)
        return;
    if((self.has_muscle_milk || !self.can_buy_muscle_milk) && (self.has_whos_who || !self.can_buy_whos_who))
        return;
    if(!isDefined(self.current_quickrevive_trigger))
    {
        whos_who_available = !self.has_whos_who && self.can_buy_whos_who && !isDefined(self.e_whos_who_corpse);
        hint = "";
        if(!self.has_muscle_milk && self.can_buy_muscle_milk)
        {
            if(whos_who_available)
                hint = "^3[{+activate}]^7 Muscle Milk [" + self.muscle_milk_price + "] ^1|^7 ^3[{+melee}]^7 Who's Who [" + self.whos_who_price + "]";
            else
                hint = "Hold ^3[{+activate}]^7 for Muscle Milk [Cost: " + self.muscle_milk_price + "]";
        }
        else if(whos_who_available)
            hint = "Press ^3[{+melee}]^7 for Who's Who [Cost: " + self.whos_who_price + "]";
        if(hint != "")
            self.current_quickrevive_trigger = create_trigger_radius(hint, self.original_quickrevive_machine_location + (0, 0, 30));
    }
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
    while(self isTouching(trigger_var) && self hasPerk("specialty_quickrevive") && !self.machine_is_in_use && !self.is_purchasing)
    {
        if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(!self.has_muscle_milk && self useButtonPressed() && self.score >= self.muscle_milk_price)
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
            else if(!self.has_whos_who && !isDefined(self.e_whos_who_corpse) && self meleeButtonPressed() && self.score >= self.whos_who_price)
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
            else if((self useButtonPressed() && !self.has_muscle_milk && self.score < self.muscle_milk_price)
                || (self meleeButtonPressed() && !self.has_whos_who && self.score < self.whos_who_price))
            {
                if(distance(self.origin, self.original_quickrevive_machine_location) <= 70)
                {
                    self playsound("evt_perk_deny");
                    self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                    wait 1;
                }
            }
        }
        wait 0.1;
    }
}

show_punchcola_prompt()
{
    self endon("disconnect");
    self endon("death");
    if(!self hasPerk("specialty_rof") || self.is_purchasing)
        return;
    if(!self.can_buy_punchcola && (self.has_winters_wail || !self.can_buy_winters_wail))
        return;
    if(!isDefined(self.current_doubletap_trigger))
    {
        hint = "";
        if(self.can_buy_punchcola)
            hint = "Hold ^3[{+activate}]^7 for Punch-a-Cola [Cost: " + self.punchcola_price + "]";
        if(!self.has_winters_wail && self.can_buy_winters_wail)
        {
            if(hint != "")
                hint += " ^1|^7 ";
            hint += "Press ^3[{+melee}]^7 for Winter's Wail [Cost: " + self.winters_wail_price + "]";
        }
        if(hint != "")
            self.current_doubletap_trigger = create_trigger_radius(hint, self.original_doubletap_machine_location + (0, 0, 30));
    }
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
    while(self isTouching(trigger_var) && self hasPerk("specialty_rof") && !self.machine_is_in_use && !self.is_purchasing)
    {
        if(!self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
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
            else if(!self.has_winters_wail && self meleeButtonPressed() && self.score >= self.winters_wail_price)
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
                || (self meleeButtonPressed() && !self.has_winters_wail && self.score < self.winters_wail_price))
            {
                if(distance(self.origin, self.original_doubletap_machine_location) <= 70)
                {
                    self playsound("evt_perk_deny");
                    self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
                    wait 1;
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
    self.buy_doubletap_trigger setcursorhint("HINT_ACTIVATE");
    self.buy_doubletap_trigger sethintstring("Hold ^3[{+activate}]^7 for Double Tap [Cost: 2000]");
    self.buy_doubletap_trigger setvisibletoall();
        
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
    self.buy_staminup_trigger setcursorhint("HINT_ACTIVATE");
    self.buy_staminup_trigger sethintstring("Hold ^3[{+activate}]^7 for Stamin-Up [Cost: 2000]");
    self.buy_staminup_trigger setvisibletoall();
        
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
    if(isDefined(self.attacker) && isPlayer(self.attacker) && self.attacker.has_vulture)
    {
        if(randomint(100) < 30)
            self.attacker thread vulture_drop(self.origin);
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
                self vulture_give_ammo();
            }
            else
            {
                points = randomintrange(10, 50);
                self maps\mp\zombies\_zm_score::add_to_player_score(points);
                self.pers["score"] = self.score;
            }
            break;
        }
        wait 0.15;
    }

    drop delete();
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

    max_ammo = weaponmaxammo(weapon);
    if(max_ammo <= 0)
        return;

    current = self getweaponammostock(weapon);
    if(current >= max_ammo)
    {
        primaries = self getWeaponsListPrimaries();
        found = false;
        if(isDefined(primaries))
        {
            foreach(p_weap in primaries)
            {
                if(p_weap != weapon && !is_offhand_weapon(p_weap) && !is_placeable_mine(p_weap) && !is_equipment(p_weap))
                {
                    p_max = weaponmaxammo(p_weap);
                    p_cur = self getweaponammostock(p_weap);
                    if(p_max > 0 && p_cur < p_max)
                    {
                        weapon = p_weap;
                        max_ammo = p_max;
                        current = p_cur;
                        found = true;
                        break;
                    }
                }
            }
        }
        if(!found)
            return;
    }

    bonus = int(max_ammo * 0.1);
    if(bonus < 1)
        bonus = 1;

    new_stock = current + bonus;
    if(new_stock > max_ammo)
        new_stock = max_ammo;

    self setweaponammostock(weapon, new_stock);
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

        self.ignoreme = inside;

        if(inside)
        {
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

process_staminup_jetpack_purchase()
{
    self process_perk_purchase("specialty_longersprint", self.jetpack_price, self.original_staminup_machine_location, level.staminup_bottle, self.has_jetpack);
    self.has_jetpack = true;
    self.last_staminup_purchase_time = GetTime();
    self iprintln("^2Exo Suit Acquired!\n^3Now you can Boost yourself!\n^1If you Double Jump and Crouch you can cause an explosion!\n^6Hold Aim [{+speed_throw}] while in air to Hover!");
    self thread init_jetpack();
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
    if(flag("solo_game") && self hasPerk("specialty_quickrevive"))
        self.lives = 1;

    self thread whos_who_cleanup_on_shadow_down(corpse);
    corpse thread whos_who_bleed_timer(getdvarfloat(#"player_lastStandBleedoutTime"));
    corpse waittill_any("player_revived", "bleedout_time_over");

    if(isDefined(corpse.bled_out) && corpse.bled_out)
        self whos_who_finish(corpse, false);
    else
        self whos_who_finish(corpse, true);
}

whos_who_finish(corpse, was_revived)
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
    }

    self whos_who_corpse_cleanup(corpse, was_revived);

    // Who's Who is spent (normally already removed when the clone spawned), but
    // perks, weapons and mod upgrades are all kept
    self whos_who_remove_perk();
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

whos_who_cleanup_on_shadow_down(corpse)
{
    self endon("disconnect");

    while(isDefined(self.e_whos_who_corpse) && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        wait 0.1;

    if(!isDefined(self.e_whos_who_corpse))
        return;

    // the player fell again in shadow mode: remove the original body so there
    // are no doubles and let the normal last stand / quick revive flow take over
    self.whos_who_finishing = true;
    self whos_who_corpse_cleanup(corpse, false);
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

    player.whos_who_finishing = true;
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

    while(self.has_winters_wail)
    {
        self waittill("damage", damage, attacker, direction_vec, point, mod);

        // Filter out non-zombie sources: fall damage, self explosives, lava/fire
        if(isDefined(mod) && (mod == "MOD_FALLING" || mod == "MOD_SUICIDE"))
            continue;

        if(!isDefined(attacker))
            continue;

        is_zombie_attacker = false;
        if(isDefined(attacker.is_zombie) && attacker.is_zombie)
            is_zombie_attacker = true;
        else if(isDefined(attacker.team) && attacker.team == level.zombie_team)
            is_zombie_attacker = true;
        else if(isAi(attacker))
            is_zombie_attacker = true;

        if(!is_zombie_attacker)
            continue;

        if(self.winters_wail_charges > 0 && !self.winters_wail_lock
            && self.health < self.maxhealth
            && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            self.winters_wail_lock = true;
            self thread winters_wail_blast();
        }
    }
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

winters_wail_blast()
{
    self.winters_wail_charges--;

    // 3x layered VFX radial burst for exaggerated frost blast
    self thread play_winters_wail_blast_fx();

    earthquake(0.35, 0.8, self.origin, 1000);
    self playsound("evt_ww_appear");
    self iprintln("^3Winter's Wail frost blast! ^7[" + self.winters_wail_charges + "/3]");

    zombies = getAiArray(level.zombie_team);
    foreach(z in zombies)
    {
        if(distance(self.origin, z.origin) < 180)
        {
            z doDamage(100 + level.round_number * 20, z.origin, self);
            z thread winters_wail_freeze();
        }
    }

    wait 5;
    self.winters_wail_lock = false;
}

play_winters_wail_blast_fx()
{
    // Center burst
    playfx(level._effect["winters_wail"], self.origin);
    playfx(level._effect["powerup_grabbed_wave"], self.origin);
    playfx(level._effect["winters_wail_eyes"], self.origin + (0, 0, 30));

    // Radial offsets to expand frost cloud 3x
    offsets = array(
        (40, 0, 10),
        (-40, 0, 10),
        (0, 40, 10),
        (0, -40, 10),
        (28, 28, 15),
        (-28, -28, 15),
        (28, -28, 15),
        (-28, 28, 15)
    );

    foreach(offset in offsets)
    {
        playfx(level._effect["winters_wail"], self.origin + offset);
        playfx(level._effect["winters_wail_eyes"], self.origin + offset);
    }
}

// runs on the zombie: frozen solid first, then thawing (slow), then normal
winters_wail_freeze()
{
    self endon("death");

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
            self.original_mule_kick_machine_location = level.multi_mule_kick_machine.origin;
            self.last_mule_kick_purchase_time = GetTime();
            self.can_buy_multi_mule = false; wait 1; self.can_buy_multi_mule = true;
        }
        
        if(self hasPerk("specialty_armorvest") && !isDefined(self.original_jugger_machine_location))
        {
            self.original_jugger_machine_location = level.multi_juggernog_machine.origin;
            self.last_jugger_purchase_time = GetTime();
            self.can_buy_multi_jugger = false;
            self.can_buy_vulture = false;
            wait 1;
            self.can_buy_multi_jugger = true;
            self.can_buy_vulture = true;
        }
        
        if(self hasPerk("specialty_longersprint") && !isDefined(self.original_staminup_machine_location))
        {
            if (getdvar("mapname") == "zm_prison")
               self.original_staminup_machine_location = level.prison_staminup_origin;
            else
               self.original_staminup_machine_location = level.multi_staminup_machine.origin;

            self.last_staminup_purchase_time = GetTime();
            self.can_buy_jetpack = false; wait 1; self.can_buy_jetpack = true;
        }
        
        if(self hasPerk("specialty_fastreload") && !isDefined(self.original_speedcola_machine_location))
        {
            self.original_speedcola_machine_location = level.multi_speedcola_machine.origin;
            self.last_speedcola_purchase_time = GetTime();
            self.can_buy_pointcrusher = false; wait 1; self.can_buy_pointcrusher = true;
        }
        
        if(self hasPerk("specialty_quickrevive") && !isDefined(self.original_quickrevive_machine_location))
        {
            if (getdvar("mapname") == "zm_tomb") 
            {
               self.original_quickrevive_machine_location = (2355.26, 5033.44, -303.875);
            }
            else
            {
               self.original_quickrevive_machine_location = level.multi_quickrevive_machine.origin;
            }
            self.last_quickrevive_purchase_time = GetTime();
            // raise both flags at the same time: if one becomes true earlier the
            // trigger is created in that window with an incomplete hintstring
            self.can_buy_muscle_milk = false;
            self.can_buy_whos_who = false;
            wait 1;
            self.can_buy_muscle_milk = true;
            self.can_buy_whos_who = true;
        }

        if(self hasPerk("specialty_rof") && !isDefined(self.original_doubletap_machine_location))
        {
            if (getdvar("mapname") == "zm_tomb")
               self.original_doubletap_machine_location = level.tomb_doubletap_origin;
            else
               self.original_doubletap_machine_location = level.multi_doubletap_machine.origin;

            self.last_doubletap_purchase_time = GetTime();
            if(!isDefined(self.punchcola_damage_level)) self.punchcola_damage_level = 1;
            self.can_buy_punchcola = false;
            self.can_buy_winters_wail = false;
            wait 1;
            self.can_buy_punchcola = true;
            self.can_buy_winters_wail = true;
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
        if (!isdefined(level.zombiemode_using_afterlife) || !level.zombiemode_using_afterlife || !is_true(self.afterlife))
        {
            if(!self hasPerk("specialty_additionalprimaryweapon"))
            {
                self.multi_mule_kick_counter = 1;
                self.mule_kick_price = self.starting_mule_kick_price;
                self.original_mule_kick_machine_location = undefined;
                self.last_mule_kick_purchase_time = 0;
                self.weapon_limit_counter = 3;
                if(isDefined(self.current_mule_kick_trigger)) { self.current_mule_kick_trigger delete(); self.current_mule_kick_trigger = undefined; }
            }
            
            if(!self hasPerk("specialty_armorvest"))
            {
                self.multi_juggernog_counter = 1;
                self.jugger_price = self.starting_jugger_price;
                self.has_vulture = false;
                self.can_buy_vulture = false;
                self.original_jugger_machine_location = undefined;
                self.last_jugger_purchase_time = 0;
                if(isDefined(self.current_jugger_trigger)) { self.current_jugger_trigger delete(); self.current_jugger_trigger = undefined; }
            }
            
            if(!self hasPerk("specialty_longersprint"))
            {
                self.has_jetpack = false;
                self.original_staminup_machine_location = undefined;
                self.last_staminup_purchase_time = 0;
                if(isDefined(self.current_staminup_trigger)) { self.current_staminup_trigger delete(); self.current_staminup_trigger = undefined; }
            }
            
            if(!self hasPerk("specialty_fastreload"))
            {
                self.multi_pointcrusher_counter = 0;
                self.pointcrusher_price = self.starting_pointcrusher_price;
                self.point_multiplier = 1;
                self.original_speedcola_machine_location = undefined;
                self.last_speedcola_purchase_time = 0;
                if(isDefined(self.current_speedcola_trigger)) { self.current_speedcola_trigger delete(); self.current_speedcola_trigger = undefined; }
            }
            
            if(!self hasPerk("specialty_quickrevive"))
            {
                self.has_muscle_milk = false;
                self.has_whos_who = false;
                self.can_buy_whos_who = false;
                self.original_quickrevive_machine_location = undefined;
                self.last_quickrevive_purchase_time = 0;
                if(isDefined(self.current_quickrevive_trigger)) { self.current_quickrevive_trigger delete(); self.current_quickrevive_trigger = undefined; }
            }

            if(!self hasPerk("specialty_rof"))
            {
                self.multi_punchcola_counter = 1;
                self.punchcola_price = self.starting_punchcola_price;
                self.punchcola_damage_level = 1;
                self.has_winters_wail = false;
                self.winters_wail_charges = 0;
                self.winters_wail_lock = false;
                self.can_buy_winters_wail = false;
                self.original_doubletap_machine_location = undefined;
                self.last_doubletap_purchase_time = 0;
                if(isDefined(self.current_doubletap_trigger)) { self.current_doubletap_trigger delete(); self.current_doubletap_trigger = undefined; }
            }
        }
        
        wait 0.5;
    }
}

custom_get_player_weapon_limit(player)
{
    weapon_limit = 2;
    if(player hasPerk("specialty_additionalprimaryweapon"))
        weapon_limit = player.weapon_limit_counter;
    else 
    {
        weapons = player getWeaponsListPrimaries();
        if(weapons.size > 2) player takeWeapon(weapons[2]);
    }
    return weapon_limit;
}

init_jetpack()
{
    self endon("disconnect");
    level endon("end_game");
    
    self.sprint_boost = 0; self.jump_boost = 0; self.slam_boost = 0;
    self.exo_boost = 100; self.is_flying_jetpack = 0;
    self.last_boost_time = 0; self.boost_cooldown = false; self.hover_active = false;
    
    self thread monitor_exo_boost();
    self thread handle_jetpack_movement();
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
            
            while(!self isonground())
            {
                if(self.exo_boost >= 20 && self.jump_boost < 1 && self jumpbuttonpressed())
                {
                    self.is_flying_jetpack = 1; self.jump_boost++;
                    earthquake(0.22, 0.9, self.origin, 850);
                    self setvelocity((self getvelocity()[0], self getvelocity()[1], 350));
                    self thread land(); self.exo_boost -= 20; self thread monitor_exo_boost();
                }
                
                if(self.exo_boost >= 20 && self.sprint_boost < 1 && self sprintbuttonpressed())
                {
                    self.is_flying_jetpack = 1; self.sprint_boost++;
                    angles = self getplayerangles(); direction = anglestoforward(angles);
                    current_vel = self getvelocity();
                    boost_vel = (current_vel[0] + direction[0] * 600, current_vel[1] + direction[1] * 600, current_vel[2]);
                    earthquake(0.22, 0.9, self.origin, 850); self setvelocity(boost_vel);
                    self thread land(); self.exo_boost -= 20; self thread monitor_exo_boost();
                }
                
                if(self adsbuttonpressed() && self.exo_boost > 0)
                {
                    current_vel = self getvelocity();
                    if(current_vel[2] < 0)
                    {
                        hover_vel = (current_vel[0] * 0.95, current_vel[1] * 0.95, current_vel[2] * 0.15);
                        self setvelocity(hover_vel); self.exo_boost = max(0, self.exo_boost - 0.5);
                    }
                }
                
                if(self.exo_boost >= 30 && self.slam_boost < 1 && self.jump_boost > 0 && self stancebuttonpressed())
                {
                    self.slam_boost++; self setvelocity((self getvelocity()[0], self getvelocity()[1], -200));
                    self thread land(); self.exo_boost -= 30; self thread monitor_exo_boost();
                }
                
                wait_network_frame();
            }
            
            if(self.slam_boost > 0)
            {
                self enableinvulnerability();
                radiusdamage(self.origin, 200, 3000, 500, self, "MOD_GRENADE_SPLASH");
                self disableinvulnerability();
                self playsound("zmb_phdflop_explo");
                fx = loadfx("explosions/fx_default_explosion"); playfx(fx, self.origin);
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
    // Muscle Milk: fires when the knife/melee attack actually hits a zombie
    if (isdefined(player) && isplayer(player) && mod == "MOD_MELEE" && player.has_muscle_milk && !player.muscle_milk_cooldown && !player.is_purchasing)
        player thread muscle_milk_attack(self, hit_origin);

    if (isdefined(player) && isplayer(player) && player hasPerk("specialty_rof") && isDefined(player.punchcola_damage_level) && player.punchcola_damage_level > 1)
    {  
        multiplier = player.punchcola_damage_level;
        extra_damage = amount * (multiplier - 1.0);  
        if (extra_damage > 0) self dodamage(extra_damage, hit_origin, player, player, hit_location, mod);  
    }  
    return false;
}