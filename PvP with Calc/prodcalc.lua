local mod_gui = require("mod-gui")
require("production-score")
require("util")


prodcalc = {}

prodcalc.on_init = function(event)
  
  local use_mods = false -- set to true if you are using mods, then modify the lists below

  local param = production_score.get_default_param()
  param.seed_prices = add_price_seeds(param.seed_prices, {["used-up-uranium-fuel-cell"] = 30})

  if use_mods then -- currently only configured for an anglebob suite (minus bobs-enemies)
    local mod_seeds = {
      ["angels-ore1"] = 3.1, -- Saphirite
      ["angels-ore2"] = 3.1 * 1.2, -- Jivolite
      ["angels-ore3"] = 3.3, -- Stiratite
      ["angels-ore4"] = 3.3 * 1.2, -- Crotinnium
      ["angels-ore5"] = 3.5, -- Rubyte
      ["angels-ore6"] = 3.5, -- Bobmonium
      ["thermal-water"] = 0.7,
      ["liquid-multi-phase-oil"] = 0.2,
      ["gas-natural-1"] = 0.2,
      ["water-viscous-mud"] = 1/1000,
      ["gas-compressed-air"] = 1/1000,
      ["temperate-tree"] = 10,
      ["swamp-tree"] = 10,
      ["desert-garden"] = 10,
      ["swamp-garden"] = 10,
      ["temperate-garden"] = 10,
      ["bio-plastic"] = 4,
      ["bio-resin"] = 4
    }

    param.seed_prices = add_price_seeds(param.seed_prices, mod_seeds)

    param.resource_ignore = { -- angelbob
      ["iron-ore"] = true,
      ["copper-ore"] = true,
      ["stone"] = true,
      ["crude-oil"] = true,
      ["uranium-ore"] = true
    }
  end
  
  global.price_list = production_score.generate_price_list(param)
  
end

prodcalc.button_press = function (event)
  local gui = event.element
  local player = game.players[event.player_index]
  
  create_calc_gui(player)

  -- local center = player.gui.center
  -- if #center.children_names > 0 then
  --   local frame = get_gui(center, "config_holding_frame")
  --   if frame then frame.destroy() end
  -- end
end

prodcalc.on_gui_click = function(event)
  local gui = event.element
  local player = game.players[event.player_index]
  if not (player and player.valid and gui and gui.valid) then return end

  if gui.name == "calc_export_button" then
    export_spreadsheet(player)
    return
  end
end

prodcalc.on_gui_elem_changed = function(event)
  local gui = event.element
  local player = game.players[event.player_index]
  if not (player and player.valid and gui and gui.valid) then return end
  
  if string.find(gui.parent.name, "recipe_chooser_table") then
    select_recipe(gui, player)
  end

  if string.find(gui.parent.name, "calc_table") then
    select_item(gui)
  end

end

prodcalc.on_gui_checked_state_changed = function(event)
  local gui = event.element
  local player = game.players[event.player_index]
  if not (player and player.valid and gui and gui.valid) then return end
  
  local parent = gui.parent
  
  if string.find(parent.name, "calc_table") then
    local chooser_type = "item"
    
    if gui.state == true then
      chooser_type = "fluid"
    end
  
  create_item_chooser_table(gui.parent, chooser_type, gui.state)  	
  end
end

prodcalc.on_gui_text_changed = function(event)
  local gui = event.element
  local player = game.players[event.player_index]
  if not (player and player.valid and gui and gui.valid) then return end

  if gui.name == "machine_count_textfield" then
    local text = gui.text
    local num = tonumber(text)

    if text == "" then num = 0 end
    if not num then num = 0 end

    prodcalc["machine_count"] = num

    local slider = get_gui(mod_gui.get_frame_flow(player), "machine_count_slider")
    slider.slider_value = num

    set_total(player)
  end

  if gui.name == "craft_speed_textfield" then
    local text = gui.text
    local num = tonumber(text)

    if text == "" then num = 0 end
    if not num then num = 0 end

    prodcalc["crafting_speed"] = num

    set_total(player)
  end
