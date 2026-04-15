ServerEvents.recipes((event) => {
  event.replaceInput(
    { mod: 'farmersdelight' }, // Arg 1: the filter
    'minecraft:egg', // Arg 2: the item to replace
    '#c:eggs', // Arg 3: the item to replace it with
    // Note: tagged fluid ingredients do not work on Fabric, but tagged items do.
  );
  event.replaceInput(
    { mod: 'mynethersdelight' }, // Arg 1: the filter
    'minecraft:egg', // Arg 2: the item to replace
    '#c:eggs', // Arg 3: the item to replace it with
    // Note: tagged fluid ingredients do not work on Fabric, but tagged items do.
  );
});
