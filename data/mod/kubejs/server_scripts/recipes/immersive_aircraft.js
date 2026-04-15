ServerEvents.recipes((event) => {
  // REMOVALS
  event.remove({
    output: [
      'immersive_aircraft:gyrodyne',
      'immersive_aircraft:airship',
      'immersive_aircraft:biplane',
      'immersive_aircraft:warship',
      'immersive_aircraft:propeller',
      'immersive_aircraft:enhanced_propeller',
      'immersive_aircraft:steel_boiler',
      'immersive_aircraft:gyroscope',
      'immersive_aircraft:hull',
      'immersive_aircraft:sail',
      'immersive_aircraft:engine',
      'immersive_aircraft:quadrocopter',
      'immersive_aircraft:nether_engine',
      'immersive_aircraft:eco_engine',
      'immersive_aircraft:industrial_gears',
      'immersive_aircraft:biplane',
    ],
  });
  // RECIPES
  event.shaped(Item.of('immersive_aircraft:hull'), ['   ', 'ABA', 'ABA'], {
    B: 'minecraft:iron_ingot',
    A: 'create:andesite_casing',
  });
  event.shaped(Item.of('immersive_aircraft:sail'), ['   ', 'AAA', 'AAA'], {
    A: 'create:white_sail',
  });
  event.shaped(Item.of('immersive_aircraft:propeller'), [' A ', 'ABA', ' A '], {
    A: 'create:iron_sheet',
    B: 'create:propeller',
  });
  event.shaped(Item.of('immersive_aircraft:boiler'), [' A ', ' B ', ' C '], {
    A: 'create:steam_engine',
    C: 'create:blaze_burner',
    B: 'create:fluid_tank',
  });
  event.shaped(Item.of('immersive_aircraft:engine'), ['   ', 'ABA', 'CDC'], {
    A: 'create:brass_sheet',
    C: 'create:sturdy_sheet',
    B: 'create:precision_mechanism',
    D: 'immersive_aircraft:boiler',
  });
  event.shaped(Item.of('immersive_aircraft:gyrodyne'), [' A ', 'BCB', 'DED'], {
    D: 'immersive_aircraft:hull',
    B: 'immersive_aircraft:sail',
    C: 'create:precision_mechanism',
    E: '#create:seats',
    A: 'immersive_aircraft:propeller',
  });
  event.shaped(Item.of('immersive_aircraft:quadrocopter'), ['ABA', ' C ', 'ADA'], {
    C: '#minecraft:wool',
    B: 'create:andesite_casing',
    D: 'immersive_aircraft:boiler',
    A: 'create:propeller',
  });
  event.shaped(Item.of('immersive_aircraft:enhanced_propeller'), [' A ', 'ABA', ' A '], {
    A: 'create:brass_sheet',
    B: 'create:brass_ingot',
  });
  event.shaped(Item.of('immersive_aircraft:steel_boiler'), ['ABA', 'ABA', 'ABA'], {
    A: 'create:iron_sheet',
    B: 'create:fluid_tank',
  });
  event.shaped(Item.of('immersive_aircraft:gyroscope'), [' AA', ' B ', '   '], {
    A: 'create:electron_tube',
    B: 'minecraft:compass',
  });
  event.shaped(Item.of('immersive_aircraft:hull_reinforcement'), ['   ', 'ABA', '   '], {
    B: 'immersive_aircraft:hull',
    A: 'create:iron_sheet',
  });
  event.shaped(Item.of('immersive_aircraft:improved_landing_gear'), ['AB ', 'C  ', '   '], {
    B: 'minecraft:iron_ingot',
    A: 'create:iron_sheet',
    C: 'create:belt_connector',
  });
  event.shaped(Item.of('immersive_aircraft:sturdy_pipes'), ['AAB', 'BBB', 'BAA'], {
    B: 'create:fluid_pipe',
    A: 'create:iron_sheet',
  });
  event.shaped(Item.of('immersive_aircraft:nether_engine'), ['   ', 'ABA', 'CDC'], {
    C: 'create:sturdy_sheet',
    A: 'create:iron_sheet',
    D: 'immersive_aircraft:boiler',
    B: 'minecraft:lava_bucket',
  });
  event.shaped(Item.of('immersive_aircraft:eco_engine'), ['   ', 'ABA', 'CDC'], {
    A: 'create:iron_sheet',
    C: 'create:copper_sheet',
    D: 'immersive_aircraft:boiler',
    B: 'minecraft:water_bucket',
  });
  event.shaped(Item.of('immersive_aircraft:industrial_gears'), [' AB', 'C A', 'BC '], {
    C: 'create:iron_sheet',
    A: 'create:copper_sheet',
    B: 'create:cogwheel',
  });
  event.recipes.create.mechanical_crafting('immersive_aircraft:airship', ['SSSSS', ' W W ', ' HREP', ' HHH ', '     '], {
    S: 'immersive_aircraft:sail',
    W: 'minecraft:string',
    H: 'immersive_aircraft:hull',
    R: 'create:red_seat',
    E: 'immersive_aircraft:engine',
    P: 'immersive_aircraft:propeller',
  });
  event.recipes.create
    .mechanical_crafting('immersive_aircraft:biplane', ['   S ', 'S  S ', 'HHREP', 'S  S ', '   S '], {
      S: 'immersive_aircraft:sail',
      H: 'immersive_aircraft:hull',
      R: 'create:red_seat',
      E: 'immersive_aircraft:engine',
      P: 'immersive_aircraft:propeller',
    })
    .id('biplane_crafting');
  event.recipes.create.mechanical_crafting('immersive_aircraft:warship', ['SSSSS', 'SSSSS', 'GEGEG', 'HRHRH', 'HHHHH'], {
    S: 'immersive_aircraft:sail',
    H: 'immersive_aircraft:hull',
    R: 'create:red_seat',
    E: 'immersive_aircraft:engine',
    G: 'immersive_aircraft:industrial_gears',
  });
});
