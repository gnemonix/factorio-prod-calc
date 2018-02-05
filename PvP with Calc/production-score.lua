local function get_total_production_counts(production_statistics)
  local produced = production_statistics.input_counts
  local consumed = production_statistics.output_counts
  for name, value in pairs (consumed) do
    if produced[name] then
      produced[name] = produced[name] - value
    else
      produced[name] = -value
    end
  end
  return produced
end

local function get_raw_resources()
  local raw_resources = {}
  local entities = game.entity_prototypes
  for name, entity_prototype in pairs (entities) do
    if entity_prototype.resource_category then
      if entity_prototype.mineable_properties then
        for k, product in pairs (entity_prototype.mineable_properties.products) do
          raw_resources[product.name] = true
        end
      end
    end
  end
  return raw_resources
end

local function get_product_list()
  local product_list = {}
  local recipes = game.recipe_prototypes
  for recipe_name, recipe_prototype in pairs (recipes) do
    local ingredients = recipe_prototype.ingredients
    local products = recipe_prototype.products
    for k, product in pairs (products) do
      if not product_list[product.name] then
        product_list[product.name] = {}
      end
      local recipe_ingredients = {}
      local product_amount = product.amount or product.probability * ((product.amount_min + product.amount_max) / 2) or 1
      if product_amount > 0 then
        for j, ingredient in pairs (ingredients) do
          recipe_ingredients[ingredient.name] = ((ingredient.amount)/#products) / product_amount
        end
        recipe_ingredients.energy = recipe_prototype.energy
        table.insert(product_list[product.name], recipe_ingredients)
      end
    end
  end
  local items = game.item_prototypes
  local entities = game.entity_prototypes
  --[[Now we do some tricky stuff for space science type items]]
  local rocket_silos = {}
  for k, entity in pairs (entities) do
    if entity.type == "rocket-silo" and entity.fixed_recipe then
      local recipe = recipes[entity.fixed_recipe]
      if not recipe then return end
      local required_parts = entity.rocket_parts_required
      local list = {}
      for k, product in pairs (recipe.products) do
        local product_amount = product.amount or product.probability * ((product.amount_min + product.amount_max) / 2) or 1
        if product_amount > 0 then
          product_amount = product_amount * required_parts
          list[product.name] = product_amount
        end
      end
      list["energy"] = recipe.energy
      table.insert(rocket_silos, list)
    end
  end
  for k, item in pairs (items) do
    local launch_products = item.rocket_launch_products
    if launch_products then
      for k, launch_product in pairs (launch_products) do
        product_list[launch_product.name] = product_list[launch_product.name] or {}
        launch_product_amount = launch_product.amount or launch_product.probability * ((launch_product.amount_min + launch_product.amount_max) / 2) or 1
        if launch_product_amount > 0 then
          for k, silo_products in pairs (rocket_silos) do
            local this_silo = {}
            for product_name, product_count in pairs (silo_products) do
              this_silo[product_name] = product_count / launch_product_amount
            end
            this_silo[item.name] = 1 / launch_product.amount
            table.insert(product_list[launch_product.name], this_silo)
          end
        end
      end
    end
  end
  return product_list
end

local default_param = function()
  return
  {
    ingredient_exponent = 1.025, --[[The exponent for increase in value for each additional ingredient formula exponent^#ingredients-2]]
    raw_resource_price = 2.5, --[[If a raw resource isn't given a price, it uses this price]]
    seed_prices = {
      ["iron-ore"] = 3.1,
      ["copper-ore"] = 3.6,
      ["coal"] = 3,
      ["stone"] = 2.4,
      ["crude-oil"] = 0.2,
      ["water"] = 1/1000,
      ["steam"] = 1/1000,
      ["raw-wood"] = 3.2,
      ["raw-fish"] = 100,
      ["energy"] = 1,
      ["uranium-ore"] = 8.2
    },
    resource_ignore = {} --[[This is used to account for mods removing resource generation, in which case we want the item price to be calculated from recipes.]]
  }
end

production_score = {}

production_score.get_default_param = function()
  return default_param()
end

production_score.generate_price_list = function(param)
  local param = param or default_param()
  local price_list = param.seed_prices or {}

  local resource_list = get_raw_resources()
  for name, k in pairs (resource_list) do
    if not price_list[name] then
      price_list[name] = param.raw_resource_price
    end
  end

  for k, name in pairs (param.resource_ignore or {}) do
    price_list[name] = nil
  end

  local product_list = get_product_list()
  local ln = math.log
  local count_table = function(table)
    local count = 0
    for k, v in pairs (table) do
      count = count + 1
    end
    return count
  end
  local get_price_recursive
  get_price_recursive = function(name, current_loop)
    local price = price_list[name]
    if price then return price end
    price = 0
    if current_loop[name] then return 0 end
    current_loop[name] = true
    local entry = product_list[name]
    if not entry then return 0 end
    local recipe_cost
    for k, recipe in pairs (entry) do
      local this_recipe_cost = 0
      for ingredient_name, cost in pairs (recipe) do
        if ingredient_name ~= "energy" then
          local addition = get_price_recursive(ingredient_name, current_loop)
          if addition and addition > 0 then
            this_recipe_cost = this_recipe_cost + (addition * cost)
          else
            this_recipe_cost = 0
            break
          end
        end
      end
      if this_recipe_cost > 0 then
        this_recipe_cost = (this_recipe_cost * ((param.ingredient_exponent or 1) ^ (count_table(recipe)-2))) + ((ln(recipe.energy + 1) * (this_recipe_cost ^ 0.5)))
        if recipe_cost then
          recipe_cost = math.min(recipe_cost, this_recipe_cost)
        else
          recipe_cost = this_recipe_cost
        end
      end
    end
    if recipe_cost then
      price = recipe_cost
      price_list[name] = price
      return price
    end
  end
  local items = game.item_prototypes
  for name, item in pairs (items) do
    local current_loop = {}
    get_price_recursive(name, current_loop)
  end
  local fluids = game.fluid_prototypes
  for name, fluid in pairs (fluids) do
    local current_loop = {}
    get_price_recursive(name, current_loop)
  end
  return price_list
end

production_score.get_production_scores = function(price_list)
  local price_list = price_list or production_score.generate_price_list()
  local scores = {}
  for k, force in pairs (game.forces) do
    local score = 0
    for name, value in pairs (get_total_production_counts(force.item_production_statistics)) do
      local price = price_list[name]
      if price then
        score = score + (price * value)
      end
    end
    for name, value in pairs (get_total_production_counts(force.fluid_production_statistics)) do
      local price = price_list[name]
      if price then
        score = score + (price * value)
      end
    end
    scores[force.name] = math.floor(score)
  end
  return scores
end

production_score.on_rocket_launched = function(event)
  --In current base game (0.16.17), when a rocket is launched, the rocket parts + satellite are not added to consumed statistics, so this event handler will add them to the statistics.
  local silo = event.rocket_silo
  if not (silo and silo.valid) then return end
  local item_stats = silo.force.item_production_statistics
  local fluid_stats = silo.force.fluid_production_statistics
  local recipe = silo.get_recipe()
  local required_parts = silo.prototype.rocket_parts_required
  for k, product in pairs (recipe.products) do
    local amount = (product.amount or ((product.amount_min + product.amount_max) / 2) * product.probability) * required_parts
    if product.type == "item" then
      item_stats.on_flow(product.name, - amount)
    elseif product.type == "fluid" then
      fluid_stats.on_flow(product.name, - amount)
    end
  end
  local rocket = event.rocket
  if not (rocket and rocket.valid) then return end
  for k = 1, 10 do
    local inventory = rocket.get_inventory(k)
    if not inventory then break end
    for name, count in pairs (inventory.get_contents()) do
      item_stats.on_flow(name, - count)
    end
  end
end

production_score.on_player_crafted_item = function(event)
  --In current base game (0.16.17), when a player crafts and item, the recipes ingredients are not added to the consmed statistics, so this event handler will add them to the statistics.
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end
  local recipe = event.recipe
  if not (recipe and recipe.valid) then return end
  local item_stats = player.force.item_production_statistics
  for k, ingredient in pairs (recipe.ingredients) do
    if ingredient.type == "item" then
      item_stats.on_flow(ingredient.name, - ingredient.amount)
    end
  end
end

return production_score