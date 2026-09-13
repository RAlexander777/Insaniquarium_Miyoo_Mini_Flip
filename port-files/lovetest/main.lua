-- Minimal test: paints the whole screen and prints to stdout, so the log says
-- whether LÖVE got this far even if nothing is visible.
print("LOVETEST: main.lua loaded")

local t = 0

function love.update(dt)
  t = t + dt
end

function love.draw()
  love.graphics.clear(0.10, 0.20, 0.60)
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("fill", 40, 40, 300, 160)
  love.graphics.setColor(0, 0, 0)
  love.graphics.print("LOVE OK " .. string.format("%.1f", t), 60, 110)
end

function love.keypressed(k)
  print("LOVETEST: key " .. tostring(k))
  if k == "escape" then
    love.event.quit()
  end
end