end

prodcalc.on_gui_value_changed = function(event)
  local gui = event.element
  local player = game.players[event.player_index]
  if not (player and player.valid and gui and gui.valid) then return end

  if gui.name == "machine_count_slider" then
    local num = round_number(gui.slider_value, 0)

    prodcalc["machine_count"] = num

    local input = get_gui(mod_gui.get_frame_flow(player), "machine_count_textfield")
    input.text = num

    set_total(player)
  end
end

function create_calc_gui(player)
  local gui = mod_gui.get_frame_flow(player)
  --local gui = player.gui.center
  
  if gui.calc_flow then
    gui.calc_flow.style.visible = not gui.calc_flow.style.visible
    return
  end

-- MAIN CALCULATOR GUI

  local flow_main = gui.add{
    type = "flow",
    name = "calc_flow",
    direction = "vertical"
  }
  flow_main.style.visible = true

  local frame_main = flow_main.add{
    type = "frame",
    name = "calc_gui",
    caption = {"calc-gui"},
    direction = "vertical"
  }

  local button_flow = flow_main.add{
    type = "flow",
    name = "calc_button_flow",
    direction = "horizontal"
  }

  local export_button = button_flow.add{
    type = "button",
    name = "calc_export_button",
    caption = {"calc-export-label"},
    tooltip = {"calc-export-tooltip"}
}

-- RECIPE CHOOSER

  local frame_recipe_chooser = frame_main.add{
    type = "frame",
    name = "recipe_chooser_frame",
    direction = "vertical"
  }
  frame_recipe_chooser.style.horizontally_stretchable = true
  frame_recipe_chooser.style.top_padding = 8
  
  local table = frame_recipe_chooser.add({
    type = "table",
    name = "recipe_chooser_table",
    column_count = 3
  })

  table.add({
    type = "choose-elem-button",
    name = "recipe_chooser_button",
    elem_type = "recipe"
  })

  table.add({
    type = "label",
    name = "recipe_chooser_label",
    caption = {"calc-select-recipe"}
  })

-- INGREDIENTS / PRODUCTS
  
  local flow_item_tables = frame_main.add{
    type = "flow",
    name = "item_tables_flow",
    direction = "horizontal"
  }
  flow_item_tables.style.horizontally_stretchable = true
  
  local frame_ingredients = flow_item_tables.add{
    type = "frame",
    name = "ingredients_frame",
    caption = {"calc-ingredients-frame-title"},
    direction = "vertical"
  }
  frame_ingredients.style.horizontally_stretchable = true
  frame_ingredients.style.vertically_stretchable = true
  frame_ingredients.add({type = "table", name = "ingredients_table", column_count = 1})
  
  local frame_products = flow_item_tables.add{
    type = "frame",
    name = "products_frame",
    caption = {"calc-products-frame-title"},
    direction = "vertical"
  }
  frame_products.style.horizontally_stretchable = true
  frame_products.style.vertically_stretchable = true
  frame_products.add({type = "table", name = "products_table", column_count = 1})

