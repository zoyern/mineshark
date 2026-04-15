// ITEMS
ServerEvents.tags('item', (event) => {
  event.add('neoadv:opac_whitelist', ['#waystones:waystones']);
  event.add('mynethersdelight:boiled_egg_candidate', '#c:eggs');
  event.add('c:eggs', ['reanimal:kiwi_egg', 'reanimal:ostrich_egg', 'reanimal:pigeon_egg', 'reanimal:vulture_egg', 'reanimal:penguin_egg', 'reanimal:crocodile_egg']);
  event.add('nomoremagicchoices:skill_weapon', '#minecraft:enchantable/weapon');
  event.add('mt:dragonsteel', [
    'iceandfire:dragonsteel_ice_sword',
    'iceandfire:dragonsteel_ice_shovel',
    'iceandfire:dragonsteel_ice_hoe',
    'iceandfire:dragonsteel_ice_axe',
    'iceandfire:dragonsteel_fire_sword',
    'iceandfire:dragonsteel_fire_shovel',
    'iceandfire:dragonsteel_fire_pickaxe',
    'iceandfire:dragonsteel_fire_hoe',
    'iceandfire:dragonsteel_fire_axe',
    'iceandfire:dragonsteel_ice_pickaxe',
    'iceandfire:dragonsteel_lightning_axe',
    'iceandfire:dragonsteel_lightning_hoe',
    'iceandfire:dragonsteel_lightning_pickaxe',
    'iceandfire:dragonsteel_lightning_shovel',
    'iceandfire:dragonsteel_lightning_sword',
  ]);
});

// BLOCKS
ServerEvents.tags('block', (event) => {
  event.add('irons_spellbooks:spectral_hammer_mineable', ['#eternal_starlight:base_stone_starlight', '#iceandfire:charred_blocks']);
  event.add('neoadv:opac_whitelist', ['#waystones:waystones', 'create:contraption_controls']);
});

// EMNTITIES
ServerEvents.tags('entity_type', (event) => {
  event.add('neoadv:cataclysm_entities', ['#cataclysm:team_scylla', '#cataclysm:team_the_harbinger', '#cataclysm:team_ender_guardian', '#cataclysm:team_the_harbinger', '#cataclysm:team_ignis', '#cataclysm:team_maledictus', '#cataclysm:team_monstrosity', '#cataclysm:team_ancient_remnant']);
  event.add('neoadv:summons', [
    'ars_nouveau:summon_wolf',
    'ars_nouveau:summoned_skeleton',
    'irons_spellbooks:summmoned_sword',
    'irons_spellbooks:summmoned_rapier',
    'irons_spellbooks:summmoned_vex',
    'irons_spellbooks:summmoned_claymore',
    'irons_spellbooks:summmoned_sword',
    'irons_spellbooks:summmoned_polar_bear',
    'irons_spellbooks:summmoned_sword',
  ]);
  event.add('neoadv:scaling_blacklist', [
    '#neoadv:summons',
    '#neoadv:cataclysm_entities',
    'irons_spellbooks:fire_boss',
    'cataclysm:netherite_monstrosity',
    'eternal_starlight:starlight_golem',
    'eternal_starlight:lunar_monstrosity',
    'bosses_of_mass_destruction:lich',
    'bosses_of_mass_destruction:obsidilith',
    'irons_spellbooks:dead_king',
    'discerning_the_eldritch:ascended_one',
    'ars_nouveau:wilden_boss',
    'born_in_chaos_v1:maggot',
    'born_in_chaos_v1:corpse_fly',
    'discerning_the_eldritch:gaoler',
  ]);
  event.add('iceandfire:immune_to_gorgon_stone', []);
  event.add('ars_nouveau:drygmy_blacklist', [
    'ars_nouveau:wilden_boss',
    '#neoadv:cataclysm_entities',
    'eternal_starlight:starlight_golem',
    'eternal_starlight:lunar_monstrosity',
    'bosses_of_mass_destruction:lich',
    'bosses_of_mass_destruction:obsidilith',
    'irons_spellbooks:dead_king',
    'irons_spellbooks:citadel_keeper',
    'irons_spellbooks:fire_boss',
    'irons_spellbooks:pyromancer',
    'irons_spellbooks:archevoker',
    'irons_spellbooks:cryomancer',
    'irons_spellbooks:priest',
    'irons_spellbooks:apothecarist',
    'irons_spellbooks:necromancer',
    'golemsoverhaul:netherite_golem',
    'discerning_the_eldritch:ascended_one',
  ]);
  event.add('ars_nouveau:drygmy_blacklist', ['#ars_nouveau:jar_blacklist']);
});
