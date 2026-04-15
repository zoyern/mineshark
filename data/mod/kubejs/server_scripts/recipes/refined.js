ServerEvents.recipes((event) => {
  // REMOVALS
  event.remove({
    output: [
      'refinedstorage:controller',
      'refinedstorage:raw_basic_processor',
      'refinedstorage:raw_improved_processor',
      'refinedstorage:raw_advanced_processor',
      'refinedstorage:basic_processor',
      'refinedstorage:improved_processor',
      'refinedstorage:advanced_processor',
      'refinedstorage:quartz_enriched_copper',
      'refinedstorage:quartz_enriched_iron',
      'refinedstorage:construction_core',
      'refinedstorage:destruction_core',
    ],
  });

  // RECIPES
  event.shaped('refinedstorage:destruction_core', ['L', 'N'], {
    L: 'alexscaves:scarlet_neodymium_ingot',
    N: '#c:plates/iron',
  });
  event.shaped('refinedstorage:construction_core', ['L', 'N'], {
    L: 'alexscaves:azure_neodymium_ingot',
    N: '#c:plates/iron',
  });
  event.recipes.create.mixing('refinedstorage:quartz_enriched_iron', ['minecraft:iron_ingot', 'minecraft:quartz']).heated().id('mix_quartz_enriched_iron');
  event.recipes.create.mixing('refinedstorage:quartz_enriched_copper', ['minecraft:copper_ingot', 'minecraft:quartz']).heated().id('mix_quartz_enriched_copper');
  event.recipes.create.mechanical_crafting('refinedstorage:controller', [' DDD ', 'DSLSD', 'DOCED', 'DSLSD', ' DDD '], {
    D: 'create:sturdy_sheet',
    S: 'eternal_starlight:golem_steel_ingot',
    C: 'refinedstorage:machine_casing',
    L: 'alexscaves:fissile_core',
    O: 'refinedstorage:construction_core',
    E: 'refinedstorage:destruction_core',
  });
  event.recipes.create
    .sequenced_assembly('refinedstorage:basic_processor', 'create:precision_mechanism', [
      event.recipes.create.deploying('refinedstorage:raw_basic_processor', ['refinedstorage:raw_basic_processor', 'create:iron_sheet']),
      event.recipes.create.deploying('refinedstorage:raw_basic_processor', ['refinedstorage:raw_basic_processor', 'refinedstorage:silicon']),
      event.recipes.create.deploying('refinedstorage:raw_basic_processor', ['refinedstorage:raw_basic_processor', 'create:sturdy_sheet']),
      event.recipes.create.pressing('refinedstorage:raw_basic_processor', 'refinedstorage:raw_basic_processor'),
    ])
    .transitionalItem('refinedstorage:raw_basic_processor')
    .loops(1)
    .id('seq_basic_processor');
  event.recipes.create
    .sequenced_assembly('refinedstorage:improved_processor', 'create:precision_mechanism', [
      event.recipes.create.deploying('refinedstorage:raw_improved_processor', ['refinedstorage:raw_improved_processor', 'create:golden_sheet']),
      event.recipes.create.deploying('refinedstorage:raw_improved_processor', ['refinedstorage:raw_improved_processor', 'refinedstorage:silicon']),
      event.recipes.create.deploying('refinedstorage:raw_improved_processor', ['refinedstorage:raw_improved_processor', 'create:sturdy_sheet']),
      event.recipes.create.pressing('refinedstorage:raw_improved_processor', 'refinedstorage:raw_improved_processor'),
    ])
    .transitionalItem('refinedstorage:raw_improved_processor')
    .loops(1)
    .id('seq_improved_processor');
  event.recipes.create
    .sequenced_assembly('refinedstorage:advanced_processor', 'create:precision_mechanism', [
      event.recipes.create.deploying('refinedstorage:raw_advanced_processor', ['refinedstorage:raw_advanced_processor', 'minecraft:diamond']),
      event.recipes.create.deploying('refinedstorage:raw_advanced_processor', ['refinedstorage:raw_advanced_processor', 'refinedstorage:silicon']),
      event.recipes.create.deploying('refinedstorage:raw_advanced_processor', ['refinedstorage:raw_advanced_processor', 'create:sturdy_sheet']),
      event.recipes.create.pressing('refinedstorage:raw_advanced_processor', 'refinedstorage:raw_advanced_processor'),
    ])
    .transitionalItem('refinedstorage:raw_advanced_processor')
    .loops(1)
    .id('seq_advanced_processor');
});