-- SUBTOTALS

  local frame_subtotals = frame_main.add{
    type = "frame",
    name = "subtotals_frame",
    --caption = {"calc-subtotals-frame-title"},
    direction = "horizontal"
  }
  frame_subtotals.style.horizontally_stretchable = true
  
  local subtotal_table = frame_subtotals.add{
    type = "table",
    name = "subtotals_table",
    column_count = 8
  }

  local cost_label = subtotal_table.add{
    type = "label",
    name = "subtotal_cost_label",
    caption = {"calc-subtotal-cost-text", ": "},
    tooltip = {"calc-recipe-score-cost"}
  }
  cost_label.style.font = "default-large-semibold"
  cost_label.style.align = "left"

  local cost_value_label = subtotal_table.add{
    type = "label",
    name = "subtotal_cost_value_label",
    caption = "",
    tooltip = {"calc-recipe-score-cost"}
  }
  cost_value_label.style.font = "default-large"
  cost_value_label.style.align = "left"

  local spacer = subtotal_table.add{
    type = "flow",
    name = "subtotals_table_spacer_left",
    direction = "horizontal"
  }
  spacer.style.horizontally_stretchable = true

  local net_score_label = subtotal_table.add{
    type = "label",
    name = "net_score_label",
    caption = {"calc-subtotal-net-gain-text", ": " },
    tooltip = {"calc-recipe-score-net"}
  }
  net_score_label.style.font = "default-large-semibold"
  net_score_label.style.align = "right"

  local net_score_value_label = subtotal_table.add{
    type = "label",
    name = "net_score_value_label",
    caption = "",
    tooltip = {"calc-recipe-score-net"}
  }
  net_score_value_label.style.font = "default-large"
  net_score_value_label.style.align = "left"

  local spacer = subtotal_table.add{
    type = "flow",
    name = "subtotals_table_spacer_right",
    direction = "horizontal"
  }
  spacer.style.horizontally_stretchable = true

  local score_label = subtotal_table.add{
    type = "label",
    name = "subtotal_score_label",
    caption = {"calc-subtotal-score-text", ": "},
    tooltip = {"calc-recipe-score-profit"}
  }
  score_label.style.font = "default-large-semibold"
  score_label.style.align = "right"

  local score_value_label = subtotal_table.add{
    type = "label",
    name = "subtotal_score_value_label",
    caption = "",
    tooltip = {"calc-recipe-score-profit"}
  }
  score_value_label.style.font = "default-large"
  score_value_label.style.align = "right"

-- TOTALS

  local frame_final_score = frame_main.add{
    type = "frame",
    name = "final_score_frame",
    --caption = {"calc-final-frame-title"},
    direction = "horizontal"
  }
  frame_final_score.style.horizontally_stretchable = true

  local final_score_table = frame_final_score.add{
    type = "table",
    name = "final_score_table",
    column_count = 5
  }
  final_score_table.style.top_padding = 8

-- CRAFTING MULTIPLIERS

  local machine_count_table = final_score_table.add{
    type = "table",
    name = "machine_count_table",
    tooltip = {"calc-machine-count-tooltip"},
    column_count = 1
  }
  machine_count_table.style.vertically_stretchable = true

-- CRAFTING SPEED

  local craft_speed_table = machine_count_table.add{
    type = "table",
    name = "craft_speed_table",
    tooltip = {"calc-craft-speed-description"},
    column_count = 3
  }
  craft_speed_table.style.horizontally_stretchable = false

  local label = craft_speed_table.add{
    type = "label",
    name = "craft_speed_label",
    caption = {"calc-craft-speed", ":"},
    tooltip = {"calc-craft-speed-description"}
  }

  local spacer = craft_speed_table.add{type = "flow", direction = "horizontal"}
  spacer.style.horizontally_stretchable = true

  local input = craft_speed_table.add{
    type = "textfield",
    name = "craft_speed_textfield",
    text = "1",
    tooltip = {"calc-craft-speed-description"}
  }
  input.style.minimal_width = 50
  input.style.maximal_width = 50
  input.style.align = "right"

