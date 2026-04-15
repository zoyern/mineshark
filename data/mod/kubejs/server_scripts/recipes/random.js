ServerEvents.recipes((event) => {
  event.remove({
    id: [
      'transmog:transmogrification_table',
      'regions_unexplored:light_gray_painted_planks',
      'regions_unexplored:cyan_painted_planks',
      'regions_unexplored:purple_painted_planks',
      'regions_unexplored:blue_painted_planks',
      'regions_unexplored:brown_painted_planks',
      'regions_unexplored:green_painted_planks',
      'regions_unexplored:red_painted_planks',
      'regions_unexplored:black_painted_planks',
    ],
  });
  event.replaceInput(
    { id: 'furniture:blueprints' }, // Arg 1: the filter
    'minecraft:light_blue_dye', // Arg 2: the item to replace
    'minecraft:blue_dye', // Arg 3: the item to replace it with
    // Note: tagged fluid ingredients do not work on Fabric, but tagged items do.
  );
  event.replaceInput(
    { input: 'minecraft:crafting_table' }, // Arg 1: the filter
    'minecraft:crafting_table', // Arg 2: the item to replace
    '#c:player_workstations/crafting_tables', // Arg 3: the item to replace it with
    // Note: tagged fluid ingredients do not work on Fabric, but tagged items do.
  );

  event.recipes.create.item_application('transmog:transmogrification_table', ['minecraft:amethyst_block', 'royalvariations:royal_ender_pearl']);
});