-- MACHINE COUNT

  local machine_input_table = machine_count_table.add{
    type = "table",
    name = "machine_input_table",
    tooltip = {"calc-machine-count-tooltip"},
    column_count = 3,
  }
  machine_input_table.style.horizontally_stretchable = false

  local label = machine_input_table.add{
    type = "label",
    name = "machine_count_label",
    caption = {"calc-machine-count-label", ":"},
    tooltip = {"calc-machine-count-tooltip"}
  }

  local spacer = machine_input_table.add{type = "flow", direction = "horizontal"}
  spacer.style.horizontally_stretchable = true

  local input = machine_input_table.add{
    type = "textfield",
    name = "machine_count_textfield",
    text = "1",
    tooltip = {"calc-machine-count-tooltip"}
  }
  input.style.minimal_width = 50
  input.style.maximal_width = 50
  input.style.align = "right"

  local slider = machine_count_table.add{
    type = "slider",
    name = "machine_count_slider",
    tooltip = {"calc-machine-count-tooltip"},
    orientation = "horizontal",
    minimum_value = 1,
    maximum_value = 200,
    value = 1
  }
  slider.style.maximal_width = 150

  local spacer = final_score_table.add{type = "flow", direction = "horizontal"}
  spacer.style.horizontally_stretchable = true

-- TOTAL NET GAIN

  local total_net_score_table = final_score_table.add{
    type = "table",
    name = "total_net_score_table",
    tooltip = {"calc-total-net-score-description"},
    column_count = 1
  }
  total_net_score_table.draw_horizontal_line_after_headers = true
  total_net_score_table.style.vertical_spacing = 8
  total_net_score_table.style.column_alignments[1] = "center"

  local total_net_score_label = total_net_score_table.add{
    type = "label",
    name = "total_net_score_label",
    caption = {"calc-total-net-score"},
    tooltip = {"calc-total-net-score-description"}
  }
  total_net_score_label.style.font = "default-large-semibold"

  local total_net_score_value_label = total_net_score_table.add{
    type = "label",
    name = "total_net_score_value_label",
    caption = "0",
    tooltip = {"calc-total-net-score-description"}
  }
  total_net_score_value_label.style.font = "default-large"

  local spacer = final_score_table.add{type = "flow", direction = "horizontal"}
  spacer.style.horizontally_stretchable = true

-- SCORE PER TIME TABLE

  local inner_frame = final_score_table.add{
    type = "frame",
    name = "inner_score_frame",
    direction = "vertical",
    style = "image_frame"
  }
  inner_frame.style.left_padding = 8
  inner_frame.style.top_padding = 8
  inner_frame.style.right_padding = 8
  inner_frame.style.bottom_padding = 8

  local time_table = inner_frame.add{
    type = "table",
    name = "time_table",
    column_count = 3
  }
  time_table.draw_horizontal_line_after_headers = true
  time_table.draw_vertical_lines = true
  time_table.style.horizontal_spacing = 16
  time_table.style.vertical_spacing = 8
  time_table.style.column_alignments[1] = "center"
  time_table.style.column_alignments[2] = "center"
  time_table.style.column_alignments[3] = "center"

  local time_label = time_table.add{
    type = "label",
    name = "time_label_second",
    caption = {"calc-second"},
    tooltip = {"calc-score-per-second"}
  }
  time_label.style.font = "default-large-semibold"

  local time_label = time_table.add{
    type = "label",
    name = "time_label_minute",
    caption = {"calc-minute"},
    tooltip = {"calc-score-per-minute"}
  }
  time_label.style.font = "default-large-semibold"

  local time_label = time_table.add{
    type = "label",
    name = "time_label_hour",
    caption = {"calc-hour"},
    tooltip = {"calc-score-per-hour"}
  }
  time_label.style.font = "default-large-semibold"

  local time_label = time_table.add{
    type = "label",
    name = "time_label_score_per_second",
    caption = "0",
    tooltip = {"calc-score-per-second"}
  }
  time_label.style.font = "default-large"

  local time_label = time_table.add{
    type = "label",
    name = "time_label_score_per_minute",
    caption = "0",
    tooltip = {"calc-score-per-minute"}
  }
  time_label.style.font = "default-large"

  local time_label = time_table.add{
    type = "label",
    name = "time_label_score_per_hour",
    caption = "0",
    tooltip = {"calc-score-per-hour"}
  }
  time_label.style.font = "default-large"

  set_subtotals(player, 0, 0)

end

function create_item_chooser_table(chooser_table, chooser_type, chooser_state)
  chooser_table.clear()

  local checkbox_caption = {"calc-_item_-fluid-checkbox-text", ":"}
  if chooser_type == "fluid" then
    checkbox_caption = {"calc-item-_fluid_-checkbox-text", ":"}
  end

  chooser_table.add({
    type = "checkbox",
    name = "show_fluid_selector",
    caption = checkbox_caption,
    state = chooser_state,
    tooltip = {"calc-item-fluid-checkbox-tooltip"}
  })

  chooser_table.add({
    type = "choose-elem-button",
    name = "chooser_button",
    elem_type = chooser_type
  })

  chooser_table.add({
    type = "label",
    name = "chooser_label",
    caption = {"calc-select-item"}
  })
end

function select_recipe(gui, player)
  local table_ingredients = get_gui(mod_gui.get_frame_flow(player), "ingredients_table")
  table_ingredients.clear()
  
  local table_products = get_gui(mod_gui.get_frame_flow(player), "products_table")
  table_products.clear()

  local sum_ingredients_price = 0
  local sum_products_price = 0

  if gui.elem_value then
    local recipe_prototype = game.recipe_prototypes[gui.elem_value]

    prodcalc["recipe_energy"] = recipe_prototype.energy
    
    gui.parent["recipe_chooser_label"].caption = recipe_prototype.localised_name
    gui.parent["recipe_chooser_label"].style.font = "default-large-semibold"
    
    for iter, ingr in pairs(recipe_prototype.ingredients) do
      local table = table_ingredients.add{type = "table", name = "calc_table"..iter, column_count = 3}
      create_item_chooser_table(table, ingr.type, (ingr.type == "fluid"))

      local button = table["chooser_button"]
      button.elem_value = ingr.name

      select_item(button, ingr.amount)

      sum_ingredients_price = sum_ingredients_price + ((global.price_list[ingr.name] or 0) * ingr.amount)
    end
    
    for iter, prod in pairs (recipe_prototype.products) do
      local table = table_products.add{type = "table", name = "calc_table"..iter, column_count = 3}
      create_item_chooser_table(table, prod.type, (prod.type == "fluid"))

      local button = table["chooser_button"]
      button.elem_value = prod.name

      local amount = (prod.amount or prod.probability * ((prod.amount_min + prod.amount_max) / 2))
      select_item(button, amount)

      sum_products_price = sum_products_price + ((global.price_list[prod.name] or 0) * amount)
    end

  else
    gui.parent["recipe_chooser_label"].caption = {"calc-select-recipe"}
    gui.parent["recipe_chooser_label"].style.font = "default-large"
  end

  set_subtotals(player, sum_ingredients_price, sum_products_price)
end

function select_item(gui, amount)
  if gui.elem_value then
    local output
    local price = global.price_list[gui.elem_value]

    if not amount then amount = 1 end
    
    if price then
      output = amount.." × [ "
      output = output..round_number(price, 2)
      output = output.." ]  >>  "
      output = output..round_number(price * amount, 2)
    else
      output = {"calc-no-price", (gui.elem_value.." : " )}
    end
    
    gui.parent["chooser_label"].caption = output
    gui.parent["chooser_label"].style.font = "default-large"
  else
    gui.parent["chooser_label"].caption = {"calc-select-item"}
    gui.parent["chooser_label"].style.font = "default"
  end
end

function set_subtotals(player, ingredients_subtotal, products_subtotal)
  net_score = products_subtotal - ingredients_subtotal
  prodcalc["net_score"] = net_score

  local cost_value_label = get_gui(mod_gui.get_frame_flow(player), "subtotal_cost_value_label")
  cost_value_label.caption = round_number(ingredients_subtotal, 2)

  local score_value_label = get_gui(mod_gui.get_frame_flow(player), "net_score_value_label")
  score_value_label.caption = round_number(net_score, 2)

  local score_value_label = get_gui(mod_gui.get_frame_flow(player), "subtotal_score_value_label")
  score_value_label.caption = round_number(products_subtotal, 2)

  set_total(player)
end

function set_total(player)
  local speed = 1
  if prodcalc.recipe_energy then speed = prodcalc.recipe_energy end
  if prodcalc.crafting_speed then speed = speed / prodcalc.crafting_speed end

  local net_score = 0
  if prodcalc.net_score then net_score = prodcalc.net_score end

  local machine_count = 1
  if prodcalc.machine_count then machine_count = prodcalc.machine_count end

  local machine_multi_score = net_score * machine_count

  local total_score_label = get_gui(mod_gui.get_frame_flow(player), "total_net_score_value_label")
  if math.abs(machine_multi_score) < 100 then
    total_score_label.caption = round_number(machine_multi_score, 1)
  else
    total_score_label.caption = round_number(machine_multi_score, 0)
  end 

  local score_per_sec = machine_multi_score / speed
  local score_per_min = 60 * score_per_sec
  local score_per_hr = 60 * score_per_min

  local time_label = get_gui(mod_gui.get_frame_flow(player), "time_label_score_per_second")
  if math.abs(score_per_sec) < 100 then
    time_label.caption = round_number(score_per_sec, 1)
  else
    time_label.caption = round_number(score_per_sec, 0)
  end

  local time_label = get_gui(mod_gui.get_frame_flow(player), "time_label_score_per_minute")
  time_label.caption = round_number(score_per_min, 0)

  local time_label = get_gui(mod_gui.get_frame_flow(player), "time_label_score_per_hour")
  time_label.caption = round_number(score_per_hr, 0)
  
end

function get_gui(gui, name)
  if not gui then return end

  local result = {}

  if not gui.children_names then return end

  for k, elem in pairs (gui.children_names) do
    if elem == name then
      result = gui[elem]
      break
    end
    
    result = get_gui(gui[elem], name)
    if result and result.name == name then break end
  end

  return result
end

function print_gui_tree(gui, spacer)
  if not gui then return end

  if not gui.children_names then return end

  for k, elem in pairs (gui.children_names) do
    game.print(elem)
    print_gui_tree(gui[elem], "-"..spacer)
  end
end

function add_price_seeds(seed_list, additional_seeds)
  for name, price in pairs (additional_seeds) do
    if not seed_list[name] then
      seed_list[name] = price
    end
  end
  return seed_list
end

function round_number(number, decimal)
  if number and (math.abs(number) < (1 / 10^decimal)) then
    decimal = decimal + 2
  end

  return util.format_number(math.floor((number * 10^decimal) + 0.5) / (10^decimal))
end

function export_spreadsheet(player)
  local price_list = global.price_list
  local prod_list = production_score.get_product_list()
  local cost_list = {}
  local net_gain_list = {}

  for name, price in pairs (price_list) do
    local recipe_list = prod_list[name]

    local recipe_cost
    if not recipe_list then
      recipe_cost = 0
    else
      local this_recipe_cost = 0

      for k, recipe in pairs (recipe_list) do
        for ingredient, amount in pairs (recipe) do
          if ingredient ~= "energy" then
            this_recipe_cost = this_recipe_cost + ((price_list[ingredient] or 0) * amount)
          end
        end

        if recipe_cost then
          recipe_cost = math.min(recipe_cost, this_recipe_cost)
        else
          recipe_cost = this_recipe_cost
        end
      end
    end

    cost_list[name] = recipe_cost
    net_gain_list[name] = price - recipe_cost
  end

  local out = "product\tprice\tcost\tnet gain\n"
  local file = "prod_calc_export.txt"

  for name, price in pairs (price_list) do
    local cost = cost_list[name]
    local gain = net_gain_list[name]
    out = out .. name .. "\t" .. price .. "\t" .. cost .. "\t" .. gain .. "\n"
  end
  game.write_file(file, out, false, player.index)

  player.print({"calc-export-success", file})
end

return prodcalc
